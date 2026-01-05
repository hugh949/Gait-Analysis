# 🔄 Setting Up Automatic Deployment

This guide shows how to set up automatic deployment so new versions are uploaded automatically without manual intervention.

## Option 1: GitHub Actions (Recommended - Most Reliable)

### Step 1: Initialize Git Repository (if not already done)

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis
git init
git add .
git commit -m "Initial commit - Ready for automatic deployment"
```

### Step 2: Create GitHub Repository

1. Go to https://github.com/new
2. Create a new repository (e.g., `gait-analysis-app`)
3. Do NOT initialize with README (since you already have files)

### Step 3: Push Code to GitHub

```bash
git remote add origin https://github.com/YOUR_USERNAME/gait-analysis-app.git
git branch -M main
git push -u origin main
```

### Step 4: Get Deployment Token from Azure

```bash
az staticwebapp secrets list \
  --name gait-analysis-web-eus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query deploymentToken -o tsv
```

Copy this token.

### Step 5: Add Token to GitHub Secrets

1. Go to your GitHub repository
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
5. Value: Paste the deployment token from Step 4
6. Click **Add secret**

### Step 6: Push Workflow File

The GitHub Actions workflow file (`.github/workflows/deploy-frontend.yml`) is already created. Just commit and push:

```bash
git add .github/workflows/deploy-frontend.yml
git commit -m "Add GitHub Actions workflow for automatic deployment"
git push
```

### Step 7: Verify

1. Go to your GitHub repository
2. Click on **Actions** tab
3. You should see the workflow running
4. Once complete, your frontend will be automatically deployed!

**Future**: Every time you push changes to `frontend/` folder, it will automatically deploy!

---

## Option 2: Azure DevOps Pipeline

### Step 1: Create Azure DevOps Project

1. Go to https://dev.azure.com
2. Create a new project

### Step 2: Create Pipeline

1. Go to **Pipelines** → **Create Pipeline**
2. Select your code repository
3. Use this YAML configuration:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - frontend/*

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: NodeTool@0
  inputs:
    versionSpec: '18.x'
  displayName: 'Install Node.js'

- script: |
    cd frontend
    npm ci
    npm run build
  displayName: 'Build frontend'

- task: AzureStaticWebApp@0
  inputs:
    app_location: 'frontend'
    output_location: 'dist'
    azure_static_web_apps_api_token: '$(AZURE_STATIC_WEB_APPS_API_TOKEN)'
  displayName: 'Deploy to Azure Static Web App'
```

### Step 3: Add Deployment Token as Variable

1. Go to **Pipelines** → **Library**
2. Create a variable group or add variable:
   - Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
   - Value: (Get from Azure CLI command above)

---

## Option 3: Automated Script (Can be called from any CI/CD)

### Usage

The script `scripts/deploy-frontend-automated.sh` is ready to use:

```bash
# Make executable
chmod +x scripts/deploy-frontend-automated.sh

# Run it
./scripts/deploy-frontend-automated.sh
```

### Integrate with CI/CD

You can call this script from:
- GitHub Actions
- GitLab CI
- Jenkins
- CircleCI
- Any CI/CD platform

Example GitHub Actions step:
```yaml
- name: Deploy Frontend
  run: |
    chmod +x scripts/deploy-frontend-automated.sh
    ./scripts/deploy-frontend-automated.sh
  env:
    AZURE_CLI_VERSION: 2.0.0
```

---

## Option 4: Azure Static Web App with GitHub Integration

### Step 1: Connect GitHub to Azure

1. Go to Azure Portal
2. Navigate to your Static Web App
3. Go to **Deployment Center**
4. Select **GitHub** as source
5. Authorize Azure to access GitHub
6. Select repository and branch
7. Configure:
   - **App location**: `/frontend`
   - **Output location**: `dist`
8. Click **Save**

### Step 2: Automatic Deployment Enabled!

Now every push to your repository will automatically trigger a deployment.

---

## Recommended Approach

**Best Option: GitHub Actions** ✅

1. ✅ Most reliable
2. ✅ Free for public repos
3. ✅ Well-documented
4. ✅ Easy to set up
5. ✅ Automatic on every push

**Quick Setup**:
1. Initialize git repo (if needed)
2. Push to GitHub
3. Add deployment token to GitHub Secrets
4. Push workflow file
5. Done! Automatic deployments enabled!

---

## Verification

After setting up, verify automatic deployment:

1. Make a small change to frontend
2. Commit and push
3. Check GitHub Actions / Azure DevOps / your CI/CD
4. Verify deployment appears in Azure Portal
5. Check website URL to see new version

---

## Troubleshooting

### GitHub Actions failing?
- Check that `AZURE_STATIC_WEB_APPS_API_TOKEN` secret is set correctly
- Verify token hasn't expired (regenerate if needed)
- Check Actions logs for specific errors

### Deployment token expired?
Get a new one:
```bash
az staticwebapp secrets list \
  --name gait-analysis-web-eus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query deploymentToken -o tsv
```

### Build failing?
- Check Node.js version matches (should be 18+)
- Verify `npm ci` works locally
- Check for TypeScript errors: `cd frontend && npm run build`

---

## Summary

The easiest and most reliable way is **GitHub Actions**:
1. Push code to GitHub
2. Add deployment token to secrets
3. Automatic deployments on every push! 🎉

