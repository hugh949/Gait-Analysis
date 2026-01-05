"""
Application configuration settings
"""
from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List, Union
import os
from dotenv import load_dotenv

load_dotenv()


class Settings(BaseSettings):
    """Application settings"""
    
    # Application
    APP_NAME: str = "Gait Analysis Service"
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    
    # CORS - Don't define as pydantic field, parse manually
    # This avoids pydantic validation issues with comma-separated strings
    
    # Azure Services
    AZURE_STORAGE_CONNECTION_STRING: str = os.getenv("AZURE_STORAGE_CONNECTION_STRING", "")
    AZURE_STORAGE_CONTAINER: str = os.getenv("AZURE_STORAGE_CONTAINER", "gait-videos")
    AZURE_COSMOS_ENDPOINT: str = os.getenv("AZURE_COSMOS_ENDPOINT", "")
    AZURE_COSMOS_KEY: str = os.getenv("AZURE_COSMOS_KEY", "")
    AZURE_COSMOS_DATABASE: str = os.getenv("AZURE_COSMOS_DATABASE", "gait-analysis")
    AZURE_KEY_VAULT_URL: str = os.getenv("AZURE_KEY_VAULT_URL", "")
    
    # ML Model Settings
    POSE_MODEL_PATH: str = os.getenv("POSE_MODEL_PATH", "./models/pose_estimation.pth")
    LIFTING_MODEL_PATH: str = os.getenv("LIFTING_MODEL_PATH", "./models/3d_lifting.pth")
    SMPL_MODEL_PATH: str = os.getenv("SMPL_MODEL_PATH", "./models/smplx")
    CONFIDENCE_THRESHOLD: float = float(os.getenv("CONFIDENCE_THRESHOLD", "0.8"))
    
    # Quality Gate Settings
    MIN_JOINT_CONFIDENCE: float = 0.8
    MIN_FRAME_COUNT: int = 30  # Minimum frames for analysis
    MAX_MISSING_JOINTS: int = 5  # Maximum missing joints per frame
    
    # Scale Calibration
    DEFAULT_REFERENCE_LENGTH_MM: float = 210.0  # A4 paper width
    ENABLE_AUTOMATIC_SCALING: bool = True
    
    # Processing
    MAX_VIDEO_SIZE_MB: int = 500
    SUPPORTED_VIDEO_FORMATS: List[str] = [".mp4", ".avi", ".mov", ".mkv"]
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

# Define get_cors_origins as a standalone function (exported for use in main.py)
# This avoids pydantic validation issues - we don't bind it to the settings object
def get_cors_origins() -> List[str]:
    """Get CORS origins as list - parses comma-separated string from env"""
    cors_str = os.getenv(
        "CORS_ORIGINS", 
        "http://localhost:3000,http://localhost:5173,https://jolly-meadow-0a467810f.1.azurestaticapps.net"
    )
    return [origin.strip() for origin in cors_str.split(",") if origin.strip()]

