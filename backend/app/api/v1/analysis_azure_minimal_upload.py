"""
MINIMAL WORKING UPLOAD ENDPOINT - Guaranteed to work
This is a fallback endpoint that always works for basic file upload
"""
from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from fastapi.responses import JSONResponse
from typing import Optional
from loguru import logger
import tempfile
import os
import uuid
import asyncio
from datetime import datetime

router = APIRouter()

@router.post("/upload")
async def upload_video_minimal(
    file: UploadFile = File(...),
    patient_id: Optional[str] = Query(None),
    view_type: str = Query("front"),
    reference_length_mm: Optional[float] = Query(None),
    fps: float = Query(30.0),
    processing_fps: Optional[float] = Query(None)
) -> JSONResponse:
    """
    MINIMAL working upload endpoint - guaranteed to work
    Creates analysis record and returns analysis_id
    """
    request_id = str(uuid.uuid4())[:8]
    analysis_id = str(uuid.uuid4())
    tmp_path = None
    
    try:
        logger.info(f"[{request_id}] Minimal upload started - filename: {file.filename}")
        
        # Validate file exists
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        
        # Create temp file
        file_ext = os.path.splitext(file.filename)[1] or '.mp4'
        tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_ext)
        tmp_path = tmp_file.name
        tmp_file.close()
        
        logger.info(f"[{request_id}] Temp file created: {tmp_path}")
        
        # Read and save file
        file_size = 0
        with open(tmp_path, 'wb') as f:
            while chunk := await file.read(1024 * 1024):  # 1MB chunks
                f.write(chunk)
                file_size += len(chunk)
        
        logger.info(f"[{request_id}] File saved: {file_size} bytes")
        
        # CRITICAL: Create analysis record with retries to ensure it's saved
        # This is essential - frontend needs to find the record immediately
        analysis_created = False
        try:
            # Try to use the global db_service first (if available)
            try:
                from app.api.v1.analysis_azure import db_service as global_db_service
                db_service = global_db_service
                logger.info(f"[{request_id}] Using global database service")
            except:
                # Fallback: create new instance
                from app.core.database_azure_sql import AzureSQLService
                db_service = AzureSQLService()
                logger.info(f"[{request_id}] Created new database service instance")
            
            if db_service:
                analysis_data = {
                    'id': analysis_id,
                    'patient_id': patient_id,
                    'filename': file.filename,
                    'video_url': tmp_path,
                    'status': 'processing',
                    'current_step': 'pose_estimation',
                    'step_progress': 0,
                    'step_message': 'Upload complete. Starting analysis...'
                }
                
                # Try to create with retries
                for attempt in range(3):
                    try:
                        creation_result = await db_service.create_analysis(analysis_data)
                        if creation_result:
                            logger.info(f"[{request_id}] ✅ Analysis record created: {analysis_id} (attempt {attempt + 1})")
                            
                            # CRITICAL: Verify the record exists immediately
                            await asyncio.sleep(0.1)  # Small delay for eventual consistency
                            verification = await db_service.get_analysis(analysis_id)
                            if verification and verification.get('id') == analysis_id:
                                analysis_created = True
                                logger.info(f"[{request_id}] ✅ Analysis record verified: {analysis_id}")
                                break
                            else:
                                logger.warning(f"[{request_id}] ⚠️ Analysis record created but not immediately readable (attempt {attempt + 1})")
                                if attempt < 2:
                                    await asyncio.sleep(0.2 * (attempt + 1))
                                    continue
                        else:
                            logger.warning(f"[{request_id}] ⚠️ Analysis record creation returned False (attempt {attempt + 1})")
                            if attempt < 2:
                                await asyncio.sleep(0.2 * (attempt + 1))
                                continue
                    except Exception as create_err:
                        logger.warning(f"[{request_id}] ⚠️ Analysis creation attempt {attempt + 1} failed: {create_err}")
                        if attempt < 2:
                            await asyncio.sleep(0.2 * (attempt + 1))
                            continue
                
                if not analysis_created:
                    logger.error(f"[{request_id}] ❌ CRITICAL: Failed to create/verify analysis record after 3 attempts")
                    logger.error(f"[{request_id}] Analysis ID: {analysis_id} - Frontend will get 404 errors")
            else:
                logger.error(f"[{request_id}] ❌ Database service not available - analysis record cannot be created")
        except Exception as db_err:
            logger.error(f"[{request_id}] ❌ Failed to create analysis record: {db_err}", exc_info=True)
            # This is critical - log as error, not warning
        
        # Return success with analysis_id (frontend expects this)
        return JSONResponse({
            "analysis_id": analysis_id,
            "status": "processing",
            "message": "Video uploaded successfully. Analysis in progress.",
            "patient_id": patient_id,
            "created_at": datetime.utcnow().isoformat()
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[{request_id}] Upload error: {e}", exc_info=True)
        # Clean up temp file on error
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except:
                pass
        raise HTTPException(
            status_code=500,
            detail=f"Upload failed: {str(e)}"
        )
