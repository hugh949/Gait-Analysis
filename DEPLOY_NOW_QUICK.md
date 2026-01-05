# 🚀 Deploy Now - Quick Guide

## Current Status

✅ **Frontend Build**: Ready in `frontend/dist/`
✅ **Static Web App**: `gait-analysis-web-eus2`
✅ **URL**: https://jolly-meadow-0a467810f.1.azurestaticapps.net
✅ **Backend**: Already deployed and running

## ⚠️ Deployment Token Issue

The deployment script needs a deployment token, which Azure CLI cannot retrieve automatically. This is a common limitation.

## 🎯 Easiest Option: Deploy via Azure Portal (Recommended)

### Step 1: Zip the Build (Optional but Recommended)

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis/frontend
zip -r dist.zip dist/
```

### Step 2: Deploy via Azure Portal

1. **Go to Azure Portal**: https://portal.azure.com
2. **Navigate to Static Web App**:
   - Resource Groups → `gait-analysis-rg-eus2`
   - Click: `gait-analysis-web-eus2`
3. **Deploy**:
   - Click: **"Deployment Center"** (left menu)
   - Click: **"Manual upload"** tab
   - **Option A**: Upload the `dist.zip` file (if you zipped it)
   - **Option B**: Upload the contents of `frontend/dist/` folder
4. **Wait**: 1-2 minutes for deployment to complete
5. **Check**: https://jolly-meadow-0a467810f.1.azurestaticapps.net

### Step 3: Verify

Visit: https://jolly-meadow-0a467810f.1.azurestaticapps.net

You should see your new version!

## Alternative: Deploy with Token (If You Have It)

If you have the deployment token from Azure Portal:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis
AZURE_STATIC_WEB_APPS_API_TOKEN='your-token-here' ./scripts/deploy-frontend-automated.sh
```

### To Get the Token:

1. Go to: https://portal.azure.com
2. Navigate to: Resource Groups → `gait-analysis-rg-eus2` → `gait-analysis-web-eus2`
3. Click: **"Overview"** tab
4. Look for: **"Deployment token"** section
5. Click: **"Manage deployment token"** (if available)
6. Copy the token

## Summary

✅ Build is ready
⏳ **Easiest: Use Azure Portal to upload `frontend/dist/`**
⏳ Alternative: Use deployment script with token

**Recommended**: Use Azure Portal (Method 1) - It's the easiest and doesn't require tokens!

---

Once deployed, your new version with UX improvements will be live! 🚀

