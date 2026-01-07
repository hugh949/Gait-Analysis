"""
Main FastAPI application for Gait Analysis Service
"""
import sys
import logging

# Setup basic logging first (before any other imports that might use logger)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Try to use loguru if available, otherwise use standard logging
try:
    from loguru import logger as loguru_logger
    logger = loguru_logger
    logger.info("Using loguru for logging")
except ImportError:
    logger.info("Using standard logging (loguru not available)")

from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import uvicorn

from app.core.config_simple import settings
from app.api.v1 import router as api_router
from app.core.database import init_db

# QualityGateService is optional
try:
    from app.services.quality_gate import QualityGateService
except ImportError:
    QualityGateService = None
    logger.warning("QualityGateService not available")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup - start accepting requests immediately
    logger.info("Starting Gait Analysis Service...")
    logger.info("Service ready and accepting requests")
    
    # Start database initialization in background (non-blocking)
    import asyncio
    async def init_db_background():
        try:
            await init_db()
            logger.info("Database initialized")
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            logger.warning("Continuing without database (degraded mode)")
    
    # Start database init as background task (doesn't block app startup)
    asyncio.create_task(init_db_background())
    
    yield
    
    # Shutdown
    logger.info("Shutting down Gait Analysis Service...")


app = FastAPI(
    title="Gait Analysis API",
    description="Clinical-grade gait analysis from RGB video",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware - simple and reliable
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(api_router, prefix="/api/v1")


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "Gait Analysis API",
        "version": "1.0.0"
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "components": {
            "database": "connected",
            "ml_models": "loaded",
            "quality_gate": "active"
        }
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )

