# Deployment Guide

This project uses **GitHub Actions** for automated deployments to Azure. This is the recommended and most reliable deployment method.

## Quick Start

1. **Set up GitHub Secrets** (one-time setup)
   - See [GitHub Actions Setup Guide](.github/GITHUB_ACTIONS_SETUP.md)
   - Run `./scripts/setup-github-secrets.sh` for help

2. **Push to main branch**
   - Workflows automatically trigger on push
   - Monitor progress in GitHub Actions tab

3. **Deploy manually** (optional)
   - Go to Actions → Select workflow → Run workflow

## Deployment Methods

### ✅ Recommended: GitHub Actions (Automated)

**Workflows:**
- `.github/workflows/deploy-backend.yml` - Backend only
- `.github/workflows/deploy-frontend.yml` - Frontend only  
- `.github/workflows/deploy-integrated.yml` - Both together

**Benefits:**
- ✅ Automatic on push to main
- ✅ Reliable and tested
- ✅ Full visibility in GitHub
- ✅ No local dependencies
- ✅ Follows Azure best practices

### ⚠️ Alternative: Direct Scripts (Manual)

**Scripts:**
- `scripts/build-and-deploy-integrated.sh` - Full deployment
- `scripts/deploy-backend-direct.sh` - Backend only
- `scripts/deploy-frontend-direct.sh` - Frontend only

**Use when:**
- Testing locally before pushing to GitHub
- Emergency hotfixes
- Local development

## Azure Resources

All resources are in **West US 3**:

- **Resource Group**: `gait-analysis-rg-wus3`
- **App Service**: `gaitanalysisapp` (https://gaitanalysisapp.azurewebsites.net)
- **Container Registry**: `gaitacr737`
- **Static Web App**: `gentle-sky-0a498ab1e` (https://gentle-sky-0a498ab1e.4.azurestaticapps.net)

## Architecture

### Integrated Application (Current)

- **Single App Service** hosting both API and React frontend
- **Single URL**: https://gaitanalysisapp.azurewebsites.net
- **Docker container** with Python FastAPI + React build
- **Azure services**: Blob Storage, Computer Vision, SQL Database

### Separate Frontend/Backend (Alternative)

- **Frontend**: Azure Static Web Apps
- **Backend**: Azure App Service (Docker)
- **CORS**: Configured for cross-origin requests

## Monitoring

### GitHub Actions

1. Go to repository → Actions tab
2. View workflow runs
3. Click on a run to see logs

### Azure Portal

- **App Service Logs**: Portal → App Service → Log stream
- **Container Logs**: Portal → App Service → Container settings
- **Application Insights**: (if configured)

## Troubleshooting

### Deployment Fails

1. Check GitHub Actions logs
2. Verify all secrets are set correctly
3. Check Azure Portal for resource status
4. See [GitHub Actions Setup Guide](.github/GITHUB_ACTIONS_SETUP.md)

### Application Not Starting

1. Check container logs in Azure Portal
2. Verify `WEBSITES_PORT=8000` is set
3. Verify ACR authentication (password should not be null)
4. Check health endpoint: `https://gaitanalysisapp.azurewebsites.net/health`

### Frontend Not Updating

1. Check Static Web Apps deployment logs
2. Clear browser cache
3. Verify deployment token is correct
4. Check build logs in GitHub Actions

## Best Practices

1. ✅ **Use GitHub Actions** for all production deployments
2. ✅ **Test locally** before pushing to main
3. ✅ **Monitor deployments** in GitHub Actions
4. ✅ **Review logs** after each deployment
5. ✅ **Keep secrets secure** - never commit to repository

## Documentation

- [GitHub Actions Setup Guide](.github/GITHUB_ACTIONS_SETUP.md) - Detailed setup instructions
- [Azure Architecture](MICROSOFT_NATIVE_ARCHITECTURE.md) - Architecture details
