# Incremental Deployment Guide

## Overview

The incremental deployment scripts are optimized for iterative development cycles. They only rebuild and redeploy what has changed, saving significant time during development.

## Key Features

✅ **Smart Change Detection** - Uses file hashes to detect what changed  
✅ **Dependency Caching** - Skips dependency installation if `package.json`/`requirements.txt` unchanged  
✅ **Docker Layer Caching** - Azure Container Registry caches Docker layers  
✅ **Fast Iterations** - Code-only changes deploy in 30-60 seconds  
✅ **Progress Feedback** - Frequent progress messages so you know it's working  

## Usage

### Backend Smart Incremental Deployment (RECOMMENDED)

```bash
./scripts/deploy-backend-smart.sh
```

**This is the fastest method!** It intelligently chooses:
- **Code only** → Fast ZIP deployment (30-60 seconds) - **NO Docker**
- **Dependencies** → Docker build (3-8 minutes) - necessary
- **No changes** → Skip deployment (30 seconds) - instant

### Backend Incremental Deployment (Legacy)

```bash
./scripts/deploy-backend-incremental.sh
```

**Note:** This always uses Docker, even for code-only changes. Use `deploy-backend-smart.sh` instead for faster deployments.

**What it does:**
- Checks if `requirements.txt` changed → Only rebuilds dependencies if changed
- Checks if Python code changed → Only rebuilds code layer if changed
- Checks if `Dockerfile.optimized` changed → Full rebuild if changed
- Uses Docker layer caching for faster builds

**Time Savings:**
- **No changes**: ~30-60 seconds (skips build, only updates config)
- **Code only changed**: ~1-2 minutes (uses cached dependencies)
- **Dependencies changed**: ~3-8 minutes (downloads/updates packages)

### Frontend Incremental Deployment

```bash
./scripts/deploy-frontend-incremental.sh
```

**What it does:**
- Checks if `package.json` changed → Only runs `npm install` if changed
- Checks if source code changed → Only rebuilds if files changed
- Skips build entirely if nothing changed

**Time Savings:**
- **No changes**: ~30-60 seconds (skips build, only uploads)
- **Code only changed**: ~30-60 seconds (uses cached `node_modules`)
- **Dependencies changed**: ~1-2 minutes (installs packages)

## How It Works

### Change Detection

The scripts use file hashes stored in hidden files:
- **Backend**: `.last_requirements_hash`, `.last_code_hash`, `.last_dockerfile_hash`
- **Frontend**: `.last_package_hash`, `.last_build_time`

These files are automatically created/updated after each successful deployment.

### Docker Layer Caching

Azure Container Registry automatically caches Docker layers. When only code changes:
1. Base image layer: ✅ Cached
2. Dependencies layer: ✅ Cached (if `requirements.txt` unchanged)
3. Code layer: 🔄 Rebuilt (only this layer)

This means code-only changes are **much faster** than full rebuilds.

## Best Practices

1. **For Code Changes Only**: Use incremental scripts (fast!)
2. **For Dependency Updates**: Use incremental scripts (they detect it)
3. **For First Deployment**: Use `deploy-backend-direct.sh` or `deploy-frontend-direct.sh`
4. **For Major Changes**: Use direct deployment scripts for full rebuild

## Troubleshooting

### "No changes detected" but I made changes

- Check if hash files exist: `ls -la backend/.last_*` or `ls -la frontend/.last_*`
- Delete hash files to force rebuild: `rm backend/.last_*` or `rm frontend/.last_*`

### Build is still slow

- First build always takes longer (downloading dependencies)
- Subsequent builds use cached layers and are much faster
- Check Azure Container Registry for layer cache status

### Script says "skipping build" but I want to rebuild

Delete the hash files:
```bash
# Backend
rm backend/.last_requirements_hash backend/.last_code_hash backend/.last_dockerfile_hash

# Frontend  
rm frontend/.last_package_hash frontend/.last_build_time
```

## Quick Reference

| Scenario | Script | Time |
|----------|--------|------|
| First deployment | `deploy-*-direct.sh` | 5-10 min |
| Code changes only | `deploy-*-incremental.sh` | 30-60 sec |
| Dependency changes | `deploy-*-incremental.sh` | 1-8 min |
| No changes | `deploy-*-incremental.sh` | 30-60 sec |

## Resources

- **Backend URL**: https://gait-analysis-api-wus3.azurewebsites.net
- **Frontend URL**: https://jolly-meadow-0a467810f.1.azurestaticapps.net
- **Resource Group**: `gait-analysis-rg-wus3`
- **Region**: West US 3
