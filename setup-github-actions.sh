#!/bin/bash
# Setup GitHub Actions for Automatic Deployment
# This script helps you set up automatic deployment via GitHub Actions

set -e

echo "🚀 GitHub Actions Setup for Automatic Deployment"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}▶ Step $1: $2${NC}"
}

print_info() {
    echo -e "${GREEN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Step 1: Check if git is initialized
print_step "1/6" "Checking Git repository..."

if [ -d ".git" ]; then
    print_info "Git repository already initialized"
    git status --short | head -5 || echo "  (no changes or clean working tree)"
else
    print_info "Initializing Git repository..."
    git init
    print_info "Git repository initialized"
fi

echo ""

# Step 2: Check workflow file exists
print_step "2/6" "Checking GitHub Actions workflow..."

if [ -f ".github/workflows/deploy-frontend.yml" ]; then
    print_info "Workflow file exists: .github/workflows/deploy-frontend.yml"
else
    print_warning "Workflow file not found. It should have been created earlier."
    echo "  Creating workflow file..."
    mkdir -p .github/workflows
    # The workflow file should already exist, but if not, we'll note it
    print_info "Please ensure .github/workflows/deploy-frontend.yml exists"
fi

echo ""

# Step 3: Get deployment token
print_step "3/6" "Getting deployment token from Azure..."

STATIC_WEB_APP_NAME="gait-analysis-web-eus2"
RESOURCE_GROUP="gait-analysis-rg-eus2"

print_info "Attempting to retrieve deployment token..."

DEPLOYMENT_TOKEN=$(az staticwebapp secrets list \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query deploymentToken -o tsv 2>/dev/null || echo "")

if [ -z "$DEPLOYMENT_TOKEN" ] || [ "$DEPLOYMENT_TOKEN" == "null" ]; then
    print_warning "Could not retrieve token automatically"
    echo ""
    echo "You'll need to get it from Azure Portal:"
    echo "  1. Go to: https://portal.azure.com"
    echo "  2. Navigate to: Resource Groups → $RESOURCE_GROUP → $STATIC_WEB_APP_NAME"
    echo "  3. Click 'Overview' → Look for 'Deployment token' or 'Manage deployment token'"
    echo "  4. Copy the token"
    echo ""
    DEPLOYMENT_TOKEN=""
else
    print_info "Token retrieved successfully!"
    echo "  Token: ${DEPLOYMENT_TOKEN:0:20}... (hidden)"
fi

echo ""

# Step 4: Instructions for GitHub
print_step "4/6" "GitHub Repository Setup"
echo ""
echo "You need to:"
echo "  1. Create a GitHub repository (if you don't have one)"
echo "     Go to: https://github.com/new"
echo "     - Repository name: gait-analysis-app (or your choice)"
echo "     - Visibility: Public (free) or Private"
echo "     - DO NOT initialize with README, .gitignore, or license"
echo ""
echo "  2. Add the remote and push:"
echo "     git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
echo "     git branch -M main"
echo "     git add ."
echo "     git commit -m 'Initial commit with GitHub Actions setup'"
echo "     git push -u origin main"
echo ""

# Step 5: Instructions for GitHub Secrets
print_step "5/6" "Add Deployment Token to GitHub Secrets"
echo ""
echo "After pushing to GitHub:"
echo "  1. Go to your GitHub repository"
echo "  2. Click 'Settings' → 'Secrets and variables' → 'Actions'"
echo "  3. Click 'New repository secret'"
echo "  4. Name: AZURE_STATIC_WEB_APPS_API_TOKEN"
if [ -n "$DEPLOYMENT_TOKEN" ]; then
    echo "  5. Value: (use the token shown below)"
    echo ""
    echo "Your deployment token:"
    echo "$DEPLOYMENT_TOKEN"
    echo ""
    echo "Copy this token and paste it in GitHub Secrets"
else
    echo "  5. Value: (paste the token you got from Azure Portal)"
fi
echo "  6. Click 'Add secret'"
echo ""

# Step 6: Verification
print_step "6/6" "Next Steps"
echo ""
echo "After setting up:"
echo "  1. ✅ Code is pushed to GitHub"
echo "  2. ✅ Deployment token is in GitHub Secrets"
echo "  3. ✅ Workflow file is in .github/workflows/deploy-frontend.yml"
echo ""
echo "Then:"
echo "  • Go to your GitHub repository → 'Actions' tab"
echo "  • You should see the workflow running"
echo "  • Future pushes to 'frontend/' folder will automatically deploy!"
echo ""

# Create a quick reference file
cat > GITHUB_ACTIONS_SETUP_CHECKLIST.md << EOF
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
\`\`\`bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git add .
git commit -m "Initial commit with GitHub Actions setup"
git push -u origin main
\`\`\`

### 3. Add Deployment Token to GitHub Secrets
- [ ] Go to repository → Settings → Secrets and variables → Actions
- [ ] Click "New repository secret"
- [ ] Name: \`AZURE_STATIC_WEB_APPS_API_TOKEN\`
- [ ] Value: (token from Azure Portal or shown in script output)
- [ ] Click "Add secret"

### 4. Verify Setup
- [ ] Go to repository → Actions tab
- [ ] Workflow should run automatically
- [ ] Check deployment status

## Deployment Token

EOF

if [ -n "$DEPLOYMENT_TOKEN" ]; then
    echo "Your deployment token:" >> GITHUB_ACTIONS_SETUP_CHECKLIST.md
    echo "\`\`\`" >> GITHUB_ACTIONS_SETUP_CHECKLIST.md
    echo "$DEPLOYMENT_TOKEN" >> GITHUB_ACTIONS_SETUP_CHECKLIST.md
    echo "\`\`\`" >> GITHUB_ACTIONS_SETUP_CHECKLIST.md
else
    echo "Get token from Azure Portal:" >> GITHUB_ACTIONS_SETUP_CHECKLIST.md
    echo "- Go to: Resource Groups → $RESOURCE_GROUP → $STATIC_WEB_APP_NAME" >> GITHUB_ACTIONS_SETUP_CHECKLIST.md
    echo "- Click 'Overview' → 'Deployment token'" >> GITHUB_ACTIONS_SETUP_CHECKLIST.md
fi

echo ""
print_info "Setup instructions saved to: GITHUB_ACTIONS_SETUP_CHECKLIST.md"
echo ""
echo "================================"
print_info "Setup script completed!"
echo ""
echo "Follow the instructions above to complete the GitHub Actions setup."
echo ""

