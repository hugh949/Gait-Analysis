#!/bin/bash
# Deploy Container App for Gait Analysis Backend

echo "Deploying Container App..."

# Get connection strings
STORAGE_CONN=$(az storage account show-connection-string \
  --name gaitanalysisprodstor \
  --resource-group gait-analysis-rg-eus2 \
  --query connectionString -o tsv)

COSMOS_ENDPOINT=$(az cosmosdb show \
  --name gaitanalysisprodcosmos \
  --resource-group gait-analysis-rg-eus2 \
  --query documentEndpoint -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name gaitanalysisprodcosmos \
  --resource-group gait-analysis-rg-eus2 \
  --query primaryMasterKey -o tsv)

# Get ACR credentials
ACR_USER=$(az acr credential show --name gaitanalysisacr --query username -o tsv)
ACR_PASS=$(az acr credential show --name gaitanalysisacr --query passwords[0].value -o tsv)

# Create container app
az containerapp create \
  --name gait-analysis-api-eus2 \
  --resource-group gait-analysis-rg-eus2 \
  --environment gait-analysis-env-eus2 \
  --image gaitanalysisacr.azurecr.io/gait-analysis-api:latest \
  --registry-server gaitanalysisacr.azurecr.io \
  --registry-username "$ACR_USER" \
  --registry-password "$ACR_PASS" \
  --target-port 8000 \
  --ingress external \
  --cpu 1.0 \
  --memory 2.0Gi \
  --min-replicas 0 \
  --max-replicas 5 \
  --env-vars \
    AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONN" \
    AZURE_STORAGE_CONTAINER="gait-videos" \
    AZURE_COSMOS_ENDPOINT="$COSMOS_ENDPOINT" \
    AZURE_COSMOS_KEY="$COSMOS_KEY" \
    AZURE_COSMOS_DATABASE="gait-analysis-db" \
    DEBUG="False" \
    HOST="0.0.0.0" \
    PORT="8000"

echo ""
echo "✅ Container App deployed!"
echo "Get the URL with: az containerapp show --name gait-analysis-api-eus2 --resource-group gait-analysis-rg-eus2 --query properties.configuration.ingress.fqdn -o tsv"

