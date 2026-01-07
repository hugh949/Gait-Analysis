#!/bin/bash
# Create Azure Service Principal for GitHub Actions
# This generates the JSON needed for the AZURE_CREDENTIALS secret

set -e

RESOURCE_GROUP="gait-analysis-rg-wus3"
SP_NAME="gait-analysis-github-actions"

echo "🔐 Creating Azure Service Principal for GitHub Actions"
echo "======================================================"
echo ""

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "📋 Configuration:"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Tenant ID: $TENANT_ID"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   Service Principal Name: $SP_NAME"
echo ""

# Check if service principal already exists
EXISTING_SP=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_SP" ] && [ "$EXISTING_SP" != "null" ]; then
    echo "⚠️  Service Principal '$SP_NAME' already exists!"
    echo ""
    echo "Options:"
    echo "1. Delete the existing one and create a new one"
    echo "2. Reset the password for the existing one"
    echo ""
    read -p "Delete and recreate? (y/N): " RECREATE
    
    if [ "$RECREATE" = "y" ] || [ "$RECREATE" = "Y" ]; then
        echo "🗑️  Deleting existing service principal..."
        az ad sp delete --id "$EXISTING_SP" 2>/dev/null || true
        echo "✅ Deleted"
    else
        echo "🔄 Resetting password for existing service principal..."
        SP_JSON=$(az ad sp credential reset --id "$EXISTING_SP" --sdk-auth 2>/dev/null || echo "")
        if [ -n "$SP_JSON" ]; then
            echo ""
            echo "✅ Service Principal Credentials (JSON):"
            echo "═══════════════════════════════════════════════════════════"
            echo "$SP_JSON"
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            echo "📝 Copy the ENTIRE JSON above and add it to GitHub:"
            echo "   1. Go to: https://github.com/hugh949/Gait-Analysis/settings/secrets/actions"
            echo "   2. Click 'New repository secret'"
            echo "   3. Name: AZURE_CREDENTIALS"
            echo "   4. Value: Paste the JSON above"
            echo "   5. Click 'Add secret'"
            exit 0
        fi
    fi
fi

echo "🔨 Creating new service principal..."
echo ""

# Create service principal with SDK auth format
SP_JSON=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role contributor \
    --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
    --sdk-auth \
    --output json)

if [ -z "$SP_JSON" ] || [ "$SP_JSON" = "null" ]; then
    echo "❌ Failed to create service principal"
    exit 1
fi

echo ""
echo "✅ Service Principal Created Successfully!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📋 Service Principal Credentials (JSON):"
echo "═══════════════════════════════════════════════════════════"
echo "$SP_JSON"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verify JSON format
if echo "$SP_JSON" | grep -q '"clientId"'; then
    echo "✅ JSON format verified (contains clientId)"
else
    echo "⚠️  Warning: JSON may be missing required fields"
fi

echo ""
echo "📝 Next Steps:"
echo "   1. Copy the ENTIRE JSON above (everything between the lines)"
echo "   2. Go to: https://github.com/hugh949/Gait-Analysis/settings/secrets/actions"
echo "   3. Click 'New repository secret'"
echo "   4. Name: AZURE_CREDENTIALS"
echo "   5. Value: Paste the JSON (make sure it's valid JSON)"
echo "   6. Click 'Add secret'"
echo ""
echo "🔍 Verify the JSON contains these fields:"
echo "   - clientId"
echo "   - clientSecret"
echo "   - subscriptionId"
echo "   - tenantId"
echo ""
echo "✅ After adding the secret, GitHub Actions will be able to deploy to Azure!"

