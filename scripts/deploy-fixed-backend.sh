#!/bin/bash
# Deploy Fixed Backend to Azure App Service
set -e

RESOURCE_GROUP="gait-analysis-rg-eus2"
APP_SERVICE_NAME="gait-analysis-api-simple"
REGISTRY="gaitanalysisacreus2"
IMAGE_NAME="gait-analysis-api"

echo "🔧 Deploying Fixed Backend"
echo "=========================="

# Step 1: Build and push Docker image
echo "📦 Step 1/3: Building and pushing Docker image..."
cd "$(dirname "$0")/../backend"
az acr build --registry $REGISTRY --image $IMAGE_NAME:latest . || {
    echo "❌ Build failed"
    exit 1
}
echo "✅ Image built and pushed"

# Step 2: Restart App Service to pull new image
echo "🔄 Step 2/3: Restarting App Service..."
az webapp restart \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --output none

echo "✅ App Service restarted"

# Step 3: Wait and test with progress
echo "⏳ Step 3/3: Waiting for app to start..."
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
        echo "✅✅✅ BACKEND IS FIXED AND WORKING! ✅✅✅"
        echo ""
        echo "Backend URL: $BACKEND_URL"
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

