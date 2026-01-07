#!/bin/bash
# Fix App Service ACR Authentication and Configuration
# This fixes the 503 error by ensuring ACR password is set

set -e

RESOURCE_GROUP="gait-analysis-rg-wus3"
APP_NAME="gaitanalysisapp"
REGISTRY="gaitacr737"

echo "🔧 Fixing App Service ACR Authentication..."
echo "============================================"
echo ""

# Get ACR credentials
echo "1. Getting ACR credentials..."
ACR_LOGIN=$(az acr show --name "$REGISTRY" --query loginServer -o tsv)
ACR_USER=$(az acr credential show --name "$REGISTRY" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$REGISTRY" --query passwords[0].value -o tsv)

echo "   Registry: $ACR_LOGIN"
echo "   Username: $ACR_USER"
echo "   Password: ${ACR_PASS:0:10}..."
echo ""

# Get current image name
CURRENT_IMAGE=$(az webapp config container show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "DOCKER_CUSTOM_IMAGE_NAME" -o tsv 2>/dev/null || echo "")
if [ -z "$CURRENT_IMAGE" ] || [ "$CURRENT_IMAGE" = "null" ]; then
    CURRENT_IMAGE="$ACR_LOGIN/gait-integrated:latest"
    echo "   Using default image: $CURRENT_IMAGE"
else
    echo "   Current image: $CURRENT_IMAGE"
fi
echo ""

# Set container configuration with ACR credentials
echo "2. Setting container configuration with ACR authentication..."
az webapp config container set \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --docker-custom-image-name "$CURRENT_IMAGE" \
    --docker-registry-server-url "https://$ACR_LOGIN" \
    --docker-registry-server-user "$ACR_USER" \
    --docker-registry-server-password "$ACR_PASS" \
    > /dev/null 2>&1

echo "✅ Container configuration updated"
echo ""

# Also set via app settings (backup method)
echo "3. Setting ACR password via app settings (backup)..."
az webapp config appsettings set \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASS" \
    > /dev/null 2>&1

echo "✅ ACR password set via app settings"
echo ""

# Ensure WEBSITES_PORT is set
echo "4. Ensuring WEBSITES_PORT=8000..."
az webapp config appsettings set \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings WEBSITES_PORT=8000 \
    > /dev/null 2>&1

echo "✅ WEBSITES_PORT=8000 set"
echo ""

# Ensure CORS is configured
echo "5. Ensuring CORS configuration..."
az webapp config appsettings set \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings CORS_ORIGINS="https://gentle-sky-0a498ab1e.4.azurestaticapps.net,https://gaitanalysisapp.azurewebsites.net,http://localhost:3000,http://localhost:5173" \
    > /dev/null 2>&1

echo "✅ CORS configured"
echo ""

# Verify configuration
echo "6. Verifying configuration..."
ACR_PASS_CHECK=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DOCKER_REGISTRY_SERVER_PASSWORD'].value" -o tsv)
PORT_CHECK=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='WEBSITES_PORT'].value" -o tsv)
CORS_CHECK=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='CORS_ORIGINS'].value" -o tsv)

echo "   ACR Password: $([ -n "$ACR_PASS_CHECK" ] && [ "$ACR_PASS_CHECK" != "null" ] && echo "✅ Set" || echo "❌ Not set")"
echo "   WEBSITES_PORT: $([ "$PORT_CHECK" = "8000" ] && echo "✅ $PORT_CHECK" || echo "❌ $PORT_CHECK")"
echo "   CORS_ORIGINS: $([ -n "$CORS_CHECK" ] && echo "✅ Set" || echo "❌ Not set")"
echo ""

# Restart App Service
echo "7. Restarting App Service..."
az webapp restart --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1
echo "✅ App Service restarted"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "✅ Configuration Fix Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⏳ Waiting 90 seconds for container to start..."
sleep 90
echo ""

echo "🧪 Testing application..."
APP_URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)
for i in {1..15}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$APP_URL/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo ""
        echo "✅✅✅ APPLICATION IS WORKING! (HTTP $HTTP_CODE)"
        echo ""
        curl -s --max-time 10 "https://$APP_URL/health" | python3 -m json.tool 2>/dev/null
        echo ""
        echo "🔗 Application URL: https://$APP_URL"
        exit 0
    else
        echo "   Check $i/15... (HTTP $HTTP_CODE)"
        sleep 8
    fi
done

echo ""
echo "⚠️  Application not responding yet. Check Azure Portal logs."
