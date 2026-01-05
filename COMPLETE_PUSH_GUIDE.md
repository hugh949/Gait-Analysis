# 🚀 Complete Guide: Push to GitHub

## Current Status

✅ **Everything is ready to push!**
- Repository: https://github.com/hugh949/gait-analysis
- Code committed: 133 files
- Workflow file: `.github/workflows/deploy-frontend.yml` ✅
- Remote configured: `origin`

## ⚠️ Authentication Required

You need to run the push command in **your terminal** (not Cursor's command execution) because it requires interactive authentication.

## Step-by-Step: Push to GitHub

### Step 1: Open Your Terminal

Open Terminal.app (or your preferred terminal) and navigate to the project:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis
```

### Step 2: Create GitHub Personal Access Token

1. **Go to**: https://github.com/settings/tokens
2. **Click**: "Generate new token" → "Generate new token (classic)"
3. **Fill in**:
   - **Note**: `gait-analysis-deployment`
   - **Expiration**: 90 days (or your preference)
   - **Scopes**: Check ✅ **"repo"** (Full control of private repositories)
4. **Click**: "Generate token" (at bottom)
5. **Copy the token** immediately! (You won't see it again)

### Step 3: Push to GitHub

In your terminal, run:

```bash
git push -u origin main
```

**When prompted**:
- **Username**: `hugh949`
- **Password**: (paste your Personal Access Token - NOT your GitHub password)

**Note**: The credential helper is configured, so after the first push, it will remember your credentials!

### Step 4: Verify Push

1. **Go to**: https://github.com/hugh949/gait-analysis
2. **Check**:
   - ✅ All files are there
   - ✅ `.github/workflows/deploy-frontend.yml` exists
   - ✅ Frontend code is there

## Next Step: Add Deployment Token

After code is pushed, add the Azure deployment token to GitHub Secrets:

### Get Deployment Token from Azure Portal

1. **Go to**: https://portal.azure.com
2. **Navigate to**:
   - Resource Groups → `gait-analysis-rg-eus2`
   - Click: `gait-analysis-web-eus2`
3. **Click**: "Overview" tab
4. **Look for**: "Deployment token" section
5. **Click**: "Manage deployment token" (if available) or copy token directly
6. **Copy the token**

### Add Token to GitHub Secrets

1. **Go to**: https://github.com/hugh949/gait-analysis/settings/secrets/actions
2. **Click**: "New repository secret"
3. **Fill in**:
   - **Name**: `AZURE_STATIC_WEB_APPS_API_TOKEN` (exact name, case-sensitive)
   - **Value**: (paste the deployment token from Azure Portal)
4. **Click**: "Add secret"

## ✅ After Setup

Once both are done:

1. **Go to**: https://github.com/hugh949/gait-analysis/actions
2. **You should see**: "Deploy Frontend to Azure Static Web App" workflow
3. **It will run automatically** on the next push to `frontend/` folder

## Test Automatic Deployment

Make a small change to trigger deployment:

```bash
# Make a small change
echo "# Automatic Deployment Active" >> README.md

# Commit and push
git add README.md
git commit -m "Test automatic deployment"
git push
```

Then:
1. Go to: https://github.com/hugh949/gait-analysis/actions
2. Watch the workflow run
3. After 2-3 minutes, check: https://jolly-meadow-0a467810f.1.azurestaticapps.net
4. Your new version should be live! 🎉

## Troubleshooting

### "fatal: could not read Username"
- Make sure you're running the command in **your terminal**, not through Cursor
- The credential helper is configured, so it should prompt you once

### "Authentication failed"
- Make sure you're using a **Personal Access Token**, not your GitHub password
- Verify the token has "repo" scope
- Check that the token hasn't expired

### "Repository not found"
- Verify the repository exists: https://github.com/hugh949/gait-analysis
- Check you have access to the repository
- Verify the remote URL: `git remote -v`

## Summary

✅ Code is ready
✅ Repository configured
⏳ **Run `git push -u origin main` in your terminal**
⏳ **Add deployment token to GitHub Secrets**

After both steps, **automatic deployment will be active!** 🚀

