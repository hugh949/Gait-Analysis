# 📤 Push Code to GitHub - Authentication Required

## Status

✅ **Git repository configured**
- Remote added: https://github.com/hugh949/gait-analysis.git
- Branch set to: main
- Files committed: 133 files, ready to push

⚠️ **Authentication needed**: Git push requires GitHub authentication

## Authentication Options

### Option 1: GitHub Personal Access Token (Recommended)

1. **Create Personal Access Token**:
   - Go to: https://github.com/settings/tokens
   - Click: **"Generate new token"** → **"Generate new token (classic)"**
   - Give it a name: `gait-analysis-deployment`
   - Select scope: **"repo"** (full control of private repositories)
   - Click: **"Generate token"**
   - **Copy the token** (you'll only see it once!)

2. **Push to GitHub**:
   ```bash
   cd /Users/hughrashid/Cursor/Gait-Analysis
   git push -u origin main
   ```
   
3. **When prompted**:
   - **Username**: `hugh949`
   - **Password**: (paste the personal access token)
   - Press Enter

4. **Done!** Code will be pushed to GitHub

### Option 2: GitHub CLI (If Installed)

If you have GitHub CLI installed:

```bash
# Authenticate with GitHub
gh auth login

# Push to GitHub
git push -u origin main
```

GitHub CLI will handle authentication interactively.

### Option 3: SSH Key (If Already Set Up)

If you have SSH keys set up with GitHub:

```bash
# Change remote to SSH URL
git remote set-url origin git@github.com:hugh949/gait-analysis.git

# Push to GitHub
git push -u origin main
```

## After Successful Push

Once code is pushed:

1. **Go to your repository**: https://github.com/hugh949/gait-analysis
2. **Verify files are there**:
   - Check that `.github/workflows/deploy-frontend.yml` exists
   - Check that all frontend files are there
3. **Go to Actions tab**:
   - Click "Actions" tab in GitHub
   - You should see the workflow file
4. **Add deployment token** (see next step)

## Next Step: Add Deployment Token to GitHub Secrets

After code is pushed:

1. **Go to repository**: https://github.com/hugh949/gait-analysis
2. **Settings** → **Secrets and variables** → **Actions**
3. **New repository secret**:
   - Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
   - Value: (get from Azure Portal - see below)
4. **Add secret**

### Get Deployment Token from Azure Portal

1. Go to: https://portal.azure.com
2. Navigate to: **Resource Groups** → `gait-analysis-rg-eus2` → `gait-analysis-web-eus2`
3. Click **"Overview"** tab
4. Look for **"Deployment token"** section
5. Click **"Manage deployment token"** or copy token directly
6. Copy the token and paste it in GitHub Secrets

## Quick Command Reference

```bash
# Option 1: Personal Access Token (recommended)
git push -u origin main
# When prompted: Username=hugh949, Password=(paste token)

# Option 2: GitHub CLI
gh auth login
git push -u origin main

# Option 3: SSH (if set up)
git remote set-url origin git@github.com:hugh949/gait-analysis.git
git push -u origin main
```

## Summary

✅ Repository ready
✅ Remote configured
✅ Code committed
⏳ **Need to push** (requires authentication)
⏳ **Need to add deployment token** to GitHub Secrets

Once both are done, **automatic deployment will be active!** 🚀

