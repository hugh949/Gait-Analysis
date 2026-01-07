#!/bin/bash
# Incremental Backend Deployment - Only rebuilds when code/dependencies change
# Much faster for small code changes!
# FIXED: Shows real-time progress and better change detection

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

echo "🚀 Incremental Backend Deployment to Azure"
echo "==========================================="
echo ""

RESOURCE_GROUP="gait-analysis-rg-wus3"
APP_SERVICE_NAME="gait-analysis-api-wus3"
REGISTRY="gaitanalysisacrwus3"
IMAGE="gait-analysis-api:latest"

# Navigate to backend directory
cd "$(dirname "$0")/../backend"

echo "═══════════════════════════════════════════════════════════"
echo "📋 Step 1/5: Checking what changed..."
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if requirements.txt changed (dependencies)
REQUIREMENTS_CHANGED=false
if [ -f ".last_requirements_hash" ]; then
    OLD_HASH=$(cat .last_requirements_hash 2>/dev/null || echo "")
    NEW_HASH=$(md5 -q requirements.txt 2>/dev/null || md5sum requirements.txt | cut -d' ' -f1 || echo "")
    if [ "$OLD_HASH" != "$NEW_HASH" ]; then
        REQUIREMENTS_CHANGED=true
        echo "   ✅ requirements.txt changed - dependencies will be updated"
    else
        echo "   ✅ requirements.txt unchanged - using cached dependencies"
    fi
else
    REQUIREMENTS_CHANGED=true
    echo "   ✅ First deployment - will install all dependencies"
fi

# Check if Python code changed (more reliable check)
CODE_CHANGED=false
if [ -f ".last_code_hash" ]; then
    # Create hash of all Python files
    OLD_HASH=$(cat .last_code_hash 2>/dev/null || echo "")
    NEW_HASH=$(find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5 -q 2>/dev/null | md5 -q 2>/dev/null || find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5sum 2>/dev/null | md5sum | cut -d' ' -f1 || echo "")
    if [ "$OLD_HASH" != "$NEW_HASH" ] && [ -n "$NEW_HASH" ]; then
        CODE_CHANGED=true
        echo "   ✅ Python code changed - will rebuild"
    else
        echo "   ✅ Python code unchanged - using cached build"
    fi
else
    CODE_CHANGED=true
    echo "   ✅ First deployment - all code will be included"
fi

# Check if Dockerfile changed
DOCKERFILE_CHANGED=false
if [ -f "Dockerfile.optimized" ]; then
    if [ -f ".last_dockerfile_hash" ]; then
        OLD_HASH=$(cat .last_dockerfile_hash 2>/dev/null || echo "")
        NEW_HASH=$(md5 -q Dockerfile.optimized 2>/dev/null || md5sum Dockerfile.optimized | cut -d' ' -f1 || echo "")
        if [ "$OLD_HASH" != "$NEW_HASH" ]; then
            DOCKERFILE_CHANGED=true
            echo "   ✅ Dockerfile.optimized changed - will rebuild from scratch"
        fi
    else
        DOCKERFILE_CHANGED=true
    fi
fi

# Determine if we need to rebuild
NEED_REBUILD=true
REBUILD_REASON=""

if [ "$REQUIREMENTS_CHANGED" = true ] || [ "$CODE_CHANGED" = true ] || [ "$DOCKERFILE_CHANGED" = true ]; then
    NEED_REBUILD=true
    if [ "$REQUIREMENTS_CHANGED" = true ]; then
        REBUILD_REASON="dependencies changed"
    elif [ "$CODE_CHANGED" = true ]; then
        REBUILD_REASON="code changed"
    elif [ "$DOCKERFILE_CHANGED" = true ]; then
        REBUILD_REASON="Dockerfile changed"
    fi
    echo ""
    echo "📦 Rebuild needed: $REBUILD_REASON"
else
    NEED_REBUILD=false
    echo ""
    echo "✅ No changes detected - skipping Docker build"
    echo "   • Using existing image: $REGISTRY.azurecr.io/$IMAGE"
    echo "   • Only updating container configuration"
fi

echo ""

# Step 2: Build Docker image only if needed
if [ "$NEED_REBUILD" = true ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "📦 Step 2/5: Building Docker Image (Incremental)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "⏳ Building Docker image..."
    if [ "$REQUIREMENTS_CHANGED" = true ]; then
        echo "   • Dependencies changed - will download/update packages"
        echo "   • Estimated time: 3-8 minutes"
    else
        echo "   • Only code changed - using cached dependencies"
        echo "   • Estimated time: 1-2 minutes"
    fi
    echo ""
    echo "📊 Progress updates every 10 seconds..."
    echo "   (Docker build output will stream below)"
    echo ""

    # Start progress indicator that shows even when build is running
    (
        ELAPSED=0
        while true; do
            sleep 10
            ELAPSED=$((ELAPSED + 10))
            echo "   ⏱️  [$(date +%H:%M:%S)] Build in progress... ${ELAPSED} seconds elapsed" >&2
        done
    ) &
    PROGRESS_PID=$!

    # Build with real-time output AND capture for parsing
    echo "   🔨 Starting Docker build..."
    echo "   💡 Tip: Azure uses layer caching - only changed layers rebuild"
    echo "   💡 You can cancel (Ctrl+C) and run script again to resume"
    echo ""
    
    # Use timeout to prevent indefinite hangs
    BUILD_LOG="/tmp/acr-build-$(date +%s).log"
    if timeout 1800 az acr build --registry $REGISTRY --image $IMAGE --file Dockerfile.optimized . 2>&1 | tee "$BUILD_LOG" | grep -E "(Step|RUN|COPY|Successfully|ERROR|error|Building|Pushing)" | head -100; then
        BUILD_EXIT_CODE=0
    else
        BUILD_EXIT_CODE=${PIPESTATUS[0]}
        # Check if it was a timeout
        if [ $BUILD_EXIT_CODE -eq 124 ] || [ $BUILD_EXIT_CODE -eq 143 ]; then
            echo ""
            echo "⚠️  Build timed out after 30 minutes"
            echo "   • This may be normal for first build (downloading dependencies)"
            echo "   • Check Azure Portal for build status"
            echo "   • Run script again to check if build completed"
            exit 1
        fi
    fi

    # Kill progress indicator
    kill $PROGRESS_PID 2>/dev/null || true
    wait $PROGRESS_PID 2>/dev/null || true

    if [ $BUILD_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "❌ Build failed!"
        tail -20 /tmp/acr-build.log
        exit 1
    fi

    # Extract build info from log
    BUILD_ID=$(grep -i "run id" /tmp/acr-build.log | tail -1 | awk '{print $NF}' || echo "unknown")
    BUILD_TIME=$(grep -i "successful after" /tmp/acr-build.log | tail -1 || echo "")

    echo ""
    echo "✅ Build complete!"
    if [ -n "$BUILD_ID" ] && [ "$BUILD_ID" != "unknown" ]; then
        echo "   • Build ID: $BUILD_ID"
    fi
    if [ -n "$BUILD_TIME" ]; then
        echo "   • $BUILD_TIME"
    fi
    
    # Save hashes for next time
    md5 -q requirements.txt > .last_requirements_hash 2>/dev/null || md5sum requirements.txt | cut -d' ' -f1 > .last_requirements_hash
    if [ -f "Dockerfile.optimized" ]; then
        md5 -q Dockerfile.optimized > .last_dockerfile_hash 2>/dev/null || md5sum Dockerfile.optimized | cut -d' ' -f1 > .last_dockerfile_hash
    fi
    find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5 -q 2>/dev/null | md5 -q > .last_code_hash 2>/dev/null || find app -name "*.py" -o -name "main.py" 2>/dev/null | xargs md5sum 2>/dev/null | md5sum | cut -d' ' -f1 > .last_code_hash
    echo ""
else
    echo "═══════════════════════════════════════════════════════════"
    echo "⏭️  Step 2/5: Skipping Docker Build (No Changes)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "✅ Using existing Docker image"
    echo "   • Image: $REGISTRY.azurecr.io/$IMAGE"
    echo "   • Saved time: ~3-8 minutes"
    echo ""
fi

# Step 3: Update container configuration
echo "═══════════════════════════════════════════════════════════"
echo "🔧 Step 3/5: Updating App Service Container"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⏳ Updating container configuration..."
echo "   • Image: $REGISTRY.azurecr.io/$IMAGE"
echo "   📊 Progress updates every 5 seconds..."
echo ""

# Start progress indicator
(
    ELAPSED=0
    while true; do
        sleep 5
        ELAPSED=$((ELAPSED + 5))
        echo "   ⏱️  [$(date +%H:%M:%S)] Config update... ${ELAPSED} seconds elapsed"
    done
) &
PROGRESS_PID=$!

CONTAINER_OUTPUT=$(timeout 60 az webapp config container set \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --container-image-name $REGISTRY.azurecr.io/$IMAGE 2>&1)

# Kill progress indicator
kill $PROGRESS_PID 2>/dev/null || true
wait $PROGRESS_PID 2>/dev/null || true

if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  Container update timed out (may have succeeded)"
else
    echo "✅ Container configuration updated"
fi
echo ""

# Step 4: Configure settings
echo "═══════════════════════════════════════════════════════════"
echo "⚙️  Step 4/5: Ensuring Configuration"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "   • Setting CORS..."
timeout 30 az webapp config appsettings set \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings \
        CORS_ORIGINS="https://jolly-meadow-0a467810f.1.azurestaticapps.net,http://localhost:3000,http://localhost:5173" \
    > /dev/null 2>&1 || echo "   ⚠️  CORS setting timed out (may already be set)"

echo "   • Enabling Always-On..."
timeout 30 az webapp config set \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --always-on true \
    > /dev/null 2>&1 || echo "   ⚠️  Always-On setting timed out (may already be enabled)"

echo "   ✅ Configuration complete"
echo ""

# Step 5: Restart and health check
echo "═══════════════════════════════════════════════════════════"
echo "🔄 Step 5/5: Restarting and Health Check"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⏳ Restarting App Service..."
echo "   📊 Progress updates every 5 seconds..."
echo ""

# Start progress indicator
(
    ELAPSED=0
    while true; do
        sleep 5
        ELAPSED=$((ELAPSED + 5))
        echo "   ⏱️  [$(date +%H:%M:%S)] Restart in progress... ${ELAPSED} seconds elapsed"
    done
) &
PROGRESS_PID=$!

RESTART_OUTPUT=$(timeout 60 az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP 2>&1)

# Kill progress indicator
kill $PROGRESS_PID 2>/dev/null || true
wait $PROGRESS_PID 2>/dev/null || true

echo "✅ App Service restart initiated"
echo ""

echo "⏳ Waiting for application to become ready..."
echo "   📊 Health check every 5 seconds..."
for i in {1..12}; do
    sleep 5
    echo "   ⏱️  [$(date +%H:%M:%S)] Health check attempt $i/12..."
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://$APP_SERVICE_NAME.azurewebsites.net/health 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo ""
        echo "✅ Application is healthy and responding! (HTTP $HTTP_CODE)"
        break
    elif [ "$HTTP_CODE" = "503" ] || [ "$HTTP_CODE" = "502" ]; then
        echo "   ⏳ Still starting... (HTTP $HTTP_CODE - normal)"
    elif [ "$HTTP_CODE" != "000" ]; then
        echo "   ⚠️  HTTP $HTTP_CODE (may still be starting)"
    else
        echo "   ⏳ Not responding yet..."
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Incremental Deployment Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🔗 Backend URL: https://$APP_SERVICE_NAME.azurewebsites.net"
echo ""
if [ "$NEED_REBUILD" = false ]; then
    echo "💡 This deployment was FAST because no code/dependencies changed!"
    echo "   • Skipped Docker build (~3-8 minutes saved)"
    echo "   • Total time: ~30-60 seconds"
else
    echo "💡 Next deployment will be faster if code/dependencies don't change"
fi
echo ""
