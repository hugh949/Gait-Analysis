"""
Analysis API endpoints
Handles video upload and gait analysis processing
"""
from fastapi import APIRouter, UploadFile, File, HTTPException, BackgroundTasks, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List, Dict
from loguru import logger
import tempfile
import os
from pathlib import Path

from app.services.perception_stack import PoseEstimator
from app.services.lifting_3d import Pose3DLifter
from app.services.multi_view_fusion import MultiViewFusionService
from app.services.environmental_robustness import EnvironmentalRobustnessService
from app.services.metrics_calculator import GaitMetricsCalculator
from app.services.quality_gate import QualityGateService
from app.core.database import db
from app.core.config import settings

router = APIRouter()


class AnalysisRequest(BaseModel):
    """Analysis request model"""
    patient_id: Optional[str] = None
    view_type: Optional[str] = "front"  # front, side, diagonal
    reference_length_mm: Optional[float] = None
    fps: Optional[float] = 30.0


class AnalysisResponse(BaseModel):
    """Analysis response model"""
    analysis_id: str
    status: str
    message: str


@router.post("/upload", response_model=AnalysisResponse)
async def upload_video(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    patient_id: Optional[str] = None,
    view_type: str = "front",
    reference_length_mm: Optional[float] = None,
    fps: float = 30.0
):
    """
    Upload video for gait analysis
    
    Supports single-view or multi-view analysis
    """
    # Validate file
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided")
    
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in settings.SUPPORTED_VIDEO_FORMATS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file format. Supported: {settings.SUPPORTED_VIDEO_FORMATS}"
        )
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as tmp_file:
        content = await file.read()
        tmp_file.write(content)
        tmp_path = tmp_file.name
    
    try:
        # Check file size
        file_size_mb = len(content) / (1024 * 1024)
        if file_size_mb > settings.MAX_VIDEO_SIZE_MB:
            raise HTTPException(
                status_code=400,
                detail=f"File too large: {file_size_mb:.1f}MB > {settings.MAX_VIDEO_SIZE_MB}MB"
            )
        
        # Generate analysis ID
        import uuid
        analysis_id = str(uuid.uuid4())
        
        # Store analysis metadata
        analysis_metadata = {
            'id': analysis_id,
            'patient_id': patient_id,
            'filename': file.filename,
            'view_type': view_type,
            'status': 'processing',
            'file_size_mb': file_size_mb
        }
        
        # Save to database
        container = await db.get_container("analyses")
        container.create_item(body=analysis_metadata)
        
        # Process in background
        background_tasks.add_task(
            process_analysis,
            analysis_id,
            tmp_path,
            patient_id,
            view_type,
            reference_length_mm,
            fps
        )
        
        return AnalysisResponse(
            analysis_id=analysis_id,
            status="processing",
            message="Video uploaded successfully. Analysis in progress."
        )
    
    except Exception as e:
        # Clean up temp file on error
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        logger.error(f"Error uploading video: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing upload: {str(e)}")


async def process_analysis(
    analysis_id: str,
    video_path: str,
    patient_id: Optional[str],
    view_type: str,
    reference_length_mm: Optional[float],
    fps: float
):
    """Background task to process video analysis"""
    try:
        logger.info(f"Starting analysis {analysis_id}")
        
        # Initialize services
        pose_estimator = PoseEstimator(model_type="hrnet")
        pose_lifter = Pose3DLifter(model_type="transformer")
        env_robustness = EnvironmentalRobustnessService()
        metrics_calculator = GaitMetricsCalculator(fps=fps)
        quality_gate = QualityGateService()
        
        # Step 1: Pose estimation
        logger.info("Extracting 2D keypoints...")
        keypoints_2d = pose_estimator.process_video(video_path)
        
        if not keypoints_2d:
            raise ValueError("No keypoints extracted from video")
        
        # Step 2: 3D lifting
        logger.info("Lifting to 3D...")
        keypoints_3d_list = pose_lifter.lift_to_3d(keypoints_2d)
        
        # Convert to numpy array
        keypoints_3d = np.array([kp['keypoints_3d'] for kp in keypoints_3d_list])
        confidence = np.array([kp['confidence'] for kp in keypoints_3d_list])
        
        # Step 3: Quality gate
        logger.info("Running quality checks...")
        can_proceed, error_msg = quality_gate.gate_analysis(keypoints_3d, confidence)
        
        if not can_proceed:
            raise ValueError(f"Quality gate failed: {error_msg}")
        
        # Step 4: Environmental robustness
        logger.info("Applying environmental robustness...")
        # Load first frame for reference detection
        import cv2
        cap = cv2.VideoCapture(video_path)
        ret, first_frame = cap.read()
        cap.release()
        
        robust_result = env_robustness.process_keypoints(
            keypoints_3d,
            confidence,
            reference_frame=first_frame if ret else None,
            reference_length_mm=reference_length_mm
        )
        
        keypoints_3d_processed = robust_result['keypoints_3d_mm']
        
        # Step 5: Calculate metrics
        logger.info("Calculating gait metrics...")
        metrics = metrics_calculator.calculate_all_metrics(
            keypoints_3d_processed,
            confidence
        )
        
        # Step 6: Store results
        container = await db.get_container("analyses")
        analysis_doc = {
            'id': analysis_id,
            'patient_id': patient_id,
            'status': 'completed',
            'metrics': metrics.__dict__,
            'keypoints_shape': keypoints_3d_processed.shape,
            'scale_factor': robust_result.get('scale_factor'),
            'quality_assessment': quality_gate.assess_quality(
                keypoints_3d_processed,
                confidence
            )
        }
        
        container.upsert_item(body=analysis_doc)
        
        logger.info(f"Analysis {analysis_id} completed successfully")
        
    except Exception as e:
        logger.error(f"Error processing analysis {analysis_id}: {e}")
        # Update status to failed
        try:
            container = await db.get_container("analyses")
            container.upsert_item(body={
                'id': analysis_id,
                'status': 'failed',
                'error': str(e)
            })
        except:
            pass
    finally:
        # Clean up temp file
        if os.path.exists(video_path):
            os.unlink(video_path)


@router.get("/{analysis_id}")
async def get_analysis(analysis_id: str):
    """Get analysis results by ID"""
    try:
        container = await db.get_container("analyses")
        analysis = container.read_item(item=analysis_id, partition_key=analysis_id)
        
        if analysis['status'] == 'processing':
            return JSONResponse({
                'analysis_id': analysis_id,
                'status': 'processing',
                'message': 'Analysis in progress'
            })
        
        if analysis['status'] == 'failed':
            return JSONResponse({
                'analysis_id': analysis_id,
                'status': 'failed',
                'error': analysis.get('error', 'Unknown error')
            }, status_code=500)
        
        return JSONResponse({
            'analysis_id': analysis_id,
            'status': analysis['status'],
            'metrics': analysis.get('metrics'),
            'quality_assessment': analysis.get('quality_assessment')
        })
    
    except Exception as e:
        logger.error(f"Error retrieving analysis {analysis_id}: {e}")
        raise HTTPException(status_code=404, detail="Analysis not found")


@router.post("/multi-view")
async def upload_multi_view(
    background_tasks: BackgroundTasks,
    front_view: UploadFile = File(...),
    side_view: Optional[UploadFile] = File(None),
    diagonal_view: Optional[UploadFile] = File(None),
    patient_id: Optional[str] = None,
    reference_length_mm: Optional[float] = None,
    fps: float = 30.0
):
    """
    Upload multiple views for fused analysis
    """
    # Similar to single view but with multi-view fusion
    # Implementation would combine views using MultiViewFusionService
    raise HTTPException(status_code=501, detail="Multi-view analysis coming soon")


# Import numpy for processing
import numpy as np

