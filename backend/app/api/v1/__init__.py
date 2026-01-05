"""
API v1 Router
"""
from fastapi import APIRouter
from app.api.v1 import analysis, reports, health
from app.api.routes import storage

router = APIRouter()

router.include_router(analysis.router, prefix="/analysis", tags=["analysis"])
router.include_router(reports.router, prefix="/reports", tags=["reports"])
router.include_router(health.router, prefix="/health", tags=["health"])
router.include_router(storage.router, prefix="/storage", tags=["storage"])

