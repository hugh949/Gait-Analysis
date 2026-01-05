"""
Database connection and initialization
"""
from azure.cosmos import CosmosClient, PartitionKey
from azure.cosmos.exceptions import CosmosResourceNotFoundError
from loguru import logger
from app.core.config_simple import settings


class Database:
    """Azure Cosmos DB client"""
    
    def __init__(self):
        self.client = None
        self.database = None
        self.containers = {}
    
    async def connect(self):
        """Initialize Cosmos DB connection"""
        try:
            self.client = CosmosClient(
                settings.AZURE_COSMOS_ENDPOINT,
                settings.AZURE_COSMOS_KEY
            )
            self.database = self.client.create_database_if_not_exists(
                id=settings.AZURE_COSMOS_DATABASE
            )
            logger.info("Connected to Cosmos DB")
        except Exception as e:
            logger.error(f"Failed to connect to Cosmos DB: {e}")
            raise
    
    async def get_container(self, container_name: str):
        """Get or create a container"""
        if container_name not in self.containers:
            try:
                container = self.database.create_container_if_not_exists(
                    id=container_name,
                    partition_key=PartitionKey(path="/id"),
                    offer_throughput=400
                )
                self.containers[container_name] = container
                logger.info(f"Container '{container_name}' ready")
            except Exception as e:
                logger.error(f"Failed to create container '{container_name}': {e}")
                raise
        return self.containers[container_name]


# Global database instance
db = Database()


async def init_db():
    """Initialize database connections"""
    await db.connect()
    # Create required containers
    await db.get_container("analyses")
    await db.get_container("videos")
    await db.get_container("reports")
    await db.get_container("users")

