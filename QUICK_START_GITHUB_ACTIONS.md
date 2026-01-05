# 🚀 Quick Start: GitHub Actions Setup (5 Steps)

Follow these steps to set up automatic deployment:

## ✅ Step 1: Git Repository (Already Done!)
Git repository is initialized and ready.

## 📋 Step 2: Create GitHub Repository

1. **Go to**: https://github.com/new
2. **Repository name**: `gait-analysis-app` (or your choice)
3. **Visibility**: Public (free) or Private
4. **⚠️ IMPORTANT**: 
   - ❌ DO NOT check "Add a README file"
   - ❌ DO NOT check "Add .gitignore"
   - ❌ DO NOT check "Choose a license"
5. **Click**: "Create repository"

## 📤 Step 3: Push Code to GitHub

After creating the repository, GitHub will show you commands. Use these:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Add GitHub remote (replace YOUR_USERNAME and YOUR_REPO)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Set main branch
git branch -M main

# Add all files
git add .

# Make initial commit
git commit -m "Initial commit with GitHub Actions setup"

# Push to GitHub
git push -u origin main
```

**Note**: You may need to authenticate. Use a GitHub Personal Access Token if prompted.

## 🔑 Step 4: Get Deployment Token from Azure Portal

1. **Go to**: https://portal.azure.com
2. **Navigate to**: 
   - Resource Groups → `gait-analysis-rg-eus2`
   - Click: `gait-analysis-web-eus2`
3. **Click**: "Overview" tab (should be default)
4. **Look for**: "Deployment token" section
5. **Click**: "Manage deployment token" button (if available)
6. **Copy**: The deployment token

**Alternative**: The token is usually displayed directly on the Overview page under "Deployment token".

## 🔐 Step 5: Add Token to GitHub Secrets

1. **Go to your GitHub repository**
2. **Click**: "Settings" (top menu)
3. **Left sidebar**: "Secrets and variables" → "Actions"
4. **Click**: "New repository secret"
5. **Fill in**:
   - **Name**: `AZURE_STATIC_WEB_APPS_API_TOKEN` (exact name, case-sensitive)
   - **Value**: (paste the token from Step 4)
6. **Click**: "Add secret"

## ✅ Done!

That's it! Now:

1. **Go to**: Your repository → "Actions" tab
2. **You should see**: "Deploy Frontend to Azure Static Web App" workflow
3. **It will run automatically** on the next push

## 🎉 Test It!

Make a small change to trigger deployment:

```bash
# Make a small change
echo "# GitHub Actions Automatic Deployment" >> README.md

# Commit and push
git add README.md
git commit -m "Test GitHub Actions deployment"
git push
```

Then:
1. Go to repository → "Actions" tab
2. Watch the workflow run
3. After 2-3 minutes, check: https://jolly-meadow-0a467810f.1.azurestaticapps.net
4. Your new version should be live!

## 📝 Quick Reference

- **Workflow File**: `.github/workflows/deploy-frontend.yml` ✅ Already created
- **Git Secret Name**: `AZURE_STATIC_WEB_APPS_API_TOKEN`
- **Static Web App**: `gait-analysis-web-eus2`
- **Frontend URL**: https://jolly-meadow-0a467810f.1.azurestaticapps.net

## 💡 After Setup

**Every push to `frontend/` folder will automatically deploy!**

```bash
# Make changes to frontend
# ... edit files ...

# Commit and push
git add frontend/
git commit -m "Update frontend"
git push

# GitHub Actions automatically deploys! 🚀
```

---

Need more details? See `GITHUB_ACTIONS_COMPLETE_SETUP.md` for comprehensive guide.

