"""
API v1 router - combines all v1 endpoints
Microsoft Native Architecture - uses analysis_azure, not analysis.py
"""
from fastapi import APIRouter

# Create main router
router = APIRouter()

# Note: We do NOT import the old analysis.py here because it has torch dependencies
# The integrated app (main_integrated.py) imports analysis_azure directly
# 
# health.py and reports.py may also have old dependencies, so we skip them for now
# They can be added later with Azure-native versions if needed

# Note: analysis_azure is imported directly in main_integrated.py
# We don't import it here to avoid circular dependencies
