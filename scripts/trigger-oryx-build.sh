#!/bin/bash
# Manually trigger Oryx build to install dependencies (including torch)
# Uses Azure CLI methods which are more reliable than Kudu API

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

RESOURCE_GROUP="gait-analysis-rg-wus3"
APP_SERVICE_NAME="gait-analysis-api-simple"

echo "🔨 Triggering Oryx Build to Install Dependencies"
echo "================================================"
echo ""

# Step 1: Ensure app settings are configured to trigger builds
echo "📋 Step 1/4: Configuring app settings for Oryx build..."
echo "   • Setting SCM_DO_BUILD_DURING_DEPLOYMENT=true"
echo "   • Setting ENABLE_ORYX_BUILD=true"
echo "   ⏱️  Timeout: 30 seconds"

timeout 30 az webapp config appsettings set \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    SCM_DO_BUILD_DURING_DEPLOYMENT=true \
    ENABLE_ORYX_BUILD=true \
  > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "   ✅ App settings configured"
else
  echo "   ⚠️  Warning: Could not set app settings (may already be set or timed out)"
fi

echo ""

# Step 2: Stop the app to clear any locks
echo "📋 Step 2/4: Stopping app to clear file locks..."
echo "   ⏱️  Timeout: 30 seconds"
timeout 30 az webapp stop --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
sleep 3
echo "   ✅ App stopped (or timeout - continuing anyway)"

echo ""

# Step 3: Sync deployment source - this triggers Oryx build
echo "📋 Step 3/4: Syncing deployment source (triggers Oryx build)..."
echo "   ⚠️  This will install ALL packages from requirements.txt"
echo "   ⚠️  torch (~2GB) will take 5-10 minutes to download and install"
echo "   ⏱️  Timeout: 30 seconds (will continue if this hangs)"
echo ""

SYNC_OUTPUT=$(timeout 30 az webapp deployment source sync \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP 2>&1)
SYNC_EXIT=$?

if [ $SYNC_EXIT -eq 0 ]; then
  echo "   ✅ Deployment source synced - Oryx build should be triggered"
elif [ $SYNC_EXIT -eq 124 ] || [ $SYNC_EXIT -ne 0 ]; then
  echo "   ⚠️  Sync command timed out or failed (exit code: $SYNC_EXIT)"
  echo "   • Continuing with restart method..."
fi

echo ""

# Step 4: Start the app - this will trigger Oryx if build wasn't triggered by sync
echo "📋 Step 4/4: Starting app (triggers Oryx build if not already started)..."
echo "   ⏱️  Timeout: 30 seconds"
timeout 30 az webapp start --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
echo "   ✅ App started (or timeout - continuing anyway)"
echo "   • Oryx should detect requirements.txt and build when app starts"

echo ""
echo "📋 Monitoring build progress..."
echo "   • Waiting 15 seconds for build to start..."
sleep 15

echo ""
echo "   • Checking recent logs for build activity..."
echo ""

# Check logs for build activity
LOG_OUTPUT=$(timeout 10 az webapp log tail \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP 2>&1 | \
  grep -i -E "oryx|build|installing|torch|pip install|requirements" | tail -10)

if [ -n "$LOG_OUTPUT" ]; then
  echo "   ✅ Build activity detected:"
  echo "$LOG_OUTPUT" | sed 's/^/      /'
else
  echo "   ⏳ No build logs yet - build may be starting..."
  echo "   • This is normal - Oryx build can take 30-60 seconds to start"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Build Trigger Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📝 Next Steps:"
echo "   1. Monitor logs: az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP"
echo "   2. Wait 5-10 minutes for torch and other packages to install"
echo "   3. Check health: curl https://$APP_SERVICE_NAME.azurewebsites.net/health"
echo ""

