"""
Azure Table Storage Database Service
Cost-effective, reliable alternative to Azure SQL for simple key-value storage
Uses Azure Table Storage which is:
- Very cheap (~$0.05 per GB/month)
- Highly reliable (99.99% SLA)
- No SQL needed - simple key-value store
- Scales automatically
- Perfect for analysis metadata storage
"""
from typing import Optional, Dict, List
from loguru import logger
import os
from datetime import datetime
from azure.data.tables import TableServiceClient, TableClient
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError

try:
    from app.core.config_simple import settings
except ImportError:
    settings = None


class AzureTableStorageService:
    """Azure Table Storage service for analysis metadata"""
    
    def __init__(self):
        """Initialize Azure Table Storage connection"""
        self.connection_string = os.getenv(
            "AZURE_STORAGE_CONNECTION_STRING",
            getattr(settings, "AZURE_STORAGE_CONNECTION_STRING", None) if settings else None
        )
        self.table_name = os.getenv(
            "ANALYSIS_TABLE_NAME",
            "gaitanalyses"  # Table name for analyses
        )
        
        if not self.connection_string:
            logger.warning("Azure Storage connection string not configured - cannot use Table Storage")
            self.table_client = None
            self._use_table = False
        else:
            try:
                # Create table service client
                table_service = TableServiceClient.from_connection_string(self.connection_string)
                
                # Create table if it doesn't exist
                try:
                    table_service.create_table_if_not_exists(table_name=self.table_name)
                    logger.info(f"✅ Azure Table Storage initialized: table '{self.table_name}'")
                except HttpResponseError as e:
                    if e.status_code == 409:  # Table already exists
                        logger.info(f"✅ Azure Table Storage table '{self.table_name}' already exists")
                    else:
                        raise
                
                # Create table client
                self.table_client = table_service.get_table_client(table_name=self.table_name)
                self._use_table = True
                
            except Exception as e:
                logger.error(f"Failed to initialize Azure Table Storage: {e}", exc_info=True)
                self.table_client = None
                self._use_table = False
    
    async def create_analysis(self, analysis_data: Dict) -> bool:
        """Create new analysis record"""
        if not self._use_table or not self.table_client:
            logger.error("Table Storage not available - cannot create analysis")
            return False
        
        try:
            analysis_id = analysis_data.get('id')
            if not analysis_id:
                logger.error("Analysis data missing 'id' field")
                return False
            
            # Table Storage uses PartitionKey and RowKey
            # Use fixed partition key for all analyses (simple single-partition design)
            # RowKey is the analysis_id
            entity = {
                'PartitionKey': 'analyses',
                'RowKey': analysis_id,
                'patient_id': analysis_data.get('patient_id'),
                'filename': analysis_data.get('filename', ''),
                'video_url': analysis_data.get('video_url'),
                'status': analysis_data.get('status', 'processing'),
                'current_step': analysis_data.get('current_step', 'pose_estimation'),
                'step_progress': analysis_data.get('step_progress', 0),
                'step_message': analysis_data.get('step_message', 'Initializing...'),
                'metrics': str(analysis_data.get('metrics', {})),  # Store as string (Table Storage doesn't support dict)
                'created_at': datetime.utcnow().isoformat(),
                'updated_at': datetime.utcnow().isoformat()
            }
            
            self.table_client.create_entity(entity=entity)
            logger.info(f"✅ Created analysis {analysis_id} in Table Storage")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create analysis in Table Storage: {e}", exc_info=True)
            return False
    
    async def get_analysis(self, analysis_id: str) -> Optional[Dict]:
        """Get analysis record"""
        if not self._use_table or not self.table_client:
            logger.error("Table Storage not available - cannot get analysis")
            return None
        
        try:
            entity = self.table_client.get_entity(
                partition_key='analyses',
                row_key=analysis_id
            )
            
            # Convert entity to dict format
            analysis = {
                'id': entity.get('RowKey'),
                'patient_id': entity.get('patient_id'),
                'filename': entity.get('filename'),
                'video_url': entity.get('video_url'),
                'status': entity.get('status'),
                'current_step': entity.get('current_step'),
                'step_progress': entity.get('step_progress', 0),
                'step_message': entity.get('step_message'),
                'metrics': eval(entity.get('metrics', '{}')) if isinstance(entity.get('metrics'), str) else entity.get('metrics', {}),
                'created_at': entity.get('created_at'),
                'updated_at': entity.get('updated_at')
            }
            
            return analysis
            
        except ResourceNotFoundError:
            logger.debug(f"Analysis {analysis_id} not found in Table Storage")
            return None
        except Exception as e:
            logger.error(f"Failed to get analysis from Table Storage: {e}", exc_info=True)
            return None
    
    async def update_analysis(self, analysis_id: str, updates: Dict) -> bool:
        """Update analysis record"""
        if not self._use_table or not self.table_client:
            logger.error("Table Storage not available - cannot update analysis")
            return False
        
        try:
            # Get existing entity
            entity = self.table_client.get_entity(
                partition_key='analyses',
                row_key=analysis_id
            )
            
            # Update fields
            for key, value in updates.items():
                if key in ['status', 'current_step', 'step_progress', 'step_message', 'video_url']:
                    entity[key] = value
                elif key == 'metrics':
                    entity['metrics'] = str(value)  # Store as string
                elif key == 'steps_completed':
                    import json
                    entity['steps_completed'] = json.dumps(value) if isinstance(value, dict) else str(value)
            
            entity['updated_at'] = datetime.utcnow().isoformat()
            
            # Update entity
            self.table_client.update_entity(entity=entity)
            logger.debug(f"✅ Updated analysis {analysis_id} in Table Storage")
            return True
            
        except ResourceNotFoundError:
            logger.warning(f"Analysis {analysis_id} not found in Table Storage for update")
            return False
        except Exception as e:
            logger.error(f"Failed to update analysis in Table Storage: {e}", exc_info=True)
            return False
    
    async def list_analyses(self, limit: int = 50) -> List[Dict]:
        """List all analyses, ordered by most recent first"""
        if not self._use_table or not self.table_client:
            logger.error("Table Storage not available - cannot list analyses")
            return []
        
        try:
            entities = self.table_client.query_entities(
                query_filter="PartitionKey eq 'analyses'"
            )
            
            analyses = []
            for entity in entities:
                analysis = {
                    'id': entity.get('RowKey'),
                    'patient_id': entity.get('patient_id'),
                    'filename': entity.get('filename'),
                    'video_url': entity.get('video_url'),
                    'status': entity.get('status'),
                    'current_step': entity.get('current_step'),
                    'step_progress': entity.get('step_progress', 0),
                    'step_message': entity.get('step_message'),
                    'metrics': eval(entity.get('metrics', '{}')) if isinstance(entity.get('metrics'), str) else entity.get('metrics', {}),
                    'created_at': entity.get('created_at'),
                    'updated_at': entity.get('updated_at')
                }
                analyses.append(analysis)
            
            # Sort by updated_at descending (most recent first)
            analyses.sort(key=lambda x: x.get('updated_at', ''), reverse=True)
            
            return analyses[:limit]
            
        except Exception as e:
            logger.error(f"Failed to list analyses from Table Storage: {e}", exc_info=True)
            return []
