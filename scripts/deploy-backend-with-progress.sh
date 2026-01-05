#!/bin/bash
# Deploy Backend with Progress Updates
set -e

RESOURCE_GROUP="gait-analysis-rg-eus2"
APP_SERVICE_NAME="gait-analysis-api-simple"
REGISTRY="gaitanalysisacreus2"
IMAGE_NAME="gait-analysis-api"

echo "🔧 Deploying Backend with Progress Updates"
echo "=========================================="
echo ""

# Step 1: Build and push Docker image with progress
echo "📦 Step 1/4: Building Docker image..."
echo "   This may take 5-10 minutes..."
echo "   Progress will be shown below:"
echo ""

# Start build in background and monitor progress
cd "$(dirname "$0")/../backend"

# Function to show progress dots
show_progress() {
    local pid=$1
    local message=$2
    local count=0
    while kill -0 $pid 2>/dev/null; do
        echo -n "."
        sleep 5
        count=$((count + 1))
        if [ $((count % 12)) -eq 0 ]; then  # Every 60 seconds
            echo ""
            echo "   Still building... ($((count * 5)) seconds elapsed)"
        fi
    done
    echo ""
}

# Build with progress
BUILD_START=$(date +%s)
BUILD_PID=$(az acr build --registry $REGISTRY --image $IMAGE_NAME:latest . > /tmp/build.log 2>&1 & echo $!)

# Show progress
echo "   Build started at $(date '+%H:%M:%S')"
show_progress $BUILD_PID "Building image"

# Wait for build to complete
wait $BUILD_PID
BUILD_EXIT=$?
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

if [ $BUILD_EXIT -ne 0 ]; then
    echo "❌ Build failed after $BUILD_DURATION seconds"
    echo "   Last 20 lines of build log:"
    tail -20 /tmp/build.log
    exit 1
fi

echo "✅ Build completed in $BUILD_DURATION seconds"
echo ""

# Step 2: Restart App Service
echo "🔄 Step 2/4: Restarting App Service..."
az webapp restart \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --output none
echo "✅ App Service restart initiated"
echo ""

# Step 3: Wait for app to start with progress
echo "⏳ Step 3/4: Waiting for app to start..."
echo "   This usually takes 30-60 seconds..."
BACKEND_URL="https://${APP_SERVICE_NAME}.azurewebsites.net"

for i in {1..12}; do
    echo -n "   Checking... ($((i * 5)) seconds)"
    if curl -s -f -m 5 "${BACKEND_URL}/health" > /dev/null 2>&1; then
        echo " ✅"
        echo ""
        echo "✅ App is responding!"
        break
    else
        echo " ⏳"
        if [ $i -lt 12 ]; then
            sleep 5
        fi
    fi
done
echo ""

# Step 4: Final health check
echo "🧪 Step 4/4: Final health check..."
HEALTH_RESPONSE=$(curl -s -f -m 10 "${BACKEND_URL}/health" 2>&1)
if [ $? -eq 0 ]; then
    echo "✅✅✅ BACKEND IS WORKING! ✅✅✅"
    echo ""
    echo "Backend URL: $BACKEND_URL"
    echo "Health Status:"
    echo "$HEALTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_RESPONSE"
    echo ""
    echo "Test it:"
    echo "  curl $BACKEND_URL/health"
else
    echo "⚠️  Backend may still be starting"
    echo "   Response: $HEALTH_RESPONSE"
    echo ""
    echo "Check logs:"
    echo "  az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP"
fi

