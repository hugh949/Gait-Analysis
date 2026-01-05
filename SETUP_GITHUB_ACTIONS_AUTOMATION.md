# ✅ Setup GitHub Actions for Automatic Deployment

## Current Status

✅ **Workflow File Created**: `.github/workflows/deploy-frontend.yml`
✅ **Code Fixed**: Upload endpoint updated
✅ **Build Working**: Frontend builds successfully
⏳ **Need to Complete**: Push to GitHub and add deployment token

## Complete Setup Instructions

### Step 1: Push Code to GitHub

If you haven't pushed your code yet, do it now:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Add all changes (including the workflow file)
git add .

# Commit the changes
git commit -m "Add GitHub Actions workflow for automatic deployment"

# Push to GitHub
git push -u origin main
```

**Note**: You'll need to authenticate. If you haven't set up authentication:
- Use a GitHub Personal Access Token as the password
- Or use SSH keys

### Step 2: Get Azure Deployment Token

1. **Go to Azure Portal**: https://portal.azure.com
2. **Navigate to**:
   - Resource Groups → `gait-analysis-rg-eus2`
   - Click: `gait-analysis-web-eus2`
3. **Click**: "Overview" tab
4. **Look for**: "Deployment token" section
5. **Copy the token** (you used this earlier: `1aaad346d4e5bd36241348cfca7dde044f070ae22516f876ea34bde2d6f6bcd201-0ab6484a-20a7-49f6-979d-bd3285fc68d000f21100a467810f`)

### Step 3: Add Token to GitHub Secrets

1. **Go to your GitHub repository**: https://github.com/hugh949/gait-analysis
2. **Click**: "Settings" (top menu)
3. **Left sidebar**: "Secrets and variables" → "Actions"
4. **Click**: "New repository secret"
5. **Fill in**:
   - **Name**: `AZURE_STATIC_WEB_APPS_API_TOKEN` (exact name, case-sensitive)
   - **Value**: (paste the deployment token from Step 2)
6. **Click**: "Add secret"

### Step 4: Verify Setup

1. **Go to your repository**: https://github.com/hugh949/gait-analysis
2. **Click**: "Actions" tab
3. **You should see**: "Deploy Frontend to Azure Static Web App" workflow
4. **The workflow will run automatically** on the next push!

## How It Works

### Automatic Deployment Triggers

The workflow will automatically run when:
- ✅ You push code to `main` or `master` branch
- ✅ Files in `frontend/` folder are changed
- ✅ The workflow file itself is updated

### Manual Trigger

You can also trigger it manually:
1. Go to repository → "Actions" tab
2. Click "Deploy Frontend to Azure Static Web App"
3. Click "Run workflow" button
4. Select branch: `main`
5. Click "Run workflow"

## What Happens on Each Push

1. **GitHub Actions runs** the workflow
2. **Checks out code** from your repository
3. **Sets up Node.js** (version 18)
4. **Installs dependencies** (`npm ci`)
5. **Builds frontend** (`npm run build`)
6. **Deploys to Azure** Static Web App
7. **Frontend is live** in 2-3 minutes!

## Benefits

✅ **Automatic**: No manual deployment needed
✅ **Fast**: Deploys in 2-3 minutes
✅ **Reliable**: Runs in GitHub's infrastructure
✅ **Free**: Free for public repositories
✅ **History**: Full deployment history in GitHub Actions

## Testing

After setup, test it:

```bash
# Make a small change
echo "# Auto-deploy test" >> README.md

# Commit and push
git add README.md
git commit -m "Test automatic deployment"
git push
```

Then:
1. Go to repository → "Actions" tab
2. Watch the workflow run
3. After 2-3 minutes, check: https://jolly-meadow-0a467810f.1.azurestaticapps.net
4. Your change should be live!

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

## Summary

✅ **Workflow file**: Ready
✅ **Build process**: Working
⏳ **Next steps**:
   1. Push code to GitHub (if not already done)
   2. Add deployment token to GitHub Secrets
   3. Done! Automatic deployments enabled! 🚀

After completing these steps, **every push to `frontend/` will automatically deploy to Azure!**

