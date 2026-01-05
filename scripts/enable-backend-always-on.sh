#!/bin/bash
# Enable Always-On for Backend App Service and Configure Settings
set -e

RESOURCE_GROUP="gait-analysis-rg-eus2"
APP_SERVICE_NAME="gait-analysis-api-simple"

echo "🔧 Enabling Always-On for Backend App Service"
echo "=============================================="

# Step 1: Get connection strings
echo "📋 Step 1/5: Getting Azure connection strings..."
STORAGE_CONN=$(az storage account show-connection-string \
  --name gaitanalysisprodstoreus2 \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

COSMOS_ENDPOINT=$(az cosmosdb show \
  --name gaitanalysisprodcosmoseus2 \
  --resource-group $RESOURCE_GROUP \
  --query documentEndpoint -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name gaitanalysisprodcosmoseus2 \
  --resource-group $RESOURCE_GROUP \
  --query primaryMasterKey -o tsv)

echo "✅ Connection strings retrieved"

# Step 2: Enable Always-On
echo "⚡ Step 2/5: Enabling Always-On..."
az webapp config set \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --always-on true \
  --output none

echo "✅ Always-On enabled"

# Step 3: Set environment variables
echo "🔐 Step 3/5: Setting environment variables..."
az webapp config appsettings set \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONN" \
    AZURE_STORAGE_CONTAINER="gait-videos" \
    AZURE_COSMOS_ENDPOINT="$COSMOS_ENDPOINT" \
    AZURE_COSMOS_KEY="$COSMOS_KEY" \
    AZURE_COSMOS_DATABASE="gait-analysis-db" \
    CORS_ORIGINS="https://jolly-meadow-0a467810f.1.azurestaticapps.net,http://localhost:3000,http://localhost:5173" \
    PORT="8000" \
    HOST="0.0.0.0" \
    DEBUG="False" \
  --output none

echo "✅ Environment variables set"

# Step 4: Restart App Service
echo "🔄 Step 4/5: Restarting App Service..."
az webapp restart \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --output none

echo "✅ App Service restarted"

# Step 5: Wait and test with progress
echo "⏳ Step 5/5: Waiting for app to start..."
echo "   This usually takes 30-60 seconds..."
echo ""

BACKEND_URL="https://${APP_SERVICE_NAME}.azurewebsites.net"

echo "   Waiting for backend to be ready..."
for i in {1..12}; do
    echo -n "   Attempt $i/12: Checking health endpoint... "
    if curl -s -f -m 5 "${BACKEND_URL}/health" > /dev/null 2>&1; then
        echo "✅ BACKEND IS RESPONDING!"
        echo ""
        HEALTH_RESPONSE=$(curl -s -f -m 10 "${BACKEND_URL}/health")
        echo "✅✅✅ BACKEND IS ONLINE AND WORKING! ✅✅✅"
        echo ""
        echo "Backend URL: $BACKEND_URL"
        echo "Always-On: ENABLED"
        echo ""
        echo "Health Status:"
        echo "$HEALTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_RESPONSE"
        echo ""
        echo "Test it:"
        echo "  curl $BACKEND_URL/health"
        exit 0
    else
        echo "⏳ Not ready yet"
        if [ $i -lt 12 ]; then
            sleep 5
        fi
    fi
done

echo ""
echo "⚠️  Backend may still be starting. Check logs:"
echo "  az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP"
echo ""
echo "Or check in Azure Portal:"
echo "  https://portal.azure.com/#@/resource/subscriptions/*/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_SERVICE_NAME"

