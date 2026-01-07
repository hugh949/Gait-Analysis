"""
Database connection and initialization
"""
import os
import logging

# Try to import logger - fallback to standard logging
try:
    from loguru import logger
except ImportError:
    logger = logging.getLogger(__name__)
    logger.warning = logger.warning
    logger.error = logger.error
    logger.info = logger.info

# Try to import Cosmos DB - if it fails, we'll use mock
try:
    from azure.cosmos import PartitionKey
    from azure.cosmos.aio import CosmosClient as AsyncCosmosClient
    COSMOS_AVAILABLE = True
except ImportError as e:
    if logger:
        logger.warning(f"Azure Cosmos DB not available: {e}")
    COSMOS_AVAILABLE = False
    PartitionKey = None
    AsyncCosmosClient = None

try:
    from app.core.config_simple import settings
except ImportError:
    # Fallback if config import fails
    class Settings:
        AZURE_COSMOS_ENDPOINT = os.getenv("AZURE_COSMOS_ENDPOINT", "")
        AZURE_COSMOS_KEY = os.getenv("AZURE_COSMOS_KEY", "")
        AZURE_COSMOS_DATABASE = os.getenv("AZURE_COSMOS_DATABASE", "gait-analysis")
    settings = Settings()

# Global database client
db_client = None
db = None


async def init_db():
    """Initialize database connection with timeout"""
    global db_client, db
    
    if not COSMOS_AVAILABLE:
        logger.warning("Azure Cosmos DB library not available - using mock database")
        return
    
    try:
        import asyncio
        endpoint = settings.AZURE_COSMOS_ENDPOINT
        key = settings.AZURE_COSMOS_KEY
        database_name = settings.AZURE_COSMOS_DATABASE or "gait-analysis"
        
        if not endpoint or not key:
            logger.warning("Cosmos DB credentials not configured - database features will be disabled")
            return
        
        # Create async client with timeout
        db_client = AsyncCosmosClient(endpoint, key)
        
        # Get or create database with 5 second timeout (fail fast)
        try:
            database = await asyncio.wait_for(
                db_client.create_database_if_not_exists(id=database_name),
                timeout=5.0
            )
            db = database
            
            # Create containers if they don't exist (with timeout)
            containers = ["analyses", "videos", "reports", "users"]
            for container_name in containers:
                try:
                    await asyncio.wait_for(
                        database.create_container_if_not_exists(
                            id=container_name,
                            partition_key=PartitionKey(path="/id")
                        ),
                        timeout=5.0
                    )
                    logger.info(f"Container '{container_name}' ready")
                except asyncio.TimeoutError:
                    logger.warning(f"Container '{container_name}' creation timed out - skipping")
                except Exception as e:
                    logger.warning(f"Could not create container '{container_name}': {e}")
            
            logger.info("Database initialized successfully")
        except asyncio.TimeoutError:
            logger.error("Database initialization timed out after 5 seconds")
            logger.warning("Continuing without database (degraded mode)")
            db_client = None
            db = None
        
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        logger.warning("Continuing without database (degraded mode)")
        db_client = None
        db = None


# Provide a mock db object if database isn't available
class MockDatabase:
    """Mock database for when Cosmos DB is not available"""
    
    async def get_container(self, container_name: str):
        """Mock container getter"""
        return MockContainer()


class MockContainer:
    """Mock container for when Cosmos DB is not available"""
    
    # In-memory storage for mock database
    _storage = {}
    
    async def create_item(self, body, **kwargs):
        """Mock item creation"""
        item_id = body.get('id', 'unknown')
        self._storage[item_id] = body
        logger.warning(f"Database not available - item stored in memory: {item_id}")
        return body
    
    async def read_item(self, item, partition_key, **kwargs):
        """Mock item read"""
        if isinstance(item, str):
            item_id = item
        else:
            item_id = item
        if item_id in self._storage:
            return self._storage[item_id]
        raise Exception("Item not found")
    
    async def upsert_item(self, body, **kwargs):
        """Mock item upsert"""
        item_id = body.get('id', 'unknown')
        self._storage[item_id] = body
        logger.warning(f"Database not available - item updated in memory: {item_id}")
        return body
    
    async def query_items(self, query, **kwargs):
        """Mock query"""
        return []


# Export db - use mock if database not initialized
if db is None:
    db = MockDatabase()
