# Infrastructure Fixes for Pilot Project

## Issues Fixed

### 1. ACR Authentication (UNAUTHORIZED errors)
**Problem**: App Service couldn't pull Docker images from Azure Container Registry due to authentication failures.

**Solution**:
- ✅ Updated deployment workflow to use new container config API
- ✅ Created `scripts/fix-acr-authentication.sh` to refresh ACR credentials
- ✅ Configured proper ACR authentication on App Service

**Usage**:
```bash
bash scripts/fix-acr-authentication.sh
```

### 2. Disk Space Issues (no space left on device)
**Problem**: Docker container running out of disk space from accumulated old images.

**Solution**:
- ✅ Created `scripts/cleanup-disk-space.sh` to clean up old ACR images
- ✅ Keeps only last 5 Docker images (sufficient for pilot)
- ✅ Restarts App Service to clear caches

**Usage**:
```bash
bash scripts/cleanup-disk-space.sh
```

## Pilot Project Optimization

For a pilot project with:
- **3 users maximum**
- **Files under 100MB each**
- **Low deployment frequency**

### Recommendations:
1. **ACR Image Retention**: Keep only last 5 images (saves ~80% disk space)
2. **Regular Cleanup**: Run cleanup script monthly or after major deployments
3. **Monitor Disk Usage**: Check App Service metrics regularly

### Cost Optimization:
- Current setup is optimized for pilot scale
- No need for premium storage or high-tier App Service plans
- ACR Basic tier is sufficient (handles pilot load easily)

## Maintenance Scripts

### Fix ACR Authentication
```bash
# Run when seeing "UNAUTHORIZED" errors
bash scripts/fix-acr-authentication.sh
az webapp restart --name gaitanalysisapp --resource-group gait-analysis-rg-wus3
```

### Clean Up Disk Space
```bash
# Run monthly or when seeing "no space left" errors
bash scripts/cleanup-disk-space.sh
```

### Combined Maintenance
```bash
# Run both fixes together
bash scripts/fix-acr-authentication.sh && \
bash scripts/cleanup-disk-space.sh
```

## Monitoring

### Check App Service Status
```bash
az webapp show --name gaitanalysisapp --resource-group gait-analysis-rg-wus3 \
  --query "{state:state, defaultHostName:defaultHostName}" -o json
```

### Check ACR Images
```bash
az acr repository show-tags --name gaitacr737 --repository gait-integrated \
  --orderby time_desc --query "[].name" -o table
```

### Check Container Configuration
```bash
az webapp config container show --name gaitanalysisapp \
  --resource-group gait-analysis-rg-wus3 -o json
```

## Troubleshooting

### If ACR authentication still fails:
1. Verify ACR admin user is enabled:
   ```bash
   az acr update --name gaitacr737 --admin-enabled true
   ```
2. Re-run authentication fix script
3. Restart App Service

### If disk space issues persist:
1. Check current disk usage in App Service metrics
2. Run cleanup script more frequently
3. Consider upgrading App Service plan if needed (only if issues persist)

## Next Steps

1. ✅ ACR authentication configured
2. ✅ Disk cleanup automated
3. ✅ Deployment workflow updated
4. ⏳ Monitor for 24-48 hours to ensure fixes are working
5. ⏳ Schedule monthly cleanup (optional but recommended)

## Notes

- These fixes are optimized for pilot scale (3 users, <100MB files)
- For production scale, consider:
  - Automated cleanup via Azure Functions
  - More aggressive image retention policies
  - Monitoring and alerting for disk space
