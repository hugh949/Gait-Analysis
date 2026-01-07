#!/bin/bash
# Deploy backend using ACR Build (no Oryx, no local Docker needed!)
# Azure builds the Docker image in the cloud, then we deploy it

set -e

RESOURCE_GROUP="gait-analysis-rg-wus3"
APP_SERVICE_NAME="gaitanalysisapp"
REGISTRY="gaitacr737"
IMAGE_NAME="gait-integrated"
IMAGE_TAG="latest"

echo "🚀 Deploying Backend with ACR Build (No Oryx, No Local Docker!)"
echo "================================================================"
echo ""
echo "This approach:"
echo "  ✅ Builds Docker image in Azure (cloud build)"
echo "  ✅ No local Docker needed!"
echo "  ✅ No Oryx - uses Docker directly"
echo "  ✅ Much faster and more reliable"
echo ""

# Step 1: Create ACR if it doesn't exist
echo "📦 Step 1/5: Creating Azure Container Registry..."
if ! az acr show --name "$REGISTRY" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "   Creating ACR (this may take 1-2 minutes)..."
    az acr create \
        --name "$REGISTRY" \
        --resource-group "$RESOURCE_GROUP" \
        --sku Basic \
        --admin-enabled true \
        > /dev/null 2>&1
    echo "✅ ACR created: $REGISTRY"
else
    echo "✅ ACR already exists: $REGISTRY"
fi

# Step 2: Get ACR credentials
echo ""
echo "🔐 Step 2/5: Getting ACR credentials..."
ACR_LOGIN_SERVER=$(az acr show --name "$REGISTRY" --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name "$REGISTRY" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$REGISTRY" --query passwords[0].value -o tsv)

echo "✅ ACR Login Server: $ACR_LOGIN_SERVER"

# Step 3: Build Docker image in Azure (ACR Build)
echo ""
echo "🔨 Step 3/5: Building Docker image in Azure (cloud build)..."
echo "   This builds in Azure - no local Docker needed!"
echo "   You'll see build progress..."

cd backend

az acr build \
    --registry "$REGISTRY" \
    --image "$IMAGE_NAME:$IMAGE_TAG" \
    --file Dockerfile.azure-native \
    . 2>&1 | grep -E "(Step|Successfully|Pushing|ERROR|error|Sending)" | head -30

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ ACR build failed!"
    exit 1
fi

echo "✅ Docker image built in Azure"
cd ..

# Step 4: Configure App Service to use Docker
echo ""
echo "⚙️  Step 4/5: Configuring App Service to use Docker..."
az webapp config container set \
    --name "$APP_SERVICE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --docker-custom-image-name "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG" \
    --docker-registry-server-url "https://$ACR_LOGIN_SERVER" \
    --docker-registry-server-user "$ACR_USERNAME" \
    --docker-registry-server-password "$ACR_PASSWORD" \
    > /dev/null 2>&1

# Verify ACR password was set
ACR_PASS_CHECK=$(az webapp config appsettings list --name "$APP_SERVICE_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DOCKER_REGISTRY_SERVER_PASSWORD'].value" -o tsv)
if [ -z "$ACR_PASS_CHECK" ] || [ "$ACR_PASS_CHECK" = "null" ]; then
    echo "   ⚠️  ACR password not set, setting via app settings..."
    az webapp config appsettings set \
        --name "$APP_SERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASSWORD" \
        > /dev/null 2>&1
fi

echo "✅ App Service configured to use Docker"

# Step 5: Set environment variables
echo ""
echo "🔧 Step 5/5: Setting environment variables..."
STORAGE_ACCOUNT="gaitnative0592"
CV_NAME="gaitvision0654"
SQL_SERVER="gait-sql-307"

STORAGE_CONN=$(az storage account show-connection-string --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query connectionString -o tsv)
CV_KEY=$(az cognitiveservices account keys list --name "$CV_NAME" --resource-group "$RESOURCE_GROUP" --query key1 -o tsv)
CV_ENDPOINT=$(az cognitiveservices account show --name "$CV_NAME" --resource-group "$RESOURCE_GROUP" --query properties.endpoint -o tsv)
SQL_PASSWORD="Gait307!2026"
SQL_USER="gaitadmin"

az webapp config appsettings set --name "$APP_SERVICE_NAME" --resource-group "$RESOURCE_GROUP" --settings \
  AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONN" \
  AZURE_STORAGE_CONTAINER_NAME="videos" \
  AZURE_COMPUTER_VISION_KEY="$CV_KEY" \
  AZURE_COMPUTER_VISION_ENDPOINT="$CV_ENDPOINT" \
  AZURE_SQL_SERVER="$SQL_SERVER.database.windows.net" \
  AZURE_SQL_DATABASE="gaitanalysis" \
  AZURE_SQL_USER="$SQL_USER" \
  AZURE_SQL_PASSWORD="$SQL_PASSWORD" \
  CORS_ORIGINS="https://gentle-sky-0a498ab1e.4.azurestaticapps.net,https://gaitanalysisapp.azurewebsites.net,http://localhost:3000,http://localhost:5173" \
  WEBSITES_PORT=8000 \
  > /dev/null 2>&1

echo "✅ Environment variables configured"

# Restart the app
echo ""
echo "🔄 Restarting App Service..."
az webapp restart --name "$APP_SERVICE_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Deployment Complete (No Oryx!)"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🔗 Backend URL: https://$APP_SERVICE_NAME.azurewebsites.net"
echo ""
echo "⏳ Waiting 45 seconds for container to start..."
sleep 45

# Test
echo ""
echo "🧪 Testing backend..."
for i in {1..12}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$APP_SERVICE_NAME.azurewebsites.net/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo ""
        echo "✅✅✅ BACKEND IS WORKING! (HTTP $HTTP_CODE)"
        echo ""
        curl -s --max-time 5 "https://$APP_SERVICE_NAME.azurewebsites.net/health" | python3 -m json.tool 2>/dev/null
        echo ""
        echo "✅ Deployment successful - no Oryx needed!"
        exit 0
    else
        echo "   Check $i/12... (HTTP $HTTP_CODE)"
        sleep 8
    fi
done

echo ""
echo "⚠️  Backend not responding yet. Check Azure Portal logs."
echo "   Container may need a few more minutes to start."

