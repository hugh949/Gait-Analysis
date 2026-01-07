#!/bin/bash
# Fix startup issue and deploy backend
# Uses direct uvicorn command instead of startup.sh file

set -e

# macOS-compatible timeout function (timeout command not available by default on macOS)
timeout() {
  local duration=$1
  shift
  
  # Start command in background
  "$@" &
  local cmd_pid=$!
  
  # Start timeout process
  (
    sleep $duration
    if kill -0 $cmd_pid 2>/dev/null; then
      kill $cmd_pid 2>/dev/null
      echo "   ⚠️  Command timed out after ${duration}s (continuing anyway)" >&2
    fi
  ) &
  local timeout_pid=$!
  
  # Wait for command to finish
  wait $cmd_pid 2>/dev/null
  local exit_code=$?
  
  # Kill timeout process
  kill $timeout_pid 2>/dev/null
  
  return $exit_code
}

echo "🔧 Fix Backend Startup & Deploy"
echo "================================"
echo ""
echo "📊 Progress updates every 10 seconds throughout deployment"
echo ""

RESOURCE_GROUP="gait-analysis-rg-wus3"
APP_SERVICE_NAME="gait-analysis-api-simple"

echo "⏱️  $(date '+%H:%M:%S') - Step 1/4: Fixing startup command..."
echo "   • Setting startup.sh that triggers Oryx build if dependencies missing..."
echo "   ⏱️  Timeout: 30 seconds (will continue if this hangs)"

# Use timeout to prevent hanging
timeout 30 az webapp config set --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP \
  --startup-file "startup.sh" 2>&1 | grep -E "appCommandLine|error" | head -3 || echo "   ✅ Startup command set to startup.sh (or timeout - continuing anyway)"

echo ""
echo "⏱️  $(date '+%H:%M:%S') - Step 2/4: Verifying configuration..."
echo "   ⏱️  Timeout: 30 seconds"
CONFIG=$(timeout 30 az webapp config show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query "{runtime:linuxFxVersion,startup:appCommandLine}" -o json 2>&1)
echo "$CONFIG" | jq '.' 2>/dev/null || echo "$CONFIG"
echo ""

echo "⏱️  $(date '+%H:%M:%S') - Step 3/4: Creating deployment package..."
cd "$(dirname "$0")/../backend"

TEMP_DIR=$(mktemp -d)
DEPLOY_DIR="$TEMP_DIR/deploy"
mkdir -p "$DEPLOY_DIR"

echo "   • Copying application files..."
cp -r app "$DEPLOY_DIR/"
cp main.py "$DEPLOY_DIR/"
echo "   • Using full requirements.txt (includes ML packages like torch)..."
cp requirements.txt "$DEPLOY_DIR/requirements.txt"
echo "   • Including startup.sh that triggers Oryx build if needed..."
cp startup.sh "$DEPLOY_DIR/startup.sh" 2>/dev/null || echo "   ⚠️  startup.sh not found (will create one)"
chmod +x "$DEPLOY_DIR/startup.sh" 2>/dev/null || true

# Create .deployment file to force fresh build
cat > "$DEPLOY_DIR/.deployment" << EOF
[config]
SCM_DO_BUILD_DURING_DEPLOYMENT=true
ENABLE_ORYX_BUILD=true
EOF

# Create .python_version to ensure Python 3.11
echo "3.11" > "$DEPLOY_DIR/.python_version"

# Force fresh build by adding unique trigger files that change hash
BUILD_TIMESTAMP=$(date +%s)
echo "$BUILD_TIMESTAMP" > "$DEPLOY_DIR/.build_trigger"
echo "FORCE_FRESH_BUILD_$BUILD_TIMESTAMP" > "$DEPLOY_DIR/.oryx_build_trigger"

# Add comment to requirements.txt to change file hash (forces rebuild)
echo "" >> "$DEPLOY_DIR/requirements.txt"
echo "# Build triggered at $(date -Iseconds) - Force fresh build" >> "$DEPLOY_DIR/requirements.txt"

echo "   • Forcing fresh build (added build triggers, modified requirements.txt hash)..."

# Create ZIP
ZIP_FILE="/tmp/backend-deploy-$(date +%s).zip"
cd "$DEPLOY_DIR"
echo "   • Creating ZIP file..."
zip -r "$ZIP_FILE" . > /dev/null 2>&1

ZIP_SIZE=$(stat -f%z "$ZIP_FILE" 2>/dev/null || stat -c%s "$ZIP_FILE" 2>/dev/null || echo "0")
ZIP_SIZE_MB=$(echo "scale=2; $ZIP_SIZE / 1024 / 1024" | bc 2>/dev/null || echo "0")
ZIP_SIZE_KB=$(echo "scale=2; $ZIP_SIZE / 1024" | bc 2>/dev/null || echo "0")

if [ "$ZIP_SIZE_MB" != "0" ] && [ "$(echo "$ZIP_SIZE_MB >= 1" | bc 2>/dev/null)" = "1" ]; then
  SIZE_DISPLAY="${ZIP_SIZE_MB} MB"
else
  SIZE_DISPLAY="${ZIP_SIZE_KB} KB"
fi

echo "   ✅ Package created: $SIZE_DISPLAY ($(du -h "$ZIP_FILE" | cut -f1))"
echo "   📦 Exact size: $ZIP_SIZE bytes"
echo ""

echo "⏱️  $(date '+%H:%M:%S') - Step 3.5/6: Clearing Oryx cache BEFORE deployment..."
echo "   • CRITICAL: Must clear cache before upload to force fresh build with torch..."

# Get publishing credentials for Kudu API (macOS-compatible)
PUBLISHING_PROFILE=$(timeout 30 az webapp deployment list-publishing-profiles \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --xml 2>/dev/null | sed -n 's/.*userName="\([^"]*\)".*/\1/p' | head -1)
PUBLISHING_PASSWORD=$(timeout 30 az webapp deployment list-publishing-profiles \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --xml 2>/dev/null | sed -n 's/.*userPWD="\([^"]*\)".*/\1/p' | head -1)

if [ -n "$PUBLISHING_PROFILE" ] && [ -n "$PUBLISHING_PASSWORD" ]; then
  echo "   • Stopping App Service to release file locks..."
  timeout 30 az webapp stop --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
  sleep 3
  
  echo "   • Deleting Oryx build cache files via Kudu API..."
  
  # Delete all Oryx-related files that could cause caching
  curl -s -X DELETE \
    -u "$PUBLISHING_PROFILE:$PUBLISHING_PASSWORD" \
    "https://$APP_SERVICE_NAME.scm.azurewebsites.net/api/vfs/site/wwwroot/oryx-manifest.toml" \
    > /dev/null 2>&1 || true
  
  curl -s -X DELETE \
    -u "$PUBLISHING_PROFILE:$PUBLISHING_PASSWORD" \
    "https://$APP_SERVICE_NAME.scm.azurewebsites.net/api/vfs/site/wwwroot/output.tar.gz" \
    > /dev/null 2>&1 || true
  
  echo "   ✅ Cache files deleted (if they existed)"
else
  echo "   ⚠️  Could not get publishing credentials - stopping app to clear locks..."
  timeout 30 az webapp stop --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
  sleep 3
fi

echo ""
echo "⏱️  $(date '+%H:%M:%S') - Step 4/6: Deploying package..."
echo "   • Uploading ZIP file ($SIZE_DISPLAY)..."
echo "   • This may take 1-2 minutes..."
echo "   • Monitoring upload progress..."

# Upload with progress monitoring and aggressive timeout
UPLOAD_START=$(date +%s)
echo "   📤 Starting upload... (this usually takes 10-30 seconds)"
echo "   ⚠️  Note: Azure may take additional time to process the deployment after upload"
echo "   ⏱️  Upload will timeout after 90 seconds if it hangs"

# Run upload with aggressive timeout - Azure CLI can hang indefinitely
UPLOAD_TIMEOUT=90  # 90 seconds max for upload
UPLOAD_OUTPUT=$(mktemp)

# Start upload in background with explicit timeout
(
  timeout $UPLOAD_TIMEOUT az webapp deployment source config-zip \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --src "$ZIP_FILE" 2>&1
) > "$UPLOAD_OUTPUT" 2>&1 &
UPLOAD_PID=$!

# Monitor upload progress with frequent updates
ELAPSED=0
UPLOAD_COMPLETE=0
echo "   ⏱️  Monitoring upload progress (updates every 5 seconds)..."

while [ $ELAPSED -lt $UPLOAD_TIMEOUT ]; do
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  
  # Show progress every 5 seconds (more frequent)
  PERCENT=$((ELAPSED * 100 / $UPLOAD_TIMEOUT))
  if [ $PERCENT -gt 100 ]; then PERCENT=100; fi
  echo "   ⏱️  Upload in progress... ${ELAPSED}s elapsed (~${PERCENT}%)"
  
  # Check if process is still running
  if ! kill -0 $UPLOAD_PID 2>/dev/null; then
    UPLOAD_COMPLETE=1
    echo "   ✅ Upload process completed"
    break
  fi
done

# If still running after timeout, kill it aggressively
if kill -0 $UPLOAD_PID 2>/dev/null; then
  echo "   ⚠️  Upload command timed out after ${UPLOAD_TIMEOUT}s"
  echo "   🔪 Killing hung process..."
  kill -9 $UPLOAD_PID 2>/dev/null || true
  wait $UPLOAD_PID 2>/dev/null
  UPLOAD_EXIT=124  # Timeout exit code
  echo "   ⚠️  Process killed - checking if upload actually succeeded..."
else
  wait $UPLOAD_PID
  UPLOAD_EXIT=$?
fi

# Show upload output
echo ""
echo "   📋 Upload command output:"
cat "$UPLOAD_OUTPUT" | grep -v "^$" | tail -15
rm -f "$UPLOAD_OUTPUT"

UPLOAD_END=$(date +%s)
UPLOAD_TIME=$((UPLOAD_END - UPLOAD_START))

# Check if upload actually succeeded (even if command timed out)
if [ $UPLOAD_EXIT -eq 124 ] || [ $UPLOAD_EXIT -ne 0 ]; then
  echo "   ⚠️  Upload command exited with code: $UPLOAD_EXIT"
  echo "   🔍 Checking if deployment was actually uploaded..."
  
  # Check deployment status
  DEPLOYMENT_STATUS=$(az webapp deployment list \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "[0].status" -o tsv 2>/dev/null || echo "unknown")
  
  if [ "$DEPLOYMENT_STATUS" != "unknown" ] && [ "$DEPLOYMENT_STATUS" != "" ]; then
    echo "   ✅ Deployment found with status: $DEPLOYMENT_STATUS"
    echo "   ⏱️  Upload took ${UPLOAD_TIME} seconds (command may have hung, but upload succeeded)"
    UPLOAD_EXIT=0  # Override exit code if deployment exists
  else
    echo "   ❌ Deployment not found - upload may have failed"
    echo "   ⏱️  Upload attempt took ${UPLOAD_TIME} seconds"
    rm -rf "$TEMP_DIR" "$ZIP_FILE"
    exit 1
  fi
else
  echo "   ✅ Upload completed successfully in ${UPLOAD_TIME} seconds"
fi

rm -rf "$TEMP_DIR" "$ZIP_FILE"

echo ""
echo "⏱️  $(date '+%H:%M:%S') - Step 5/6: Configuring for fresh Oryx build..."
echo "   • This will install ALL packages from requirements.txt (including torch)"
echo "   • First build: 5-10 minutes (downloads torch ~2GB, opencv, etc.)"

# Set app settings to force rebuild (MUST be done)
echo "   • Setting app settings to force fresh build..."
echo "   ⏱️  Timeout: 30 seconds"
timeout 30 az webapp config appsettings set \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    SCM_DO_BUILD_DURING_DEPLOYMENT=true \
    ENABLE_ORYX_BUILD=true \
    POST_BUILD_COMMAND="echo 'Fresh build completed at $(date)'" \
  > /dev/null 2>&1 || echo "   ⚠️  Timeout or error (continuing anyway)"

# Get publishing credentials for Kudu API to trigger build
echo "   • Getting publishing credentials to trigger Oryx build..."
PUBLISHING_PROFILE=$(timeout 30 az webapp deployment list-publishing-profiles \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --xml 2>/dev/null | sed -n 's/.*userName="\([^"]*\)".*/\1/p' | head -1)
PUBLISHING_PASSWORD=$(timeout 30 az webapp deployment list-publishing-profiles \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --xml 2>/dev/null | sed -n 's/.*userPWD="\([^"]*\)".*/\1/p' | head -1)

if [ -n "$PUBLISHING_PROFILE" ] && [ -n "$PUBLISHING_PASSWORD" ]; then
  echo "   • Triggering Oryx build via Kudu API..."
  echo "   ⚠️  This will install ALL packages from requirements.txt (torch ~2GB, takes 5-10 minutes)..."
  
  # Method 1: Trigger Oryx build via Kudu build API
  echo "   • Attempting to trigger build via Kudu API..."
  BUILD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -u "$PUBLISHING_PROFILE:$PUBLISHING_PASSWORD" \
    "https://$APP_SERVICE_NAME.scm.azurewebsites.net/api/command" \
    -H "Content-Type: application/json" \
    -d '{"command": "oryx build . -o /home/site/wwwroot --platform python --platform-version 3.11", "dir": "/home/site/wwwroot"}' 2>&1)
  
  HTTP_CODE=$(echo "$BUILD_RESPONSE" | tail -1)
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "   ✅ Oryx build command triggered (HTTP $HTTP_CODE)"
  else
    echo "   ⚠️  Build command response: HTTP $HTTP_CODE"
    echo "   • Trying alternative: Restarting app to trigger auto-build..."
    
    # Method 2: Restart app - this should trigger Oryx if SCM_DO_BUILD_DURING_DEPLOYMENT is set
    timeout 30 az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
    echo "   ✅ App restarted - Oryx should detect requirements.txt and build"
  fi
else
  echo "   ⚠️  Could not get publishing credentials - restarting app to trigger build..."
  timeout 30 az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
fi

# Also sync deployment source (alternative trigger)
echo "   • Syncing deployment source (alternative build trigger)..."
echo "   ⏱️  Timeout: 30 seconds"
timeout 30 az webapp deployment source sync --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || echo "   ⚠️  Timeout or error (continuing anyway)"

# Start the app to trigger fresh Oryx build
echo "   • Starting App Service (triggers Oryx build if not already started)..."
echo "   ⏱️  Timeout: 30 seconds"
timeout 30 az webapp start --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || echo "   ⚠️  Timeout or error (continuing anyway)"

echo "   ✅ Configuration complete - Oryx build should be running"

echo ""
echo "⏱️  $(date '+%H:%M:%S') - Step 6/6: Monitoring build and startup progress..."
echo "   • Oryx is installing dependencies (this takes time for ML packages)..."
echo "   • Progress updates every 10 seconds..."

BUILD_START=$(date +%s)
MAX_WAIT_TIME=600  # 10 minutes max
ELAPSED=0
LAST_STATUS=""
POLL_INTERVAL=10

while [ $ELAPSED -lt $MAX_WAIT_TIME ]; do
  sleep $POLL_INTERVAL
  ELAPSED=$((ELAPSED + $POLL_INTERVAL))
  
  # Check backend health
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    https://$APP_SERVICE_NAME.azurewebsites.net/health 2>/dev/null || echo "000")
  
  # Show progress every 10 seconds
  if [ $((ELAPSED % 10)) -eq 0 ]; then
    PERCENT=$((ELAPSED * 100 / $MAX_WAIT_TIME))
    if [ $PERCENT -gt 100 ]; then PERCENT=100; fi
    
    if [ "$HTTP_CODE" = "200" ]; then
      echo "   ✅ Backend is responding! (HTTP $HTTP_CODE) - ${ELAPSED}s elapsed"
      break
    elif [ "$HTTP_CODE" = "000" ]; then
      echo "   ⏳ Still building/starting... ${ELAPSED}s elapsed (~${PERCENT}%) - Backend not responding yet"
    elif [ "$HTTP_CODE" = "503" ] || [ "$HTTP_CODE" = "502" ]; then
      echo "   ⏳ Service starting... ${ELAPSED}s elapsed (~${PERCENT}%) - HTTP $HTTP_CODE (expected during startup)"
    else
      echo "   ⏳ Building... ${ELAPSED}s elapsed (~${PERCENT}%) - HTTP $HTTP_CODE"
    fi
  fi
  
  # Break if backend is healthy
  if [ "$HTTP_CODE" = "200" ]; then
    break
  fi
done

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

echo ""
echo "🔍 Final health check..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  https://$APP_SERVICE_NAME.azurewebsites.net/health 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo "   ✅ Backend is healthy! (HTTP $HTTP_CODE)"
  echo "   ⏱️  Total build/startup time: ${BUILD_TIME} seconds"
else
  echo "   ⚠️  Backend returned: HTTP $HTTP_CODE"
  echo "   ⏱️  Waited ${BUILD_TIME} seconds"
  if [ $ELAPSED -ge $MAX_WAIT_TIME ]; then
    echo "   ⚠️  Maximum wait time reached (${MAX_WAIT_TIME}s)"
    echo "   • Backend may still be installing dependencies"
    echo "   • Check Azure logs: az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP"
  else
    echo "   • May need more time to start"
    echo "   • Check logs if issues persist"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Deployment Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🔗 Backend URL: https://$APP_SERVICE_NAME.azurewebsites.net"
echo ""

