"""
Storage API endpoints
Handles SAS token generation for blob storage uploads
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from loguru import logger
from app.services.storage_service import storage_service

router = APIRouter()


class SASRequest(BaseModel):
    """Request model for SAS token generation"""
    blob_name: str
    expiry_minutes: Optional[int] = 60


class SASResponse(BaseModel):
    """Response model for SAS token"""
    sas_url: str
    blob_name: str
    expiry_minutes: int


@router.post("/sas-token", response_model=SASResponse)
async def get_sas_token(request: SASRequest):
    """
    Generate SAS token for uploading video to blob storage
    
    The frontend should:
    1. Call this endpoint to get a SAS token
    2. Upload the video directly to the returned SAS URL
    3. Call the analysis endpoint with the blob name
    """
    try:
        if not request.blob_name:
            raise HTTPException(status_code=400, detail="blob_name is required")
        
        # Validate expiry_minutes
        expiry_minutes = request.expiry_minutes
        if expiry_minutes < 1 or expiry_minutes > 1440:  # 1 minute to 24 hours
            expiry_minutes = 60
        
        # Generate SAS token
        sas_url = storage_service.generate_upload_sas_token(
            blob_name=request.blob_name,
            expiry_minutes=expiry_minutes
        )
        
        if not sas_url:
            raise HTTPException(
                status_code=500,
                detail="Failed to generate SAS token. Check storage configuration."
            )
        
        logger.info(f"Generated SAS token for blob: {request.blob_name}")
        
        return SASResponse(
            sas_url=sas_url,
            blob_name=request.blob_name,
            expiry_minutes=expiry_minutes
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating SAS token: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

