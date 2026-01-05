#!/bin/bash
# Get Deployment Token for Azure Static Web App
# This is a helper script to get the deployment token

STATIC_WEB_APP_NAME="gait-analysis-web-eus2"
RESOURCE_GROUP="gait-analysis-rg-eus2"

echo "Getting deployment token for: $STATIC_WEB_APP_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Method 1: Try secrets list
echo "Method 1: Trying az staticwebapp secrets list..."
TOKEN=$(az staticwebapp secrets list \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query deploymentToken -o tsv 2>&1)

if [ $? -eq 0 ] && [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo "✅ Token retrieved successfully!"
    echo ""
    echo "Deployment Token:"
    echo "$TOKEN"
    echo ""
    exit 0
fi

echo "Method 1 failed: $TOKEN"
echo ""

# Method 2: Try different query
echo "Method 2: Trying alternative query..."
TOKEN=$(az staticwebapp show \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query deploymentToken -o tsv 2>&1)

if [ $? -eq 0 ] && [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo "✅ Token retrieved successfully!"
    echo ""
    echo "Deployment Token:"
    echo "$TOKEN"
    echo ""
    exit 0
fi

echo "Method 2 also failed"
echo ""

# Method 3: Try using management API
echo "Method 3: Instructions for getting token from Azure Portal..."
echo ""
echo "To get the deployment token:"
echo "1. Go to Azure Portal: https://portal.azure.com"
echo "2. Navigate to: Resource Groups → $RESOURCE_GROUP → $STATIC_WEB_APP_NAME"
echo "3. Click 'Overview' or 'Manage deployment token' in the left menu"
echo "4. Copy the deployment token"
echo ""
echo "Or use this command in Azure Portal Cloud Shell:"
echo "az staticwebapp secrets list --name $STATIC_WEB_APP_NAME --resource-group $RESOURCE_GROUP --query deploymentToken -o tsv"
echo ""
exit 1

