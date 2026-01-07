"""
Azure Blob Storage Service
Simple file storage using Microsoft managed service
"""
from typing import Optional
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient
from azure.core.exceptions import AzureError
from loguru import logger
import os
import uuid

try:
    from app.core.config_simple import settings
except ImportError:
    settings = None


class AzureStorageService:
    """Azure Blob Storage service for video file management"""
    
    def __init__(self):
        """Initialize Azure Blob Storage client"""
        connection_string = os.getenv(
            "AZURE_STORAGE_CONNECTION_STRING",
            getattr(settings, "AZURE_STORAGE_CONNECTION_STRING", None) if settings else None
        )
        self.container_name = os.getenv(
            "AZURE_STORAGE_CONTAINER_NAME",
            getattr(settings, "AZURE_STORAGE_CONTAINER_NAME", "videos") if settings else "videos"
        )
        
        if not connection_string:
            logger.warning("Azure Storage not configured - using mock")
            self.client = None
            self.container_client = None
        else:
            try:
                self.client = BlobServiceClient.from_connection_string(connection_string)
                self.container_client = self.client.get_container_client(self.container_name)
                
                # Ensure container exists
                if not self.container_client.exists():
                    self.container_client.create_container()
                    logger.info(f"Created container: {self.container_name}")
                
                logger.info(f"Azure Storage initialized: {self.container_name}")
            except Exception as e:
                logger.error(f"Failed to initialize Azure Storage: {e}")
                self.client = None
                self.container_client = None
    
    async def upload_video(
        self,
        file_path: str,
        blob_name: Optional[str] = None
    ) -> str:
        """
        Upload video file to Azure Blob Storage
        
        Args:
            file_path: Local file path
            blob_name: Optional blob name (generated if not provided)
        
        Returns:
            Blob URL
        """
        if not self.container_client:
            logger.warning("Storage not configured - file not uploaded")
            return f"mock://{blob_name or 'file'}"
        
        if not blob_name:
            blob_name = f"{uuid.uuid4()}.mp4"
        
        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            
            with open(file_path, "rb") as data:
                blob_client.upload_blob(data, overwrite=True)
            
            blob_url = blob_client.url
            logger.info(f"Uploaded video: {blob_url}")
            return blob_url
        
        except Exception as e:
            logger.error(f"Failed to upload video: {e}")
            raise
    
    async def get_blob_url(self, blob_name: str) -> Optional[str]:
        """Get URL for a blob"""
        if not self.container_client:
            return None
        
        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            if blob_client.exists():
                return blob_client.url
            return None
        except Exception as e:
            logger.error(f"Failed to get blob URL: {e}")
            return None
    
    async def download_blob(self, blob_name: str) -> Optional[bytes]:
        """Download blob data asynchronously"""
        if not self.container_client:
            return None
        
        try:
            import asyncio
            loop = asyncio.get_event_loop()
            
            def _download():
                blob_client = self.container_client.get_blob_client(blob_name)
                if blob_client.exists():
                    download_stream = blob_client.download_blob()
                    return download_stream.readall()
                return None
            
            # Run in thread pool to avoid blocking
            return await loop.run_in_executor(None, _download)
        except Exception as e:
            logger.error(f"Failed to download blob: {e}")
            return None
    
    async def delete_blob(self, blob_name: str) -> bool:
        """Delete a blob"""
        if not self.container_client:
            return False
        
        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            blob_client.delete_blob()
            logger.info(f"Deleted blob: {blob_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete blob: {e}")
            return False



