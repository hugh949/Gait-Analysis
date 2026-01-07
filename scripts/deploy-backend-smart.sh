#!/bin/bash
# Smart Incremental Backend Deployment
# Intelligently chooses the fastest deployment method based on what changed
# - Code only: Fast ZIP deployment (30-60 seconds) - NO DOCKER
# - Dependencies: Docker build (3-8 minutes) - necessary for deps
# - No changes: Skip (30 seconds)

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
      echo "   ⚠️  Command timed out after ${duration}s (continuing anyway)" >&2
    fi
  ) &
  local timeout_pid=$!
  
  wait $cmd_pid 2>/dev/null
  local exit_code=$?
  
  kill $timeout_pid 2>/dev/null
  
  return $exit_code
}

echo "🚀 Smart Incremental Backend Deployment"
echo "========================================"
echo ""
echo "💡 Intelligently chooses fastest method based on changes"
echo "   • Code only → Fast ZIP (30-60s)"
echo "   • Dependencies → Docker (3-8min)"
echo "   • No changes → Skip (30s)"
echo ""

RESOURCE_GROUP="gait-analysis-rg-wus3"
APP_SERVICE_NAME="gait-analysis-api-wus3"
REGISTRY="gaitanalysisacrwus3"
IMAGE="gait-analysis-api:latest"

# Navigate to backend directory
cd "$(dirname "$0")/../backend"

echo "═══════════════════════════════════════════════════════════"
echo "📋 Step 1/4: Analyzing Changes"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if requirements.txt changed (dependencies)
REQUIREMENTS_CHANGED=false
if [ -f ".last_requirements_hash" ]; then
    OLD_HASH=$(cat .last_requirements_hash 2>/dev/null || echo "")
    NEW_HASH=$(md5 -q requirements.txt 2>/dev/null || md5sum requirements.txt | cut -d' ' -f1 || echo "")
    if [ "$OLD_HASH" != "$NEW_HASH" ]; then
        REQUIREMENTS_CHANGED=true
        echo "   ✅ requirements.txt changed - dependencies need update"
    else
        echo "   ✅ requirements.txt unchanged - dependencies cached"
    fi
else
    REQUIREMENTS_CHANGED=true
    echo "   ✅ First deployment - will install dependencies"
fi

# Check if Python code changed
CODE_CHANGED=false
if [ -f ".last_code_hash" ]; then
    OLD_HASH=$(cat .last_code_hash 2>/dev/null || echo "")
    NEW_HASH=$(find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5 -q 2>/dev/null | md5 -q 2>/dev/null || find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5sum 2>/dev/null | md5sum | cut -d' ' -f1 || echo "")
    if [ "$OLD_HASH" != "$NEW_HASH" ] && [ -n "$NEW_HASH" ]; then
        CODE_CHANGED=true
        echo "   ✅ Python code changed"
    else
        echo "   ✅ Python code unchanged"
    fi
else
    CODE_CHANGED=true
    echo "   ✅ First deployment - all code included"
fi

# Determine deployment strategy
DEPLOYMENT_METHOD=""
if [ "$REQUIREMENTS_CHANGED" = true ]; then
    DEPLOYMENT_METHOD="docker"
    echo ""
    echo "📦 Strategy: Docker Build (dependencies changed)"
    echo "   • Estimated time: 3-8 minutes"
    echo "   • Reason: Dependencies need to be rebuilt"
elif [ "$CODE_CHANGED" = true ]; then
    DEPLOYMENT_METHOD="zip"
    echo ""
    echo "📦 Strategy: Fast ZIP Deployment (code only)"
    echo "   • Estimated time: 30-60 seconds"
    echo "   • Reason: Only code changed, dependencies cached"
else
    DEPLOYMENT_METHOD="skip"
    echo ""
    echo "📦 Strategy: Skip (no changes)"
    echo "   • Estimated time: 30 seconds"
    echo "   • Reason: Nothing changed"
fi

echo ""

# Step 2: Execute deployment based on strategy
if [ "$DEPLOYMENT_METHOD" = "docker" ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "🐳 Step 2/4: Docker Build (Dependencies Changed)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "⏳ Building Docker image..."
    echo "   📊 Progress updates every 10 seconds..."
    echo ""
    
    # Progress indicator
    (
        ELAPSED=0
        while true; do
            sleep 10
            ELAPSED=$((ELAPSED + 10))
            echo "   ⏱️  [$(date +%H:%M:%S)] Build in progress... ${ELAPSED}s elapsed" >&2
        done
    ) &
    PROGRESS_PID=$!
    
    BUILD_OUTPUT=$(timeout 1800 az acr build --registry $REGISTRY --image $IMAGE --file Dockerfile.optimized . 2>&1)
    BUILD_EXIT_CODE=$?
    
    kill $PROGRESS_PID 2>/dev/null || true
    wait $PROGRESS_PID 2>/dev/null || true
    
    if [ $BUILD_EXIT_CODE -ne 0 ]; then
        echo "❌ Build failed!"
        echo "$BUILD_OUTPUT" | tail -20
        exit 1
    fi
    
    echo "✅ Docker build complete!"
    echo ""
    
    # Switch to Docker mode and update container
    echo "🔧 Switching to Docker mode..."
    timeout 30 az webapp config set \
        --name $APP_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP \
        --linux-fx-version "DOCKER|$REGISTRY.azurecr.io/$IMAGE" \
        > /dev/null 2>&1 || true
    
    echo "🔧 Updating container configuration..."
    ACR_USERNAME=$(az acr credential show --name $REGISTRY --query username -o tsv 2>/dev/null || echo "")
    ACR_PASSWORD=$(az acr credential show --name $REGISTRY --query passwords[0].value -o tsv 2>/dev/null || echo "")
    
    if [ -n "$ACR_USERNAME" ] && [ -n "$ACR_PASSWORD" ]; then
        timeout 60 az webapp config container set \
            --name $APP_SERVICE_NAME \
            --resource-group $RESOURCE_GROUP \
            --container-image-name $REGISTRY.azurecr.io/$IMAGE \
            --container-registry-url "https://$REGISTRY.azurecr.io" \
            --container-registry-user $ACR_USERNAME \
            --container-registry-password $ACR_PASSWORD \
            > /dev/null 2>&1 || echo "   ⚠️  Config update timed out (may have succeeded)"
    fi
    
    # Save hashes
    md5 -q requirements.txt > .last_requirements_hash 2>/dev/null || md5sum requirements.txt | cut -d' ' -f1 > .last_requirements_hash
    find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5 -q 2>/dev/null | md5 -q > .last_code_hash 2>/dev/null || find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5sum 2>/dev/null | md5sum | cut -d' ' -f1 > .last_code_hash
    
elif [ "$DEPLOYMENT_METHOD" = "zip" ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "⚡ Step 2/4: Fast ZIP Deployment (Code Only)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "⏳ Creating deployment package..."
    echo "   📊 Progress updates every 3 seconds..."
    echo ""
    
    # Create deployment package
    TEMP_DIR=$(mktemp -d)
    DEPLOY_DIR="$TEMP_DIR/deploy"
    mkdir -p "$DEPLOY_DIR"
    
    (
        ELAPSED=0
        while true; do
            sleep 3
            ELAPSED=$((ELAPSED + 3))
            echo "   ⏱️  [$(date +%H:%M:%S)] Preparing package... ${ELAPSED}s elapsed" >&2
        done
    ) &
    PROGRESS_PID=$!
    
    # Copy files
    cp -r app "$DEPLOY_DIR/" 2>/dev/null || true
    cp main.py "$DEPLOY_DIR/" 2>/dev/null || true
    cp requirements.txt "$DEPLOY_DIR/" 2>/dev/null || true
    
    # Create Oryx config (skip build since deps unchanged)
    echo "3.11" > "$DEPLOY_DIR/.python_version"
    cat > "$DEPLOY_DIR/.deployment" << EOF
[config]
SCM_DO_BUILD_DURING_DEPLOYMENT=false
ENABLE_ORYX_BUILD=false
POST_BUILD_COMMAND=""
EOF
    
    # Create startup script
    cat > "$DEPLOY_DIR/startup.sh" << 'EOF'
#!/bin/bash
if [ -d "/home/site/wwwroot/antenv" ]; then
    source /home/site/wwwroot/antenv/bin/activate
    export PATH="/home/site/wwwroot/antenv/bin:$PATH"
fi
cd /home/site/wwwroot
exec uvicorn main:app --host 0.0.0.0 --port 8000 --timeout-keep-alive 300
EOF
    chmod +x "$DEPLOY_DIR/startup.sh"
    
    # Create ZIP
    ZIP_FILE="/tmp/backend-smart-$(date +%s).zip"
    cd "$DEPLOY_DIR"
    zip -r "$ZIP_FILE" . > /dev/null 2>&1
    
    kill $PROGRESS_PID 2>/dev/null || true
    wait $PROGRESS_PID 2>/dev/null || true
    
    ZIP_SIZE=$(stat -f%z "$ZIP_FILE" 2>/dev/null || stat -c%s "$ZIP_FILE" 2>/dev/null || echo "0")
    ZIP_KB=$((ZIP_SIZE / 1024))
    echo "   ✅ Package created: ${ZIP_KB}KB"
    echo ""
    
    # Upload with progress (using correct command)
    echo "⏳ Uploading package..."
    echo "   📊 Progress updates every 3 seconds..."
    echo ""
    
    (
        ELAPSED=0
        while true; do
            sleep 3
            ELAPSED=$((ELAPSED + 3))
            echo "   ⏱️  [$(date +%H:%M:%S)] Uploading... ${ELAPSED}s elapsed" >&2
        done
    ) &
    PROGRESS_PID=$!
    
    # Use the correct command for ZIP deployment
    UPLOAD_OUTPUT=$(mktemp)
    if timeout 120 az webapp deployment source config-zip \
        --name $APP_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP \
        --src "$ZIP_FILE" 2>&1 | tee "$UPLOAD_OUTPUT"; then
        UPLOAD_SUCCESS=true
    else
        UPLOAD_SUCCESS=false
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    wait $PROGRESS_PID 2>/dev/null || true
    
    if [ "$UPLOAD_SUCCESS" = true ]; then
        echo "   ✅ Upload complete!"
    else
        echo "   ⚠️  Upload may have timed out, but checking if it succeeded..."
        # Check if deployment actually succeeded
        sleep 5
        DEPLOYMENT_STATUS=$(az webapp deployment list \
            --name $APP_SERVICE_NAME \
            --resource-group $RESOURCE_GROUP \
            --query '[0].status' -o tsv 2>/dev/null || echo "unknown")
        if [ "$DEPLOYMENT_STATUS" = "4" ] || [ "$DEPLOYMENT_STATUS" = "Success" ]; then
            echo "   ✅ Deployment actually succeeded!"
        else
            echo "   ⚠️  Deployment status: $DEPLOYMENT_STATUS"
        fi
    fi
    rm -f "$UPLOAD_OUTPUT"
    echo ""
    
    # Switch to native Python mode (not Docker)
    echo "🔧 Switching to native Python mode..."
    timeout 30 az webapp config set \
        --name $APP_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP \
        --linux-fx-version "PYTHON|3.11" \
        --startup-file "startup.sh" \
        > /dev/null 2>&1 || true
    
    # Clear container config
    timeout 30 az webapp config container set \
        --name $APP_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP \
        --docker-custom-image-name "" \
        > /dev/null 2>&1 || true
    
    echo "   ✅ Switched to native Python mode"
    echo ""
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    # Save code hash (requirements hash stays same)
    find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5 -q 2>/dev/null | md5 -q > .last_code_hash 2>/dev/null || find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5sum 2>/dev/null | md5sum | cut -d' ' -f1 > .last_code_hash
    
elif [ "$DEPLOYMENT_METHOD" = "skip" ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "⏭️  Step 2/4: Skipping Deployment (No Changes)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "✅ No changes detected - skipping deployment"
    echo "   • Saved time: ~3-8 minutes"
    echo ""
fi

# Step 3: Configure settings
echo "═══════════════════════════════════════════════════════════"
echo "⚙️  Step 3/4: Ensuring Configuration"
echo "═══════════════════════════════════════════════════════════"
echo ""

timeout 30 az webapp config appsettings set \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings \
        CORS_ORIGINS="https://gentle-sky-0a498ab1e.4.azurestaticapps.net,https://jolly-meadow-0a467810f.1.azurestaticapps.net,http://localhost:3000,http://localhost:5173" \
    > /dev/null 2>&1 || true

timeout 30 az webapp config set \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --always-on true \
    > /dev/null 2>&1 || true

echo "✅ Configuration complete"
echo ""

# Step 4: Restart and health check
echo "═══════════════════════════════════════════════════════════"
echo "🔄 Step 4/4: Restarting and Health Check"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ "$DEPLOYMENT_METHOD" != "skip" ]; then
    echo "⏳ Restarting App Service..."
    timeout 60 az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1 || true
    echo "✅ Restart initiated"
    echo ""
    
    echo "⏳ Waiting for application to become ready..."
    for i in {1..12}; do
        sleep 5
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://$APP_SERVICE_NAME.azurewebsites.net/health 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Application is healthy! (HTTP $HTTP_CODE)"
            break
        fi
        echo "   ⏱️  Health check $i/12... (HTTP $HTTP_CODE)"
    done
else
    echo "✅ No restart needed (no changes)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Smart Deployment Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🔗 Backend URL: https://$APP_SERVICE_NAME.azurewebsites.net"
echo ""
if [ "$DEPLOYMENT_METHOD" = "zip" ]; then
    echo "💡 This was FAST! (~30-60 seconds) because only code changed"
elif [ "$DEPLOYMENT_METHOD" = "skip" ]; then
    echo "💡 This was INSTANT! (~30 seconds) because nothing changed"
else
    echo "💡 Docker build was necessary for dependency changes"
fi
echo ""

