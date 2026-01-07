"""
API v1 router - combines all v1 endpoints
"""
from fastapi import APIRouter
from app.api.v1 import analysis, health, reports

# Create main router
router = APIRouter()

# Include all sub-routers
router.include_router(analysis.router, prefix="/analysis", tags=["analysis"])
router.include_router(health.router, prefix="/health", tags=["health"])
router.include_router(reports.router, prefix="/reports", tags=["reports"])
