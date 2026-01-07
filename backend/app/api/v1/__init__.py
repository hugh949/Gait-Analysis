"""
API v1 router - combines all v1 endpoints
Microsoft Native Architecture - uses analysis_azure, not analysis.py

IMPORTANT: This file does NOT import the old analysis.py, health.py, or reports.py
because they have been deleted and contained torch dependencies.
The integrated app (main_integrated.py) imports analysis_azure directly.
"""
from fastapi import APIRouter

# Create main router
router = APIRouter()

# DO NOT import old files - they have been deleted:
# - analysis.py (deleted - had torch dependencies)
# - health.py (deleted - not needed)
# - reports.py (deleted - not needed)

# The integrated app imports analysis_azure directly:
# from app.api.v1.analysis_azure import router as analysis_router
