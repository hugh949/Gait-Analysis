#!/bin/bash
# Update Container App with new ACR image (East US 2)

echo "Updating Container App with new image from ACR..."

# Get ACR credentials
ACR_USER=$(az acr credential show --name gaitanalysisacreus2 --query username -o tsv)
ACR_PASS=$(az acr credential show --name gaitanalysisacreus2 --query passwords[0].value -o tsv)

# Get connection strings
STORAGE_CONN=$(az storage account show-connection-string \
  --name gaitanalysisprodstoreus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query connectionString -o tsv)

COSMOS_ENDPOINT=$(az cosmosdb show \
  --name gaitanalysisprodcosmoseus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query documentEndpoint -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name gaitanalysisprodcosmoseus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query primaryMasterKey -o tsv)

# Update Container App
az containerapp update \
  --name gait-analysis-api-eus2 \
  --resource-group gait-analysis-rg-eus2 \
  --image gaitanalysisacreus2.azurecr.io/gait-analysis-api:latest \
  --registry-server gaitanalysisacreus2.azurecr.io \
  --registry-username "$ACR_USER" \
  --registry-password "$ACR_PASS" \
  --set-env-vars \
    AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONN" \
    AZURE_STORAGE_CONTAINER="gait-videos" \
    AZURE_COSMOS_ENDPOINT="$COSMOS_ENDPOINT" \
    AZURE_COSMOS_KEY="$COSMOS_KEY" \
    AZURE_COSMOS_DATABASE="gait-analysis-db" \
    CORS_ORIGINS="https://gentle-wave-0d4e1d10f.4.azurestaticapps.net,http://localhost:3000,http://localhost:5173" \
    FRONTEND_URL="https://gentle-wave-0d4e1d10f.4.azurestaticapps.net" \
    DEBUG="False" \
    HOST="0.0.0.0" \
    PORT="8000"

echo ""
echo "✅ Container App updated!"
echo "Backend URL: https://gait-analysis-api-eus2.jollymeadow-b5f64007.eastus2.azurecontainerapps.io"

