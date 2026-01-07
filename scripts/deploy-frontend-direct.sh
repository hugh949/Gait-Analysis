#!/bin/bash
# Direct Frontend Deployment from Cursor to Azure
# Bypasses GitHub - deploys local code directly to Azure Static Web Apps

set -e

echo "🚀 Direct Frontend Deployment to Azure"
echo "======================================"
echo ""

# Azure Static Web App deployment token
DEPLOYMENT_TOKEN="d19afc06fc8fbc344789453cfe2e37f4879d0066b305fdb18f26e025618aa0a304-98907e59-86cf-4e90-a218-f90b7c6ebebc01e19240a498ab1e"

# Navigate to frontend directory
cd "$(dirname "$0")/../frontend"

echo "📦 Step 1/3: Building frontend..."
echo "   • Running npm build (this may take 1-2 minutes)..."
echo "   📊 Progress updates will appear every 15 seconds..."

# Start progress indicator
(
  ELAPSED=0
  while true; do
    sleep 15
    ELAPSED=$((ELAPSED + 15))
    echo "   ⏱️  Build in progress... ${ELAPSED} seconds elapsed (still building...)"
  done
) &
PROGRESS_PID=$!

npm run build
BUILD_EXIT_CODE=$?

# Kill progress indicator
kill $PROGRESS_PID 2>/dev/null || true
wait $PROGRESS_PID 2>/dev/null || true

if [ $BUILD_EXIT_CODE -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi

echo "✅ Build complete"
echo ""

echo "🔧 Step 2/3: Deploying to Azure Static Web Apps..."
echo "   • Uploading files to Azure (this may take 30-60 seconds)..."
echo "   📊 Progress updates will appear every 10 seconds..."

# Start progress indicator
(
  ELAPSED=0
  while true; do
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo "   ⏱️  Upload in progress... ${ELAPSED} seconds elapsed (still uploading...)"
  done
) &
PROGRESS_PID=$!

npx @azure/static-web-apps-cli deploy dist \
  --deployment-token "$DEPLOYMENT_TOKEN" \
  --env production

DEPLOY_EXIT_CODE=$?

# Kill progress indicator
kill $PROGRESS_PID 2>/dev/null || true
wait $PROGRESS_PID 2>/dev/null || true

if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
  echo "❌ Deployment failed"
  exit 1
fi

echo ""
echo "✅ Deployment complete!"
echo "🔗 App URL: https://gentle-sky-0a498ab1e.4.azurestaticapps.net"
echo ""


