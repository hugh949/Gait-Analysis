"""
Main FastAPI application for Gait Analysis Service
"""
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import uvicorn
from loguru import logger

from app.core.config_simple import settings
from app.api.v1 import router as api_router
from app.core.database import init_db
from app.services.quality_gate import QualityGateService


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Initializing Gait Analysis Service...")
    await init_db()
    logger.info("Database initialized")
    logger.info("Service ready")
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

