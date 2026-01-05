# 🔄 Automatic Deployment Setup - Quick Start

## Overview

I've created reliable scripts and workflows for automatic deployment. Choose the option that works best for you.

## ✅ What's Ready

1. **Automated Deployment Script**: `scripts/deploy-frontend-automated.sh`
   - Reliable, error-handling included
   - Can be run manually or in CI/CD
   - Handles all prerequisites

2. **GitHub Actions Workflow**: `.github/workflows/deploy-frontend.yml`
   - Automatic deployment on every push
   - Most reliable option
   - Free for public repositories

3. **Setup Guide**: `scripts/setup-automatic-deployment.md`
   - Detailed instructions for all options
   - Troubleshooting tips

## 🚀 Quick Setup (GitHub Actions - Recommended)

### 1. Initialize Git (if needed)
```bash
cd /Users/hughrashid/Cursor/Gait-Analysis
git init
git add .
git commit -m "Add automatic deployment setup"
```

### 2. Create GitHub Repository
- Go to https://github.com/new
- Create repository
- Copy the repository URL

### 3. Push to GitHub
```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

### 4. Get Deployment Token
```bash
az staticwebapp secrets list \
  --name gait-analysis-web-eus2 \
  --resource-group gait-analysis-rg-eus2 \
  --query deploymentToken -o tsv
```

### 5. Add to GitHub Secrets
1. Go to your GitHub repository
2. **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
5. Value: (paste token from step 4)
6. Click **Add secret**

### 6. Push Workflow File
```bash
git add .github/workflows/deploy-frontend.yml
git commit -m "Add GitHub Actions workflow"
git push
```

### 7. Done! ✅

Now every push to `frontend/` will automatically deploy to Azure!

---

## 🔧 Alternative: Use the Automated Script

If you prefer running the script manually or from another CI/CD:

```bash
# Make executable (if not already)
chmod +x scripts/deploy-frontend-automated.sh

# Run it
./scripts/deploy-frontend-automated.sh
```

The script:
- ✅ Checks prerequisites
- ✅ Builds frontend
- ✅ Gets deployment token
- ✅ Deploys using best available method
- ✅ Verifies deployment

---

## 📋 File Locations

- **Automated Script**: `scripts/deploy-frontend-automated.sh`
- **GitHub Workflow**: `.github/workflows/deploy-frontend.yml`
- **Setup Guide**: `scripts/setup-automatic-deployment.md`

---

## 🎯 Recommendation

**Use GitHub Actions** - It's the most reliable and automatic:
- Deploys on every push
- No manual intervention needed
- Free for public repos
- Easy to set up
- Well-documented

Just follow the Quick Setup steps above!

