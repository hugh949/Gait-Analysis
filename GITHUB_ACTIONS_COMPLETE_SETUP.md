# 🚀 Complete GitHub Actions Setup Guide

This guide will help you set up automatic deployment using GitHub Actions.

## Prerequisites

✅ Git installed
✅ GitHub account
✅ Azure Static Web App: `gait-analysis-web-eus2`
✅ Frontend code ready in `frontend/` directory

## Step-by-Step Setup

### Step 1: Initialize Git Repository (If Needed)

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Initialize git (if not already done)
git init

# Add all files
git add .

# Make initial commit
git commit -m "Initial commit with GitHub Actions setup"
```

### Step 2: Create GitHub Repository

1. **Go to GitHub**: https://github.com/new
2. **Create new repository**:
   - Repository name: `gait-analysis-app` (or your choice)
   - Description: (optional)
   - Visibility: **Public** (free) or **Private** (your choice)
   - ⚠️ **IMPORTANT**: Do NOT check "Initialize this repository with:"
     - ❌ Don't check README
     - ❌ Don't check .gitignore
     - ❌ Don't check license
   - Click **"Create repository"**

3. **Copy the repository URL** (you'll need it next)

### Step 3: Push Code to GitHub

```bash
# Add GitHub remote (replace YOUR_USERNAME and YOUR_REPO with your values)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Set main branch
git branch -M main

# Push code
git push -u origin main
```

**Note**: You may need to authenticate with GitHub (use personal access token if prompted).

### Step 4: Get Deployment Token from Azure

You have two options:

#### Option A: Azure Portal (Easiest)

1. Go to: https://portal.azure.com
2. Navigate to: **Resource Groups** → `gait-analysis-rg-eus2` → `gait-analysis-web-eus2`
3. Click **"Overview"** tab
4. Look for **"Deployment token"** section
5. Click **"Manage deployment token"** or copy the token directly
6. Copy the token (you'll need it in the next step)

#### Option B: Azure CLI

```bash
az staticwebapp secrets list \
  --name gait-analysis-web-eus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query deploymentToken -o tsv
```

**Note**: This may not work in all environments. Use Azure Portal if it fails.

### Step 5: Add Token to GitHub Secrets

1. **Go to your GitHub repository**
2. Click **"Settings"** tab (top menu)
3. In left sidebar: **"Secrets and variables"** → **"Actions"**
4. Click **"New repository secret"** button
5. Fill in:
   - **Name**: `AZURE_STATIC_WEB_APPS_API_TOKEN`
   - **Value**: (paste the deployment token from Step 4)
6. Click **"Add secret"**

✅ Your secret is now stored securely in GitHub!

### Step 6: Verify Workflow File

The workflow file is already created at: `.github/workflows/deploy-frontend.yml`

If you pushed your code, it should already be in GitHub. Verify:
1. Go to your repository
2. Click **"Actions"** tab
3. You should see **"Deploy Frontend to Azure Static Web App"** workflow
4. If you see it, you're good! (It may run automatically or wait for next push)

### Step 7: Trigger Deployment (If Needed)

If the workflow didn't run automatically:

1. **Make a small change** to trigger it:
   ```bash
   # Edit any file (or just add a comment)
   echo "# GitHub Actions setup" >> README.md
   git add .
   git commit -m "Trigger GitHub Actions workflow"
   git push
   ```

2. **Or trigger manually**:
   - Go to repository → **"Actions"** tab
   - Click **"Deploy Frontend to Azure Static Web App"** workflow
   - Click **"Run workflow"** button (if available)
   - Select branch: `main`
   - Click **"Run workflow"**

### Step 8: Monitor Deployment

1. Go to repository → **"Actions"** tab
2. Click on the running workflow
3. Watch the progress:
   - ✅ Checkout code
   - ✅ Setup Node.js
   - ✅ Install dependencies
   - ✅ Build
   - ✅ Deploy to Azure Static Web Apps

4. **Once complete**, check your Static Web App URL:
   - **URL**: https://jolly-meadow-0a467810f.1.azurestaticapps.net
   - You should see your new version!

## 🎉 Success!

Once set up, **every push to the `frontend/` folder will automatically deploy** to Azure!

## Future Deployments

From now on, deployment is automatic:

1. **Make changes** to frontend code
2. **Commit and push**:
   ```bash
   git add frontend/
   git commit -m "Update frontend"
   git push
   ```
3. **GitHub Actions automatically**:
   - Builds the frontend
   - Deploys to Azure
   - Updates your live site

No manual intervention needed! 🚀

## Troubleshooting

### Workflow not running?
- Check that `.github/workflows/deploy-frontend.yml` is in your repository
- Verify you pushed the file
- Check GitHub Actions is enabled (Settings → Actions → General)

### Deployment failing?
- Check that `AZURE_STATIC_WEB_APPS_API_TOKEN` secret is set correctly
- Verify the token hasn't expired (get a new one if needed)
- Check workflow logs in Actions tab for specific errors

### Build failing?
- Check Node.js version (should be 18+)
- Verify `npm ci` works locally: `cd frontend && npm ci`
- Check for TypeScript errors: `cd frontend && npm run build`

### Need to update token?
1. Get new token from Azure Portal
2. Go to GitHub → Settings → Secrets and variables → Actions
3. Click on `AZURE_STATIC_WEB_APPS_API_TOKEN`
4. Click "Update"
5. Paste new token
6. Click "Update secret"

## Files Created

- ✅ `.github/workflows/deploy-frontend.yml` - GitHub Actions workflow
- ✅ `.gitignore` - Git ignore file (excludes node_modules, dist, etc.)
- ✅ `setup-github-actions.sh` - Setup helper script
- ✅ `GITHUB_ACTIONS_COMPLETE_SETUP.md` - This guide

## Quick Reference

**Workflow File**: `.github/workflows/deploy-frontend.yml`
**GitHub Secret**: `AZURE_STATIC_WEB_APPS_API_TOKEN`
**Static Web App**: `gait-analysis-web-eus2`
**Frontend URL**: https://jolly-meadow-0a467810f.1.azurestaticapps.net

Follow the steps above and you'll have automatic deployment set up! 🎉

