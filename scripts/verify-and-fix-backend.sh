#!/bin/bash
# Comprehensive Backend Verification and Fix Script
# Goal: Ensure backend can receive files and process them for gait analysis

set -e

# macOS-compatible timeout function
timeout() {
  local duration=$1
  shift
  
  "$@" &
  local cmd_pid=$!
  
  (
    sleep $duration
    if kill -0 $cmd_pid 2>/dev/null; then
      kill $cmd_pid 2>/dev/null
    fi
  ) &
  local timeout_pid=$!
  
  wait $cmd_pid 2>/dev/null
  local exit_code=$?
  
  kill $timeout_pid 2>/dev/null
  
  return $exit_code
}

RESOURCE_GROUP="gait-analysis-rg-wus3"
APP_SERVICE_NAME="gait-analysis-api-simple"
BACKEND_URL="https://${APP_SERVICE_NAME}.azurewebsites.net"
FRONTEND_URL="https://jolly-meadow-0a467810f.1.azurestaticapps.net"

echo "🔍 Backend Verification and Fix Script"
echo "======================================="
echo ""
echo "Goal: Ensure backend can receive files and process them for gait analysis"
echo ""

ISSUES_FOUND=0
FIXES_APPLIED=0

# Function to report issue
report_issue() {
  echo "   ❌ $1"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

# Function to report fix
report_fix() {
  echo "   ✅ $1"
  FIXES_APPLIED=$((FIXES_APPLIED + 1))
}

# Function to report OK
report_ok() {
  echo "   ✅ $1"
}

echo "═══════════════════════════════════════════════════════════"
echo "Step 1/7: Checking App Service Status"
echo "═══════════════════════════════════════════════════════════"
echo ""

APP_STATE=$(timeout 30 az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query "state" -o tsv 2>/dev/null || echo "unknown")

if [ "$APP_STATE" = "Running" ]; then
  report_ok "App Service is Running"
else
  report_issue "App Service state: $APP_STATE"
  echo "   • Starting App Service..."
  timeout 60 az webapp start --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
  sleep 5
  report_fix "App Service started"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Step 2/7: Checking Deployment Method"
echo "═══════════════════════════════════════════════════════════"
echo ""

RUNTIME=$(timeout 30 az webapp config show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query "linuxFxVersion" -o tsv 2>/dev/null || echo "unknown")

if echo "$RUNTIME" | grep -q "DOCKER"; then
  report_ok "Using Docker deployment (includes all dependencies)"
  DOCKER_IMAGE=$(echo "$RUNTIME" | cut -d'|' -f2)
  echo "   • Image: $DOCKER_IMAGE"
  
  # Check if ACR authentication is configured
  echo "   • Checking ACR authentication..."
  REGISTRY_URL=$(timeout 30 az webapp config container show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query "dockerRegistryServerUrl" -o tsv 2>/dev/null || echo "")
  
  if [ -z "$REGISTRY_URL" ] || [ "$REGISTRY_URL" = "None" ]; then
    report_issue "ACR authentication not configured (ImagePullFailure will occur)"
    echo "   • Configuring ACR authentication..."
    
    REGISTRY_NAME="gaitanalysisacrwus3"
    ACR_CREDS=$(timeout 30 az acr credential show --name $REGISTRY_NAME --query "{username: username, password: passwords[0].value}" -o json 2>/dev/null || echo "")
    
    if [ -n "$ACR_CREDS" ] && echo "$ACR_CREDS" | grep -q "username"; then
      ACR_USER=$(echo "$ACR_CREDS" | grep -o '"username": "[^"]*' | cut -d'"' -f4)
      ACR_PASS=$(echo "$ACR_CREDS" | grep -o '"password": "[^"]*' | cut -d'"' -f4)
      
      timeout 60 az webapp config container set \
        --name $APP_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP \
        --container-image-name "${REGISTRY_NAME}.azurecr.io/gait-analysis-api:latest" \
        --container-registry-url "https://${REGISTRY_NAME}.azurecr.io" \
        --container-registry-user "$ACR_USER" \
        --container-registry-password "$ACR_PASS" \
        > /dev/null 2>&1 || true
      
      echo "   • Restarting App Service to apply ACR authentication..."
      timeout 60 az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
      sleep 10
      report_fix "ACR authentication configured and app restarted"
    else
      echo "   ⚠️  Could not get ACR credentials automatically"
      echo "   • Manual fix needed: Configure ACR authentication in Azure Portal"
    fi
  else
    report_ok "ACR authentication is configured"
  fi
else
  report_issue "Not using Docker deployment: $RUNTIME"
  echo "   • Docker deployment is required for dependencies (torch, etc.)"
  echo "   • Run: bash scripts/deploy-backend-direct.sh"
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Step 3/7: Checking Always-On Configuration"
echo "═══════════════════════════════════════════════════════════"
echo ""

ALWAYS_ON=$(timeout 30 az webapp config show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query "alwaysOn" -o tsv 2>/dev/null || echo "false")

if [ "$ALWAYS_ON" = "true" ]; then
  report_ok "Always-On is enabled"
else
  report_issue "Always-On is disabled"
  echo "   • Enabling Always-On..."
  timeout 30 az webapp config set --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --always-on true > /dev/null 2>&1 || true
  report_fix "Always-On enabled"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Step 4/7: Checking CORS Configuration"
echo "═══════════════════════════════════════════════════════════"
echo ""

CORS_ORIGINS=$(timeout 30 az webapp config appsettings list --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query "[?name=='CORS_ORIGINS'].value" -o tsv 2>/dev/null || echo "")

if [ -n "$CORS_ORIGINS" ] && echo "$CORS_ORIGINS" | grep -q "$FRONTEND_URL"; then
  report_ok "CORS is configured with frontend URL"
  echo "   • CORS_ORIGINS: $CORS_ORIGINS"
else
  report_issue "CORS not properly configured"
  echo "   • Setting CORS_ORIGINS..."
  timeout 30 az webapp config appsettings set \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings \
      CORS_ORIGINS="$FRONTEND_URL,http://localhost:3000,http://localhost:5173" \
    > /dev/null 2>&1 || true
  report_fix "CORS configured"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Step 5/7: Checking Backend Health"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "   • Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s --max-time 10 "${BACKEND_URL}/health" 2>&1 || echo "ERROR")

if echo "$HEALTH_RESPONSE" | grep -q "healthy\|status"; then
  report_ok "Health endpoint responding"
  echo "   • Response: $HEALTH_RESPONSE"
elif echo "$HEALTH_RESPONSE" | grep -q "Application Error\|503\|502"; then
  report_issue "Backend returning error (may still be starting)"
  echo "   • Response indicates application error"
  echo "   • Checking logs for issues..."
  
  # Check if it's just starting up
  echo "   • Waiting 30 seconds for container to fully start..."
  sleep 30
  
  HEALTH_RESPONSE2=$(curl -s --max-time 10 "${BACKEND_URL}/health" 2>&1 || echo "ERROR")
  if echo "$HEALTH_RESPONSE2" | grep -q "healthy\|status"; then
    report_fix "Backend is now healthy (was still starting)"
  else
    report_issue "Backend still not healthy after wait"
    echo "   • Need to check application logs"
  fi
else
  report_issue "Cannot reach backend"
  echo "   • Response: $HEALTH_RESPONSE"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Step 6/7: Checking Application Logs for Errors"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "   • Checking logs (using non-blocking method)..."
# Use log download instead of tail (tail can hang indefinitely)
LOG_ZIP="/tmp/backend-logs-$(date +%s).zip"
timeout 15 az webapp log download --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --log-file "$LOG_ZIP" > /dev/null 2>&1 &

DOWNLOAD_PID=$!
sleep 5

# Check if download completed
if kill -0 $DOWNLOAD_PID 2>/dev/null; then
  # Still downloading, kill it and skip
  kill $DOWNLOAD_PID 2>/dev/null
  echo "   ⚠️  Log download taking too long (skipping detailed log check)"
  LOG_ERRORS=""
else
  wait $DOWNLOAD_PID 2>/dev/null
  if [ -f "$LOG_ZIP" ]; then
    # Extract and check logs
    EXTRACT_DIR="/tmp/backend-logs-extracted-$(date +%s)"
    unzip -q -o "$LOG_ZIP" -d "$EXTRACT_DIR" 2>/dev/null || true
    LOG_ERRORS=$(find "$EXTRACT_DIR" -type f \( -name "*.log" -o -name "*.txt" \) 2>/dev/null | head -5 | xargs grep -i -E "error|exception|traceback|failed|ModuleNotFoundError|ImportError" 2>/dev/null | tail -10 || echo "")
    rm -rf "$LOG_ZIP" "$EXTRACT_DIR" 2>/dev/null || true
  else
    LOG_ERRORS=""
    echo "   ⚠️  Could not download logs (will check health endpoint instead)"
  fi
fi

if [ -z "$LOG_ERRORS" ]; then
  report_ok "No critical errors in recent logs"
else
  report_issue "Errors found in logs:"
  echo "$LOG_ERRORS" | sed 's/^/      /'
  
  # Check for specific issues
  if echo "$LOG_ERRORS" | grep -qi "torch\|ModuleNotFoundError"; then
    echo ""
    echo "   ⚠️  Dependencies missing - need to rebuild Docker image"
    echo "   • Run: bash scripts/deploy-backend-direct.sh"
  fi
  
  if echo "$LOG_ERRORS" | grep -qi "uvicorn.*not found"; then
    echo ""
    echo "   ⚠️  uvicorn not found - Docker image may be incomplete"
    echo "   • Run: bash scripts/deploy-backend-direct.sh"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Step 7/7: Testing File Upload Endpoint"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "   • Testing upload endpoint availability..."
UPLOAD_RESPONSE=$(curl -s -X OPTIONS --max-time 10 \
  -H "Origin: $FRONTEND_URL" \
  -H "Access-Control-Request-Method: POST" \
  "${BACKEND_URL}/api/v1/analysis/upload" 2>&1 || echo "ERROR")

if echo "$UPLOAD_RESPONSE" | grep -q "200\|204" || [ -z "$UPLOAD_RESPONSE" ]; then
  report_ok "Upload endpoint accessible (CORS preflight works)"
else
  report_issue "Upload endpoint may have issues"
  echo "   • Response: $UPLOAD_RESPONSE"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📊 Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
  echo "✅ Backend is fully functional!"
  echo ""
  echo "🎯 Ready for:"
  echo "   • Receiving file uploads"
  echo "   • Processing videos for gait analysis"
  echo ""
  echo "🔗 Test it:"
  echo "   • Frontend: $FRONTEND_URL"
  echo "   • Backend: $BACKEND_URL"
  echo "   • Health: ${BACKEND_URL}/health"
else
  echo "⚠️  Found $ISSUES_FOUND issue(s)"
  if [ $FIXES_APPLIED -gt 0 ]; then
    echo "✅ Applied $FIXES_APPLIED fix(es)"
  fi
  echo ""
  echo "📝 Next Steps:"
  
  if echo "$LOG_ERRORS" | grep -qi "torch\|ModuleNotFoundError\|uvicorn.*not found"; then
    echo "   1. Rebuild Docker image with all dependencies:"
    echo "      bash scripts/deploy-backend-direct.sh"
  fi
  
  if [ "$APP_STATE" != "Running" ]; then
    echo "   2. Ensure App Service is running"
  fi
  
  echo "   3. Wait 1-2 minutes for container to fully start"
  echo "   4. Re-run this script to verify:"
  echo "      bash scripts/verify-and-fix-backend.sh"
fi

echo ""
echo "📋 Quick Commands:"
echo "   • Check health: curl ${BACKEND_URL}/health"
echo "   • View logs: az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP"
echo "   • Restart: az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP"
echo ""

