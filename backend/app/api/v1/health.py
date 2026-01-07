"""
Health check endpoints
"""
from fastapi import APIRouter
from app.core.database import db

router = APIRouter()


@router.get("")
@router.get("/")
async def health_check():
    """Basic health check - handles both /api/v1/health and /api/v1/health/"""
    return {"status": "healthy"}


@router.get("/detailed")
async def detailed_health_check():
    """Detailed health check with component status"""
    try:
        # Check database connection
        await db.get_container("analyses")
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    return {
        "status": "healthy",
        "components": {
            "database": db_status,
            "api": "operational"
        }
    }


