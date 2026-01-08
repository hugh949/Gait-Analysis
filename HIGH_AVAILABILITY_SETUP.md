# High Availability Configuration for Gait Analysis Service

This document describes the high availability setup for maximum service availability and performance.

## Overview

The service is configured for **maximum availability** with cost not being a constraint. The configuration ensures:

- ✅ **Multiple instances** (2-10) for redundancy and load distribution
- ✅ **Auto-scaling** based on CPU and memory usage
- ✅ **Premium App Service Plan** (P1v3) for high performance
- ✅ **Standard SQL Database** (S2) for better performance
- ✅ **Health checks** and monitoring
- ✅ **Multiple workers per instance** for concurrent video processing

## Architecture

### App Service Plan
- **Tier**: Premium V3 (P1v3)
- **Minimum instances**: 2
- **Maximum instances**: 10
- **Default instances**: 3
- **Auto-scaling**: Enabled

### Auto-Scaling Rules
- **Scale Out** (add instances):
  - CPU > 70% for 5 minutes → +1 instance
  - Memory > 80% for 5 minutes → +1 instance
- **Scale In** (remove instances):
  - CPU < 30% for 10 minutes → -1 instance

### Workers per Instance
- **Default**: 4 workers per instance
- **Configurable**: Via `WEBSITES_WORKER_PROCESSES` environment variable
- **Total capacity**: Up to 40 concurrent workers (10 instances × 4 workers)

### SQL Database
- **Tier**: S2 (Standard)
- **Performance**: Better than Basic tier for concurrent operations

### Azure Container Registry
- **Tier**: Standard
- **Features**: Better performance and reliability

## Setup Instructions

### Option 1: Automated Setup (Recommended)

Run the upgrade script:

```bash
./scripts/upgrade-to-high-availability.sh
```

This will:
1. Upgrade App Service Plan to Premium V3
2. Configure auto-scaling (2-10 instances)
3. Upgrade SQL Database to S2
4. Upgrade ACR to Standard
5. Configure health checks
6. Set minimum instances to 2

### Option 2: Manual Setup

#### 1. Upgrade App Service Plan

```bash
az appservice plan update \
    --name gait-analysis-plan \
    --resource-group gait-analysis-rg-wus3 \
    --sku P1V3
```

#### 2. Configure Auto-Scaling

```bash
./scripts/configure-auto-scaling.sh
```

#### 3. Set Minimum Instances

```bash
az appservice plan update \
    --name gait-analysis-plan \
    --resource-group gait-analysis-rg-wus3 \
    --number-of-workers 2
```

#### 4. Configure App Service

```bash
az webapp config set \
    --name gaitanalysisapp \
    --resource-group gait-analysis-rg-wus3 \
    --always-on true \
    --request-timeout 600 \
    --http20-enabled true

az webapp config update \
    --name gaitanalysisapp \
    --resource-group gait-analysis-rg-wus3 \
    --set healthCheckPath="/health"

az webapp config appsettings set \
    --name gaitanalysisapp \
    --resource-group gait-analysis-rg-wus3 \
    --settings WEBSITES_WORKER_PROCESSES=4
```

#### 5. Upgrade SQL Database

```bash
SQL_SERVER=$(az sql server list --resource-group gait-analysis-rg-wus3 --query "[0].name" -o tsv)
az sql db update \
    --resource-group gait-analysis-rg-wus3 \
    --server "$SQL_SERVER" \
    --name gaitanalysis \
    --service-objective S2
```

## Monitoring

### Health Checks
- **Path**: `/health`
- **Frequency**: Every 30 seconds
- **Action**: Unhealthy instances are automatically replaced

### Metrics to Monitor
- **CPU Usage**: Should stay below 70% for optimal performance
- **Memory Usage**: Should stay below 80%
- **Instance Count**: Automatically adjusts based on load
- **Request Count**: Tracks concurrent video processing requests
- **Response Time**: Should be monitored for video processing endpoints

### View Auto-Scaling Status

```bash
az monitor autoscale show \
    --name gait-analysis-plan-autoscale \
    --resource-group gait-analysis-rg-wus3
```

### View Current Instance Count

```bash
az appservice plan show \
    --name gait-analysis-plan \
    --resource-group gait-analysis-rg-wus3 \
    --query sku.capacity
```

## Performance Characteristics

### Concurrent Video Processing
- **Per instance**: 4 workers = 4 concurrent videos
- **Minimum (2 instances)**: 8 concurrent videos
- **Maximum (10 instances)**: 40 concurrent videos
- **Default (3 instances)**: 12 concurrent videos

### Request Timeout
- **Configured**: 600 seconds (10 minutes)
- **Purpose**: Allows long-running video processing without timeout

### Always On
- **Enabled**: Yes
- **Purpose**: Prevents cold starts and ensures immediate availability

## Cost Considerations

This configuration prioritizes availability over cost:

- **Premium V3 Plan**: ~$146/month per instance (minimum 2 = ~$292/month)
- **SQL Database S2**: ~$75/month
- **ACR Standard**: ~$5/month
- **Total minimum**: ~$372/month
- **Total maximum (10 instances)**: ~$1,460/month + SQL + ACR

## Troubleshooting

### Check Auto-Scaling Status

```bash
az monitor autoscale show \
    --name gait-analysis-plan-autoscale \
    --resource-group gait-analysis-rg-wus3 \
    --output table
```

### View Scaling History

```bash
az monitor autoscale list-metrics \
    --autoscale-name gait-analysis-plan-autoscale \
    --resource-group gait-analysis-rg-wus3
```

### Manual Scale (if needed)

```bash
az appservice plan update \
    --name gait-analysis-plan \
    --resource-group gait-analysis-rg-wus3 \
    --number-of-workers 5
```

## Best Practices

1. **Monitor Metrics**: Regularly check CPU, memory, and instance count
2. **Adjust Rules**: Fine-tune scaling rules based on actual usage patterns
3. **Health Checks**: Ensure `/health` endpoint is always responsive
4. **Database Performance**: Monitor SQL Database DTU usage
5. **Cost Optimization**: Review scaling rules periodically to optimize costs if needed

## Support

For issues or questions about the high availability configuration, check:
- Azure Portal → App Service → Scale out (App Service plan)
- Azure Portal → Monitor → Autoscale
- Application logs via `az webapp log tail`
