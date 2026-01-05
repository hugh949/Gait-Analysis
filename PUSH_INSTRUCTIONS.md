# 📤 Push Code to GitHub - Run These Commands Locally

## ⚠️ Authentication Required

Git push requires authentication, which must be done in your local terminal (not through Cursor).

## Quick Solution: Use Personal Access Token

### Step 1: Create Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click: **"Generate new token"** → **"Generate new token (classic)"**
3. Fill in:
   - **Note**: `gait-analysis-deployment`
   - **Expiration**: (your choice, e.g., 90 days or no expiration)
   - **Scopes**: Check **"repo"** (full control of private repositories)
4. Click: **"Generate token"**
5. **Copy the token** immediately (you won't see it again!)

### Step 2: Push Using Token (Choose One Method)

#### Method A: Use Token in URL (One-Time Setup)

Run this in your terminal:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Set remote with token (replace YOUR_TOKEN with actual token)
git remote set-url origin https://YOUR_TOKEN@github.com/hugh949/gait-analysis.git

# Push to GitHub
git push -u origin main
```

**Note**: Your token will be stored in `.git/config`. Make sure this file is in `.gitignore` or be careful with it.

#### Method B: Use Token When Prompted (Recommended)

Run this in your terminal:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Push (will prompt for credentials)
git push -u origin main
```

When prompted:
- **Username**: `hugh949`
- **Password**: (paste your personal access token - NOT your GitHub password)

#### Method C: Use Git Credential Helper (Recommended for Long-Term)

Run these commands in your terminal:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Configure credential helper to store credentials
git config --global credential.helper osxkeychain  # For macOS

# Push (will prompt once, then remember)
git push -u origin main
```

When prompted:
- **Username**: `hugh949`
- **Password**: (paste your personal access token)

After this, git will remember your credentials!

## Alternative: Use SSH (If You Have SSH Keys Set Up)

If you have SSH keys set up with GitHub:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Change remote to SSH URL
git remote set-url origin git@github.com:hugh949/gait-analysis.git

# Push to GitHub
git push -u origin main
```

## After Successful Push

Once code is pushed:

1. **Verify**: Go to https://github.com/hugh949/gait-analysis
   - Check that all files are there
   - Check that `.github/workflows/deploy-frontend.yml` exists

2. **Add Deployment Token** (required for GitHub Actions):
   - Go to: https://github.com/hugh949/gait-analysis/settings/secrets/actions
   - Click: **"New repository secret"**
   - Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
   - Value: (get from Azure Portal - see below)
   - Click: **"Add secret"**

3. **Get Deployment Token from Azure Portal**:
   - Go to: https://portal.azure.com
   - Navigate to: **Resource Groups** → `gait-analysis-rg-eus2` → `gait-analysis-web-eus2`
   - Click: **"Overview"** tab
   - Look for: **"Deployment token"** section
   - Click: **"Manage deployment token"** or copy token directly
   - Copy the token and paste it in GitHub Secrets

## Quick Reference

**Repository**: https://github.com/hugh949/gait-analysis
**Remote**: origin
**Branch**: main
**Workflow**: `.github/workflows/deploy-frontend.yml`

## Summary

✅ Code is committed and ready
⏳ Need to push (requires authentication in your terminal)
⏳ Need to add deployment token to GitHub Secrets

After both steps, **automatic deployment will be active!** 🚀

