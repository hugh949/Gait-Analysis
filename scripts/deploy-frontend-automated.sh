#!/bin/bash
# Automated Frontend Deployment Script
# This script builds and deploys the frontend to Azure Static Web App
# Designed to be reliable and runnable in CI/CD pipelines

set -e  # Exit on error

RESOURCE_GROUP="gait-analysis-rg-eus2"
STATIC_WEB_APP_NAME="gait-analysis-web-eus2"
FRONTEND_DIR="frontend"
BUILD_DIR="dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Automated Frontend Deployment"
echo "================================"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Step 1: Verify prerequisites
print_status "Step 1/5: Checking prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run: az login"
    exit 1
fi

print_status "Azure CLI is installed and authenticated"

# Check if frontend directory exists
if [ ! -d "$FRONTEND_DIR" ]; then
    print_error "Frontend directory not found: $FRONTEND_DIR"
    exit 1
fi

print_status "Prerequisites check passed"
echo ""

# Step 2: Build frontend
print_status "Step 2/5: Building frontend..."

cd "$FRONTEND_DIR"

# Check if node_modules exists, install if not
if [ ! -d "node_modules" ]; then
    print_warning "node_modules not found. Installing dependencies..."
    npm install
fi

# Build the frontend
print_status "Running build..."
if npm run build; then
    print_status "Build completed successfully"
else
    print_error "Build failed"
    exit 1
fi

# Verify build output exists (we're in frontend directory)
if [ ! -d "$BUILD_DIR" ]; then
    print_error "Build output directory not found: $BUILD_DIR"
    exit 1
fi

# Count files in build
FILE_COUNT=$(find "$BUILD_DIR" -type f | wc -l | tr -d ' ')
print_status "Build contains $FILE_COUNT files"

# Stay in frontend directory for deployment
echo ""

# Step 3: Get deployment token (optional - can be passed as env var)
print_status "Step 3/5: Getting deployment token..."

# Check if token is provided as environment variable
if [ -n "$AZURE_STATIC_WEB_APPS_API_TOKEN" ]; then
    print_status "Using deployment token from environment variable"
    DEPLOYMENT_TOKEN="$AZURE_STATIC_WEB_APPS_API_TOKEN"
else
    # Try to get token from Azure CLI
    print_status "Attempting to retrieve deployment token from Azure..."
    DEPLOYMENT_TOKEN=$(az staticwebapp secrets list \
        --name "$STATIC_WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query deploymentToken -o tsv 2>/dev/null)
    
    # Check if token was retrieved
    if [ -z "$DEPLOYMENT_TOKEN" ] || [ "$DEPLOYMENT_TOKEN" == "null" ] || [ "$DEPLOYMENT_TOKEN" == "" ]; then
        print_warning "Could not retrieve deployment token automatically"
        print_warning ""
        print_warning "You can get the token from Azure Portal:"
        print_warning "  1. Go to: https://portal.azure.com"
        print_warning "  2. Navigate to: Resource Groups → $RESOURCE_GROUP → $STATIC_WEB_APP_NAME"
        print_warning "  3. Click 'Overview' → Look for 'Deployment token' or 'Manage deployment token'"
        print_warning ""
        print_warning "Then run the script with the token:"
        print_warning "  AZURE_STATIC_WEB_APPS_API_TOKEN='your-token' ./scripts/deploy-frontend-automated.sh"
        print_warning ""
        print_warning "Alternatively, use Azure Portal to deploy manually:"
        print_warning "  - Go to Deployment Center → Manual upload"
        print_warning "  - Upload contents of: $FRONTEND_DIR/$BUILD_DIR"
        print_warning ""
        print_warning "Or set up GitHub Actions for automatic deployment (see AUTOMATIC_DEPLOYMENT_SETUP.md)"
        exit 1
    fi
fi

print_status "Deployment token retrieved successfully"
echo ""

# Step 4: Deploy using SWA CLI or Azure CLI
print_status "Step 4/5: Deploying to Azure Static Web App..."

# We're already in frontend directory
# Try SWA CLI first (preferred method)
if command -v swa &> /dev/null; then
    print_status "Using SWA CLI for deployment..."
    
    if swa deploy "$BUILD_DIR" --deployment-token "$DEPLOYMENT_TOKEN" --env production; then
        print_status "Deployment completed successfully"
        DEPLOYMENT_SUCCESS=true
    else
        print_error "SWA CLI deployment failed"
        DEPLOYMENT_SUCCESS=false
    fi
    
# Fallback to npx if swa not installed globally
elif command -v npx &> /dev/null; then
    print_status "Using npx SWA CLI for deployment..."
    
    if npx -y @azure/static-web-apps-cli deploy "$BUILD_DIR" --deployment-token "$DEPLOYMENT_TOKEN" --env production; then
        print_status "Deployment completed successfully"
        DEPLOYMENT_SUCCESS=true
    else
        print_error "npx SWA CLI deployment failed"
        DEPLOYMENT_SUCCESS=false
    fi
    
# Last resort: Azure CLI (if available)
elif az staticwebapp deploy --help &> /dev/null 2>&1; then
    print_warning "SWA CLI not available, trying Azure CLI..."
    
    # Create zip file for deployment
    ZIP_FILE="dist-$(date +%Y%m%d-%H%M%S).zip"
    zip -r "$ZIP_FILE" "$BUILD_DIR"/
    
    if az staticwebapp deploy \
        --name "$STATIC_WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --artifact-location "$BUILD_DIR" \
        --token "$DEPLOYMENT_TOKEN"; then
        print_status "Deployment completed successfully"
        DEPLOYMENT_SUCCESS=true
        rm -f "$ZIP_FILE"
    else
        print_error "Azure CLI deployment failed"
        DEPLOYMENT_SUCCESS=false
    fi
else
    print_error "No deployment method available. Please install SWA CLI or use Azure Portal."
    print_warning "Install SWA CLI: npm install -g @azure/static-web-apps-cli"
    exit 1
fi

if [ "$DEPLOYMENT_SUCCESS" != "true" ]; then
    print_error "All deployment methods failed"
    exit 1
fi

echo ""

# Step 5: Verify deployment
print_status "Step 5/5: Verifying deployment..."

# Go back to project root for Azure CLI
cd "$(dirname "$0")/.."

STATIC_WEB_APP_URL=$(az staticwebapp show \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query defaultHostname -o tsv 2>/dev/null)

if [ -n "$STATIC_WEB_APP_URL" ]; then
    print_status "Deployment URL: https://${STATIC_WEB_APP_URL}"
    
    # Wait a few seconds for deployment to propagate
    print_status "Waiting for deployment to propagate (10 seconds)..."
    sleep 10
    
    # Check if site is accessible
    if curl -s -f -m 10 "https://${STATIC_WEB_APP_URL}" > /dev/null 2>&1; then
        print_status "✅ Site is accessible!"
    else
        print_warning "Site may still be deploying. Check manually: https://${STATIC_WEB_APP_URL}"
    fi
else
    print_warning "Could not retrieve Static Web App URL"
fi

echo ""
echo "================================"
print_status "Deployment process completed!"
echo ""
echo "Frontend URL: https://${STATIC_WEB_APP_URL}"
echo ""
echo "Next steps:"
echo "  1. Visit the URL above to verify the new version"
echo "  2. Test the upload flow"
echo "  3. Check sequential step progress"
echo ""

