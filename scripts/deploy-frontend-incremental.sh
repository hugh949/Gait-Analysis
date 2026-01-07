#!/bin/bash
# Incremental Frontend Deployment - Only rebuilds when code/dependencies change
# Much faster for small code changes!

set -e

echo "🚀 Incremental Frontend Deployment to Azure"
echo "============================================"
echo ""

DEPLOYMENT_TOKEN="d19afc06fc8fbc344789453cfe2e37f4879d0066b305fdb18f26e025618aa0a304-98907e59-86cf-4e90-a218-f90b7c6ebebc01e19240a498ab1e"

# Navigate to frontend directory
cd "$(dirname "$0")/../frontend"

echo "📋 Step 1/4: Checking what changed..."
echo ""

# Check if package.json changed (dependencies)
PACKAGE_JSON_CHANGED=false
if [ -f ".last_package_hash" ]; then
    OLD_HASH=$(cat .last_package_hash 2>/dev/null || echo "")
    NEW_HASH=$(md5 -q package.json 2>/dev/null || md5sum package.json | cut -d' ' -f1 || echo "")
    if [ "$OLD_HASH" != "$NEW_HASH" ]; then
        PACKAGE_JSON_CHANGED=true
        echo "   ✅ package.json changed - dependencies will be updated"
    else
        echo "   ✅ package.json unchanged - using cached node_modules"
    fi
else
    PACKAGE_JSON_CHANGED=true
    echo "   ✅ First deployment - will install all dependencies"
fi

# Check if source code changed
CODE_CHANGED=false
if [ -f ".last_build_time" ]; then
    LAST_BUILD=$(cat .last_build_time 2>/dev/null || echo "0")
    # Check if any source files changed
    SOURCE_FILES=$(find src -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.css" -o -name "*.json" \) 2>/dev/null)
    for file in $SOURCE_FILES; do
        if [ -f "$file" ]; then
            FILE_MODIFIED=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo "0")
            if [ "$FILE_MODIFIED" -gt "$LAST_BUILD" ]; then
                CODE_CHANGED=true
                echo "   ✅ Code changed: $file"
                break
            fi
        fi
    done
    
    # Also check package.json, vite.config, etc.
    for file in package.json vite.config.ts tsconfig.json index.html; do
        if [ -f "$file" ]; then
            FILE_MODIFIED=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo "0")
            if [ "$FILE_MODIFIED" -gt "$LAST_BUILD" ]; then
                CODE_CHANGED=true
                echo "   ✅ Config changed: $file"
                break
            fi
        fi
    done
else
    CODE_CHANGED=true
    echo "   ✅ First deployment - all code will be built"
fi

# Determine if we need to rebuild
NEED_REBUILD=true
REBUILD_REASON=""

if [ "$PACKAGE_JSON_CHANGED" = true ] || [ "$CODE_CHANGED" = true ]; then
    NEED_REBUILD=true
    if [ "$PACKAGE_JSON_CHANGED" = true ]; then
        REBUILD_REASON="dependencies changed"
    elif [ "$CODE_CHANGED" = true ]; then
        REBUILD_REASON="code changed"
    fi
    echo ""
    echo "📦 Rebuild needed: $REBUILD_REASON"
else
    NEED_REBUILD=false
    echo ""
    echo "✅ No changes detected - skipping build"
    echo "   • Using existing dist/ folder"
fi

echo ""

# Step 2: Build only if needed
if [ "$NEED_REBUILD" = true ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "📦 Step 2/4: Building Frontend (Incremental)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if [ "$PACKAGE_JSON_CHANGED" = true ]; then
        echo "⏳ Installing/updating dependencies..."
        echo "   • This may take 1-2 minutes if packages changed"
        npm install
        echo "   ✅ Dependencies installed"
        echo ""
    else
        echo "✅ Dependencies unchanged - skipping npm install"
        echo ""
    fi
    
    echo "⏳ Building frontend..."
    if [ "$PACKAGE_JSON_CHANGED" = true ]; then
        echo "   • Estimated time: 1-2 minutes (with dependency install)"
    else
        echo "   • Estimated time: 30-60 seconds (code only)"
    fi
    echo "   📊 Progress updates every 15 seconds..."
    echo ""

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
    
    # Save hashes for next time
    md5 -q package.json > .last_package_hash 2>/dev/null || md5sum package.json | cut -d' ' -f1 > .last_package_hash
    date +%s > .last_build_time
    echo ""
else
    echo "═══════════════════════════════════════════════════════════"
    echo "⏭️  Step 2/4: Skipping Build (No Changes)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "✅ Using existing build in dist/ folder"
    echo "   • Saved time: ~1-2 minutes"
    echo ""
fi

# Step 3: Deploy
echo "═══════════════════════════════════════════════════════════"
echo "🚀 Step 3/4: Deploying to Azure Static Web Apps"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⏳ Uploading files to Azure..."
echo "   • Estimated time: 30-60 seconds"
echo "   📊 Progress updates every 10 seconds..."
echo ""

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
echo "═══════════════════════════════════════════════════════════"
echo "✅ Incremental Deployment Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🔗 App URL: https://gentle-sky-0a498ab1e.4.azurestaticapps.net"
echo ""
if [ "$NEED_REBUILD" = false ]; then
    echo "💡 This deployment was FAST because no code/dependencies changed!"
    echo "   • Skipped build (~1-2 minutes saved)"
fi
echo ""

