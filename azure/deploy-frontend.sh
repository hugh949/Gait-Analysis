#!/bin/bash
# Deploy Frontend to Static Web App

echo "Deploying frontend to Static Web App..."

cd "$(dirname "$0")/../frontend"

# Check if dist folder exists
if [ ! -d "dist" ]; then
    echo "Building frontend..."
    npm run build
fi

# Get deployment token
echo "Getting deployment token..."
TOKEN=$(az staticwebapp secrets list \
  --name gait-analysis-web \
  --resource-group gait-analysis-rg-eus2 \
  --query deploymentToken -o tsv 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "⚠️  Could not get deployment token automatically."
    echo "Please get it from Azure Portal:"
    echo "1. Go to Static Web App 'gait-analysis-web'"
    echo "2. Navigate to 'Manage deployment token'"
    echo "3. Copy the token and run:"
    echo "   swa deploy ./dist --deployment-token <your-token>"
    exit 1
fi

# Deploy using SWA CLI if available
if command -v swa &> /dev/null; then
    echo "Deploying with SWA CLI..."
    swa deploy ./dist --deployment-token "$TOKEN" --env production
else
    echo "SWA CLI not installed. Installing..."
    npm install -g @azure/static-web-apps-cli
    swa deploy ./dist --deployment-token "$TOKEN" --env production
fi

echo ""
echo "✅ Frontend deployment initiated!"
echo "Frontend URL: https://gentle-wave-0d4e1d10f.4.azurestaticapps.net"

