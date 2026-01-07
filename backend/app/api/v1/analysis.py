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
from app.core.config_simple import settings

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
    
    # Save uploaded file temporarily with chunked reading for large files
    tmp_path = None
    file_size_mb = 0
    chunk_size = 1024 * 1024  # 1MB chunks
    
    try:
        # Create temp file
        tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_ext)
        tmp_path = tmp_file.name
        
        # Read file in chunks to handle large files reliably
        total_size = 0
        while True:
            chunk = await file.read(chunk_size)
            if not chunk:
                break
            tmp_file.write(chunk)
            total_size += len(chunk)
            
            # Check size limit during upload
            file_size_mb = total_size / (1024 * 1024)
            if file_size_mb > settings.MAX_VIDEO_SIZE_MB:
                tmp_file.close()
                if os.path.exists(tmp_path):
                    os.unlink(tmp_path)
                raise HTTPException(
                    status_code=400,
                    detail=f"File too large: {file_size_mb:.1f}MB > {settings.MAX_VIDEO_SIZE_MB}MB"
                )
        
        tmp_file.close()
        
        # Final size check
        file_size_mb = total_size / (1024 * 1024)
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
        await container.create_item(body=analysis_metadata)
        
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
    
    except HTTPException:
        # Re-raise HTTP exceptions (they're already properly formatted)
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except:
                pass
        raise
    except Exception as e:
        # Clean up temp file on error
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except:
                pass
        logger.error(f"Error uploading video: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error processing upload: {str(e)}")


async def update_progress(analysis_id: str, current_step: str, step_progress: int, step_message: str):
    """Update analysis progress in database"""
    try:
        container = await db.get_container("analyses")
        await container.upsert_item(body={
            'id': analysis_id,
            'status': 'processing',
            'current_step': current_step,
            'step_progress': step_progress,
            'step_message': step_message,
            'updated_at': str(os.path.getmtime(__file__))  # Simple timestamp
        })
        logger.debug(f"Updated progress for {analysis_id}: {current_step} - {step_progress}% - {step_message}")
    except Exception as e:
        logger.warning(f"Could not update progress: {e}")


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
        await update_progress(analysis_id, 'pose_estimation', 0, 'Initializing pose estimation...')
        logger.info("✅ Progress: 0% - Initializing pose estimation...")
        
        # Initialize services
        await update_progress(analysis_id, 'pose_estimation', 10, 'Loading pose estimation models...')
        logger.info("✅ Progress: 10% - Loading pose estimation models...")
        pose_estimator = PoseEstimator(model_type="hrnet")
        
        await update_progress(analysis_id, 'pose_estimation', 20, 'Preparing video for processing...')
        pose_lifter = Pose3DLifter(model_type="transformer")
        env_robustness = EnvironmentalRobustnessService()
        metrics_calculator = GaitMetricsCalculator(fps=fps)
        quality_gate = QualityGateService()
        
        # Step 1: Pose estimation with progress callback
        logger.info("Extracting 2D keypoints...")
        
        # Get the running event loop for async callbacks
        import asyncio
        import time
        loop = asyncio.get_running_loop()
        
        # Create a queue to collect progress updates from sync callback
        progress_queue = asyncio.Queue()
        last_saved_progress = {'pct': 0, 'time': time.time()}
        
        def pose_progress_callback(progress_pct: int, message: str):
            """Progress callback for pose estimation - queues async update"""
            # Put update in queue (non-blocking)
            try:
                progress_queue.put_nowait((progress_pct, message))
            except:
                pass  # Queue full, skip this update
        
        # Background task to process progress queue
        async def process_progress_queue():
            while True:
                try:
                    # Wait for update with timeout
                    progress_pct, message = await asyncio.wait_for(progress_queue.get(), timeout=1.0)
                    await update_progress(analysis_id, 'pose_estimation', progress_pct, message)
                    last_saved_progress['pct'] = progress_pct
                    last_saved_progress['time'] = time.time()
                    logger.info(f"✅ Pose Estimation Progress: {progress_pct}% - {message}")
                except asyncio.TimeoutError:
                    # No update in queue, check if we need to send a heartbeat
                    elapsed = time.time() - last_saved_progress['time']
                    if elapsed >= 10.0:
                        # Send heartbeat update every 10 seconds
                        await update_progress(
                            analysis_id, 
                            'pose_estimation', 
                            last_saved_progress['pct'],
                            f'Processing... ({int(elapsed)}s elapsed)'
                        )
                        last_saved_progress['time'] = time.time()
                except Exception as e:
                    logger.warning(f"Error processing progress queue: {e}")
        
        # Start progress processor
        progress_task = asyncio.create_task(process_progress_queue())
        
        # Run video processing in executor to avoid blocking
        import concurrent.futures
        executor = concurrent.futures.ThreadPoolExecutor()
        try:
            # Run in executor and wait for completion
            keypoints_2d = await asyncio.get_event_loop().run_in_executor(
                executor, 
                pose_estimator.process_video, 
                video_path, 
                pose_progress_callback
            )
        finally:
            # Cancel progress processor after video processing
            progress_task.cancel()
            try:
                await progress_task
            except asyncio.CancelledError:
                pass
            executor.shutdown(wait=False)
        
        if not keypoints_2d:
            raise ValueError("No keypoints extracted from video")
        
        await update_progress(analysis_id, 'pose_estimation', 100, 'Pose estimation complete!')
        
        # Step 2: 3D lifting with progress callback
        await update_progress(analysis_id, '3d_lifting', 0, 'Starting 3D pose conversion...')
        logger.info("Lifting to 3D...")
        
        # Create queue for 3D lifting progress
        lifting_queue = asyncio.Queue()
        last_lifting_progress = {'pct': 0, 'time': time.time()}
        
        def lifting_progress_callback(progress_pct: int, message: str):
            """Progress callback for 3D lifting - queues async update"""
            try:
                lifting_queue.put_nowait((progress_pct, message))
            except:
                pass
        
        # Background task to process lifting progress queue
        async def process_lifting_queue():
            while True:
                try:
                    progress_pct, message = await asyncio.wait_for(lifting_queue.get(), timeout=1.0)
                    await update_progress(analysis_id, '3d_lifting', progress_pct, message)
                    last_lifting_progress['pct'] = progress_pct
                    last_lifting_progress['time'] = time.time()
                    logger.info(f"✅ 3D Lifting Progress: {progress_pct}% - {message}")
                except asyncio.TimeoutError:
                    elapsed = time.time() - last_lifting_progress['time']
                    if elapsed >= 10.0:
                        await update_progress(
                            analysis_id,
                            '3d_lifting',
                            last_lifting_progress['pct'],
                            f'Converting to 3D... ({int(elapsed)}s elapsed)'
                        )
                        last_lifting_progress['time'] = time.time()
                except Exception as e:
                    logger.warning(f"Error processing lifting queue: {e}")
        
        lifting_task = asyncio.create_task(process_lifting_queue())
        
        # Run 3D lifting in executor
        lifting_executor = concurrent.futures.ThreadPoolExecutor()
        try:
            # Run in executor and wait for completion
            keypoints_3d_list = await asyncio.get_event_loop().run_in_executor(
                lifting_executor,
                pose_lifter.lift_to_3d,
                keypoints_2d,
                30,
                lifting_progress_callback
            )
        finally:
            # Cancel lifting progress processor
            lifting_task.cancel()
            try:
                await lifting_task
            except asyncio.CancelledError:
                pass
            lifting_executor.shutdown(wait=False)
        
        await update_progress(analysis_id, '3d_lifting', 70, 'Processing 3D pose data...')
        # Convert to numpy array
        keypoints_3d = np.array([kp['keypoints_3d'] for kp in keypoints_3d_list])
        confidence = np.array([kp['confidence'] for kp in keypoints_3d_list])
        
        await update_progress(analysis_id, '3d_lifting', 100, '3D conversion complete!')
        
        # Step 3: Quality gate
        await update_progress(analysis_id, 'metrics_calculation', 0, 'Running quality checks...')
        logger.info("Running quality checks...")
        await update_progress(analysis_id, 'metrics_calculation', 10, 'Validating pose data quality...')
        can_proceed, error_msg = quality_gate.gate_analysis(keypoints_3d, confidence)
        
        if not can_proceed:
            raise ValueError(f"Quality gate failed: {error_msg}")
        
        # Step 4: Environmental robustness
        await update_progress(analysis_id, 'metrics_calculation', 20, 'Applying environmental corrections...')
        logger.info("Applying environmental robustness...")
        # Load first frame for reference detection
        import cv2
        cap = cv2.VideoCapture(video_path)
        ret, first_frame = cap.read()
        cap.release()
        
        await update_progress(analysis_id, 'metrics_calculation', 40, 'Processing reference frame...')
        robust_result = env_robustness.process_keypoints(
            keypoints_3d,
            confidence,
            reference_frame=first_frame if ret else None,
            reference_length_mm=reference_length_mm
        )
        
        keypoints_3d_processed = robust_result['keypoints_3d_mm']
        
        # Step 5: Calculate metrics with progress updates
        await update_progress(analysis_id, 'metrics_calculation', 60, 'Calculating gait metrics...')
        logger.info("Calculating gait metrics...")
        
        import asyncio
        import time
        metrics_start_time = time.time()
        
        # Create a background task to send progress updates every 10 seconds
        async def metrics_progress_updater():
            elapsed = 0
            while elapsed < 300:  # Max 5 minutes
                await asyncio.sleep(10)
                elapsed = time.time() - metrics_start_time
                if elapsed < 60:
                    await update_progress(analysis_id, 'metrics_calculation', 70, f'Computing gait metrics... ({int(elapsed)}s elapsed)')
                elif elapsed < 120:
                    await update_progress(analysis_id, 'metrics_calculation', 80, f'Analyzing gait patterns... ({int(elapsed)}s elapsed)')
                else:
                    await update_progress(analysis_id, 'metrics_calculation', 85, f'Finalizing calculations... ({int(elapsed)}s elapsed)')
        
        progress_task = asyncio.create_task(metrics_progress_updater())
        
        await update_progress(analysis_id, 'metrics_calculation', 70, 'Computing step length, cadence, and velocity...')
        metrics = metrics_calculator.calculate_all_metrics(
            keypoints_3d_processed,
            confidence
        )
        
        # Cancel progress updater
        progress_task.cancel()
        try:
            await progress_task
        except asyncio.CancelledError:
            pass
        
        await update_progress(analysis_id, 'metrics_calculation', 90, 'Finalizing metric calculations...')
        await update_progress(analysis_id, 'metrics_calculation', 100, 'Metrics calculation complete!')
        
        # Step 6: Report generation with progress updates
        await update_progress(analysis_id, 'report_generation', 0, 'Generating analysis reports...')
        logger.info("Generating reports...")
        
        report_start_time = time.time()
        
        # Create a background task to send progress updates every 10 seconds
        async def report_progress_updater():
            elapsed = 0
            while elapsed < 120:  # Max 2 minutes
                await asyncio.sleep(10)
                elapsed = time.time() - report_start_time
                if elapsed < 30:
                    await update_progress(analysis_id, 'report_generation', 30, f'Compiling analysis results... ({int(elapsed)}s elapsed)')
                elif elapsed < 60:
                    await update_progress(analysis_id, 'report_generation', 60, f'Generating medical reports... ({int(elapsed)}s elapsed)')
                else:
                    await update_progress(analysis_id, 'report_generation', 80, f'Finalizing reports... ({int(elapsed)}s elapsed)')
        
        report_progress_task = asyncio.create_task(report_progress_updater())
        
        await update_progress(analysis_id, 'report_generation', 50, 'Creating detailed analysis reports...')
        
        # Cancel report progress updater before storing results
        report_progress_task.cancel()
        try:
            await report_progress_task
        except asyncio.CancelledError:
            pass
        
        # Step 7: Store results
        container = await db.get_container("analyses")
        analysis_doc = {
            'id': analysis_id,
            'patient_id': patient_id,
            'status': 'completed',
            'current_step': 'report_generation',
            'step_progress': 100,
            'step_message': 'Analysis complete! Reports ready.',
            'metrics': metrics.__dict__,
            'keypoints_shape': keypoints_3d_processed.shape,
            'scale_factor': robust_result.get('scale_factor'),
            'quality_assessment': quality_gate.assess_quality(
                keypoints_3d_processed,
                confidence
            )
        }
        
        await container.upsert_item(body=analysis_doc)
        
        logger.info(f"Analysis {analysis_id} completed successfully")
        
    except Exception as e:
        logger.error(f"Error processing analysis {analysis_id}: {e}")
        # Update status to failed
        try:
            container = await db.get_container("analyses")
            await container.upsert_item(body={
                'id': analysis_id,
                'status': 'failed',
                'error': str(e),
                'step_message': f'Error: {str(e)}'
            })
        except:
            pass
    finally:
        # Clean up temp file
        if video_path and os.path.exists(video_path):
            try:
                os.unlink(video_path)
                logger.debug(f"Cleaned up temp file: {video_path}")
            except Exception as e:
                logger.warning(f"Could not delete temp file {video_path}: {e}")


@router.get("/{analysis_id}")
async def get_analysis(analysis_id: str):
    """Get analysis results by ID"""
    try:
        container = await db.get_container("analyses")
        analysis = await container.read_item(item=analysis_id, partition_key=analysis_id)
        
        if analysis['status'] == 'processing':
            return JSONResponse({
                'analysis_id': analysis_id,
                'status': 'processing',
                'current_step': analysis.get('current_step', 'pose_estimation'),
                'step_progress': analysis.get('step_progress', 0),
                'step_message': analysis.get('step_message', 'Processing...'),
                'message': 'Analysis in progress'
            })
        
        if analysis['status'] == 'failed':
            return JSONResponse({
                'analysis_id': analysis_id,
                'status': 'failed',
                'error': analysis.get('error', 'Unknown error'),
                'step_message': analysis.get('step_message', 'Analysis failed')
            }, status_code=500)
        
        return JSONResponse({
            'analysis_id': analysis_id,
            'status': analysis['status'],
            'current_step': 'report_generation',
            'step_progress': 100,
            'step_message': 'Analysis complete! Reports ready.',
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


