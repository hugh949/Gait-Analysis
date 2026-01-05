# GitHub Actions Setup Checklist

## ✅ Completed by Script
- [x] Git repository initialized/checked
- [x] Workflow file verified: .github/workflows/deploy-frontend.yml
- [ ] Deployment token retrieved (see below)

## 📋 To Do Manually

### 1. Create GitHub Repository
- [ ] Go to https://github.com/new
- [ ] Create repository (don't initialize with files)
- [ ] Copy repository URL

### 2. Push Code to GitHub
```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git add .
git commit -m "Initial commit with GitHub Actions setup"
git push -u origin main
```

### 3. Add Deployment Token to GitHub Secrets
- [ ] Go to repository → Settings → Secrets and variables → Actions
- [ ] Click "New repository secret"
- [ ] Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
- [ ] Value: (token from Azure Portal or shown in script output)
- [ ] Click "Add secret"

### 4. Verify Setup
- [ ] Go to repository → Actions tab
- [ ] Workflow should run automatically
- [ ] Check deployment status

## Deployment Token

Get token from Azure Portal:
- Go to: Resource Groups → gait-analysis-rg-eus2 → gait-analysis-web-eus2
- Click 'Overview' → 'Deployment token'
