#!/bin/bash
# Configure auto-scaling for high availability video processing
# This ensures the service can handle multiple concurrent video processing requests

set -e

RESOURCE_GROUP="gait-analysis-rg-wus3"
PLAN_NAME="gait-analysis-plan"

echo "📈 Configuring Auto-Scaling for High Availability"
echo "=================================================="
echo ""

# Get the App Service Plan resource ID
PLAN_ID=$(az appservice plan show \
    --name "$PLAN_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query id -o tsv)

if [ -z "$PLAN_ID" ]; then
    echo "❌ Error: App Service Plan '$PLAN_NAME' not found!"
    exit 1
fi

echo "📋 App Service Plan: $PLAN_NAME"
echo "📋 Resource ID: $PLAN_ID"
echo ""

# Create or update auto-scale settings
echo "🔧 Creating/updating auto-scale settings..."

# Check if autoscale already exists
AUTOSCALE_NAME="${PLAN_NAME}-autoscale"
if az monitor autoscale show --name "$AUTOSCALE_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "   Updating existing auto-scale configuration..."
    az monitor autoscale update \
        --name "$AUTOSCALE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --min-count 2 \
        --max-count 10 \
        --count 3 \
        --output none
else
    echo "   Creating new auto-scale configuration..."
    az monitor autoscale create \
        --name "$AUTOSCALE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --resource "$PLAN_ID" \
        --min-count 2 \
        --max-count 10 \
        --count 3 \
        --output none
fi

echo "✅ Auto-scale settings: 2-10 instances, starting with 3"

# Remove existing rules (if any) and create new ones
echo ""
echo "📊 Configuring scaling rules..."

# Delete existing rules (ignore errors if they don't exist)
az monitor autoscale rule list \
    --autoscale-name "$AUTOSCALE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].name" -o tsv 2>/dev/null | while read rule_name; do
    if [ -n "$rule_name" ]; then
        az monitor autoscale rule delete \
            --autoscale-name "$AUTOSCALE_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --name "$rule_name" \
            --output none 2>/dev/null || true
    fi
done

# Scale out rule: When CPU > 70% for 5 minutes, add 1 instance
echo "   Adding scale-out rule (CPU > 70% for 5min → +1 instance)..."
az monitor autoscale rule create \
    --autoscale-name "$AUTOSCALE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --condition "Percentage CPU > 70 avg 5m" \
    --scale out 1 \
    --output none

# Scale in rule: When CPU < 30% for 10 minutes, remove 1 instance
echo "   Adding scale-in rule (CPU < 30% for 10min → -1 instance)..."
az monitor autoscale rule create \
    --autoscale-name "$AUTOSCALE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --condition "Percentage CPU < 30 avg 10m" \
    --scale in 1 \
    --output none

# Additional rule: Scale out on high memory usage
echo "   Adding memory-based scale-out rule (Memory > 80% for 5min → +1 instance)..."
az monitor autoscale rule create \
    --autoscale-name "$AUTOSCALE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --condition "Memory Percentage > 80 avg 5m" \
    --scale out 1 \
    --output none

echo "✅ Scaling rules configured"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Auto-Scaling Configuration Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Configuration:"
echo "  📊 Minimum instances: 2"
echo "  📊 Maximum instances: 10"
echo "  📊 Default instances: 3"
echo "  📊 Scale-out triggers:"
echo "     - CPU > 70% for 5 minutes"
echo "     - Memory > 80% for 5 minutes"
echo "  📊 Scale-in trigger:"
echo "     - CPU < 30% for 10 minutes"
echo ""
echo "Your service will automatically scale to handle video processing load!"
echo ""
