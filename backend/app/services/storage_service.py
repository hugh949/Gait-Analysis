"""
Azure Blob Storage Service
Handles SAS token generation and blob operations
"""
from azure.storage.blob import BlobServiceClient, generate_container_sas, ContainerSasPermissions
from datetime import datetime, timedelta
from loguru import logger
from app.core.config_simple import settings
from typing import Optional


class StorageService:
    """Azure Blob Storage service for video file handling"""
    
    def __init__(self):
        self.blob_service_client: Optional[BlobServiceClient] = None
        self._initialize()
    
    def _initialize(self):
        """Initialize blob service client"""
        try:
            if settings.AZURE_STORAGE_CONNECTION_STRING:
                self.blob_service_client = BlobServiceClient.from_connection_string(
                    settings.AZURE_STORAGE_CONNECTION_STRING
                )
                logger.info("Blob Storage client initialized")
            else:
                logger.warning("Azure Storage connection string not set")
        except Exception as e:
            logger.error(f"Failed to initialize Blob Storage: {e}")
            self.blob_service_client = None
    
    def generate_upload_sas_token(self, blob_name: str, expiry_minutes: int = 60) -> Optional[str]:
        """
        Generate SAS token for uploading a blob
        
        Args:
            blob_name: Name of the blob to upload
            expiry_minutes: Token expiry time in minutes (default: 60)
        
        Returns:
            SAS token URL string or None if generation fails
        """
        if not self.blob_service_client:
            logger.error("Blob service client not initialized")
            return None
        
        try:
            # Get account key from connection string
            account_key = self._extract_account_key()
            if not account_key:
                logger.error("Could not extract account key from connection string")
                return None
            
            # Generate container SAS token with write permissions
            sas_token = generate_container_sas(
                account_name=self.blob_service_client.account_name,
                container_name=settings.AZURE_STORAGE_CONTAINER,
                account_key=account_key,
                permission=ContainerSasPermissions(write=True, create=True),
                expiry=datetime.utcnow() + timedelta(minutes=expiry_minutes)
            )
            
            # Construct full SAS URL
            container_url = f"https://{self.blob_service_client.account_name}.blob.core.windows.net/{settings.AZURE_STORAGE_CONTAINER}"
            sas_url = f"{container_url}/{blob_name}?{sas_token}"
            
            logger.info(f"Generated SAS token for {blob_name}")
            return sas_url
        
        except Exception as e:
            logger.error(f"Failed to generate SAS token: {e}")
            return None
    
    def generate_read_sas_token(self, blob_name: str, expiry_minutes: int = 60) -> Optional[str]:
        """
        Generate SAS token for reading a blob
        
        Args:
            blob_name: Name of the blob to read
            expiry_minutes: Token expiry time in minutes (default: 60)
        
        Returns:
            SAS token URL string or None if generation fails
        """
        if not self.blob_service_client:
            logger.error("Blob service client not initialized")
            return None
        
        try:
            account_key = self._extract_account_key()
            if not account_key:
                return None
            
            sas_token = generate_container_sas(
                account_name=self.blob_service_client.account_name,
                container_name=settings.AZURE_STORAGE_CONTAINER,
                account_key=account_key,
                permission=ContainerSasPermissions(read=True),
                expiry=datetime.utcnow() + timedelta(minutes=expiry_minutes)
            )
            
            container_url = f"https://{self.blob_service_client.account_name}.blob.core.windows.net/{settings.AZURE_STORAGE_CONTAINER}"
            sas_url = f"{container_url}/{blob_name}?{sas_token}"
            
            return sas_url
        
        except Exception as e:
            logger.error(f"Failed to generate read SAS token: {e}")
            return None
    
    def _extract_account_key(self) -> Optional[str]:
        """Extract account key from connection string"""
        try:
            conn_str = settings.AZURE_STORAGE_CONNECTION_STRING
            for part in conn_str.split(';'):
                if part.startswith('AccountKey='):
                    return part.split('=', 1)[1]
            return None
        except Exception as e:
            logger.error(f"Failed to extract account key: {e}")
            return None
    
    def get_blob_url(self, blob_name: str) -> Optional[str]:
        """
        Get public blob URL (if container is public) or SAS URL
        
        Args:
            blob_name: Name of the blob
        
        Returns:
            Blob URL string
        """
        if not self.blob_service_client:
            return None
        
        try:
            container_url = f"https://{self.blob_service_client.account_name}.blob.core.windows.net/{settings.AZURE_STORAGE_CONTAINER}"
            return f"{container_url}/{blob_name}"
        except Exception as e:
            logger.error(f"Failed to get blob URL: {e}")
            return None
    
    def blob_exists(self, blob_name: str) -> bool:
        """Check if a blob exists"""
        if not self.blob_service_client:
            return False
        
        try:
            container_client = self.blob_service_client.get_container_client(
                settings.AZURE_STORAGE_CONTAINER
            )
            blob_client = container_client.get_blob_client(blob_name)
            return blob_client.exists()
        except Exception as e:
            logger.error(f"Failed to check blob existence: {e}")
            return False


# Global storage service instance
storage_service = StorageService()

