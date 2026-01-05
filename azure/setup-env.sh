#!/bin/bash
# Script to extract and save Azure connection strings to .env file

echo "Extracting Azure connection strings..."

# Get storage connection string
STORAGE_CONN=$(az storage account show-connection-string \
  --name gaitanalysisprodstoreus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query connectionString -o tsv)

# Get Cosmos DB details
COSMOS_ENDPOINT=$(az cosmosdb show \
  --name gaitanalysisprodcosmoseus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query documentEndpoint -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name gaitanalysisprodcosmoseus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query primaryMasterKey -o tsv)

# Create .env file in backend directory
cat > ../backend/.env << EOF
# Azure Configuration
AZURE_STORAGE_CONNECTION_STRING=$STORAGE_CONN
AZURE_STORAGE_CONTAINER=gait-videos
AZURE_COSMOS_ENDPOINT=$COSMOS_ENDPOINT
AZURE_COSMOS_KEY=$COSMOS_KEY
AZURE_COSMOS_DATABASE=gait-analysis-db

# Application Settings
DEBUG=False
HOST=0.0.0.0
PORT=8000
FRONTEND_URL=http://localhost:3000

# ML Model Paths (update with actual paths)
POSE_MODEL_PATH=./models/pose_estimation.pth
LIFTING_MODEL_PATH=./models/lifting_3d.pth
SMPL_MODEL_PATH=./models/smplx

# Quality Gate Settings
CONFIDENCE_THRESHOLD=0.8
MIN_JOINT_CONFIDENCE=0.8
MIN_FRAME_COUNT=30
MAX_MISSING_JOINTS=5

# Scale Calibration
DEFAULT_REFERENCE_LENGTH_MM=210.0
ENABLE_AUTOMATIC_SCALING=True

# Processing Limits
MAX_VIDEO_SIZE_MB=500
EOF

echo "✅ .env file created in backend directory"
echo ""
echo "Connection strings saved:"
echo "  - Storage: gaitanalysisprodstor"
echo "  - Cosmos DB: gaitanalysisprodcosmos"
echo ""
echo "Next steps:"
echo "  1. Review backend/.env file"
echo "  2. Start backend: cd backend && python main.py"
echo "  3. Start frontend: cd frontend && npm run dev"

