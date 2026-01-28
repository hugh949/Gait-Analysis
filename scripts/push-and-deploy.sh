#!/bin/bash
# Push to GitHub and trigger automatic deployment
# This script handles pushing code and verifying deployment status

set -e

echo "🚀 Push and Deploy Script"
echo "========================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if [ ! -d .git ]; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${YELLOW}Current branch: ${CURRENT_BRANCH}${NC}"

if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${YELLOW}⚠️  Warning: Not on main branch. Deployments typically happen from main.${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes:${NC}"
    git status --short
    echo ""
    read -p "Do you want to commit these changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enter commit message (or press Enter for default):"
        read -r COMMIT_MSG
        if [ -z "$COMMIT_MSG" ]; then
            COMMIT_MSG="Auto-commit before deployment"
        fi
        git add -A
        git commit -m "$COMMIT_MSG"
        echo -e "${GREEN}✅ Changes committed${NC}"
    else
        echo -e "${YELLOW}Skipping commit...${NC}"
    fi
fi

# Check if we're ahead of origin
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
if [ "$AHEAD" -gt 0 ]; then
    echo -e "${YELLOW}📤 You have $AHEAD commit(s) to push${NC}"
else
    echo -e "${GREEN}✅ Branch is up to date with origin/main${NC}"
    echo "Checking if there are any local commits..."
    LOCAL_COMMITS=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$LOCAL_COMMITS" -eq 0 ]; then
        echo -e "${YELLOW}No new commits to push${NC}"
        exit 0
    fi
fi

# Show what will be pushed
echo ""
echo -e "${YELLOW}Commits to be pushed:${NC}"
git log origin/main..HEAD --oneline 2>/dev/null || git log -5 --oneline
echo ""

# Try to push
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
if git push origin "$CURRENT_BRANCH"; then
    echo -e "${GREEN}✅ Successfully pushed to GitHub!${NC}"
    echo ""
    
    # Get the commit SHA
    COMMIT_SHA=$(git rev-parse HEAD)
    SHORT_SHA=$(git rev-parse --short HEAD)
    
    echo -e "${GREEN}🚀 Deployment Information:${NC}"
    echo "  Commit: $SHORT_SHA"
    echo "  Branch: $CURRENT_BRANCH"
    echo "  Repository: https://github.com/hugh949/Gait-Analysis"
    echo ""
    echo -e "${YELLOW}📊 Monitor deployment:${NC}"
    echo "  GitHub Actions: https://github.com/hugh949/Gait-Analysis/actions"
    echo "  Latest workflow: https://github.com/hugh949/Gait-Analysis/actions/workflows/deploy-integrated.yml"
    echo ""
    echo -e "${YELLOW}⏳ Deployment typically takes 5-10 minutes${NC}"
    echo ""
    
    # Check if GitHub CLI is available
    if command -v gh &> /dev/null; then
        echo -e "${YELLOW}Checking GitHub Actions status...${NC}"
        sleep 2
        gh run list --limit 1 --workflow=deploy-integrated.yml 2>/dev/null || echo "Could not fetch workflow status"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Push complete! GitHub Actions will automatically deploy to Azure.${NC}"
else
    echo -e "${RED}❌ Push failed!${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check your internet connection"
    echo "2. Verify GitHub credentials: git config --list | grep credential"
    echo "3. Try SSH instead: git remote set-url origin git@github.com:hugh949/Gait-Analysis.git"
    echo "4. Check GitHub status: https://www.githubstatus.com"
    exit 1
fi
