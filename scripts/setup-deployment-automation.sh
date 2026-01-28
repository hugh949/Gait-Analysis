#!/bin/bash
# Setup deployment automation for easy git push and deploy
# Run this once: ./scripts/setup-deployment-automation.sh

set -e

echo "🔧 Setting Up Deployment Automation"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get the repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo -e "${BLUE}Repository: $REPO_ROOT${NC}"
echo ""

# 1. Create git aliases for easy deployment
echo -e "${YELLOW}📝 Setting up git aliases...${NC}"

git config alias.deploy '!git push origin main && echo "✅ Deployment triggered! Monitor at: https://github.com/hugh949/Gait-Analysis/actions"'
git config alias.deploy-status '!gh run list --limit 3 --workflow=deploy-integrated.yml || open https://github.com/hugh949/Gait-Analysis/actions'
git config alias.quick-commit '!f() { git add -A && git commit -m "${1:-Quick commit}" && echo "✅ Committed. Run: git deploy"; }; f'

echo -e "${GREEN}  ✅ Git aliases created:${NC}"
echo "     git deploy           - Push and trigger deployment"
echo "     git deploy-status    - Check deployment status"
echo "     git quick-commit     - Quick commit all changes"
echo ""

# 2. Create post-commit hook to remind about deployment
echo -e "${YELLOW}📝 Creating post-commit hook...${NC}"

cat > .git/hooks/post-commit << 'HOOK_EOF'
#!/bin/bash
# Post-commit hook - reminds to push/deploy

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're ahead of origin
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")

if [ "$AHEAD" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Commit successful!${NC}"
    echo ""
    echo -e "${BLUE}💡 Quick deploy options:${NC}"
    echo ""
    echo -e "   ${GREEN}git deploy${NC}              - Push and deploy now"
    echo -e "   ${GREEN}git push origin main${NC}    - Standard push"
    echo -e "   ${GREEN}./scripts/push-and-deploy.sh${NC} - Interactive push"
    echo ""
    echo -e "${YELLOW}📊 You have $AHEAD commit(s) ready to push${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi
HOOK_EOF

chmod +x .git/hooks/post-commit
echo -e "${GREEN}  ✅ Post-commit hook created${NC}"
echo ""

# 3. Create a simple deploy command
echo -e "${YELLOW}📝 Creating quick deploy command...${NC}"

cat > scripts/deploy << 'DEPLOY_EOF'
#!/bin/bash
# Quick deploy - commit and push in one command
# Usage: ./scripts/deploy [commit-message]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get commit message from argument or use default
COMMIT_MSG="${1:-Auto-deploy: $(date +'%Y-%m-%d %H:%M')}"

echo -e "${YELLOW}🚀 Quick Deploy${NC}"
echo "==============="
echo ""

# Check for changes
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}No changes to commit${NC}"
    
    # Check if we're ahead
    AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
    if [ "$AHEAD" -gt 0 ]; then
        echo -e "${GREEN}Found $AHEAD commit(s) to push${NC}"
        echo ""
        read -p "Push to GitHub and deploy? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin main
            echo ""
            echo -e "${GREEN}✅ Deployed! Monitor at: https://github.com/hugh949/Gait-Analysis/actions${NC}"
        fi
    else
        echo -e "${GREEN}Everything up to date!${NC}"
    fi
    exit 0
fi

# Show changes
echo -e "${YELLOW}Changes to commit:${NC}"
git status --short
echo ""

# Commit
echo -e "${YELLOW}📝 Committing: $COMMIT_MSG${NC}"
git add -A
git commit -m "$COMMIT_MSG"
echo ""

# Push
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
if git push origin main; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Deployment Started!${NC}"
    echo ""
    echo "📊 Monitor deployment:"
    echo "   https://github.com/hugh949/Gait-Analysis/actions"
    echo ""
    echo "⏳ Deployment typically takes 5-10 minutes"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo ""
    echo -e "${RED}❌ Push failed! Check network connection.${NC}"
    exit 1
fi
DEPLOY_EOF

chmod +x scripts/deploy
echo -e "${GREEN}  ✅ Quick deploy command created${NC}"
echo ""

# 4. Create shell aliases file
echo -e "${YELLOW}📝 Creating shell aliases...${NC}"

cat > scripts/shell-aliases.sh << 'ALIAS_EOF'
# Gait Analysis Deployment Aliases
# Add these to your ~/.zshrc or ~/.bashrc:
# source ~/Cursor/Gait-Analysis/scripts/shell-aliases.sh

# Quick navigation
alias gait='cd ~/Cursor/Gait-Analysis'

# Deployment commands
alias gait-deploy='cd ~/Cursor/Gait-Analysis && git push origin main && echo "✅ Deployed! https://github.com/hugh949/Gait-Analysis/actions"'
alias gait-quick='cd ~/Cursor/Gait-Analysis && ./scripts/deploy'
alias gait-status='cd ~/Cursor/Gait-Analysis && git status'
alias gait-logs='cd ~/Cursor/Gait-Analysis && gh run list --limit 5 --workflow=deploy-integrated.yml || open https://github.com/hugh949/Gait-Analysis/actions'

# Azure commands
alias gait-azure-logs='az webapp log tail --name gaitanalysisapp --resource-group gait-analysis-rg-wus3'
alias gait-azure-status='az webapp show --name gaitanalysisapp --resource-group gait-analysis-rg-wus3 --query state -o tsv'

echo "✅ Gait Analysis aliases loaded"
ALIAS_EOF

echo -e "${GREEN}  ✅ Shell aliases file created${NC}"
echo ""

# 5. Update .gitignore to exclude certain files
echo -e "${YELLOW}📝 Updating .gitignore...${NC}"

if ! grep -q "downloaded_logs/" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Local logs and test files" >> .gitignore
    echo "downloaded_logs/" >> .gitignore
    echo "logs.zip" >> .gitignore
    echo "test_video.mp4" >> .gitignore
    echo "test_walking_video.mp4" >> .gitignore
fi

echo -e "${GREEN}  ✅ .gitignore updated${NC}"
echo ""

# 6. Create a README for deployment commands
echo -e "${YELLOW}📝 Creating deployment commands README...${NC}"

cat > DEPLOYMENT_COMMANDS.md << 'README_EOF'
# Deployment Commands Quick Reference

## One-Line Deployment

### Quick Deploy (Commit + Push)
```bash
./scripts/deploy "Your commit message"
```
Or with default message:
```bash
./scripts/deploy
```

### Just Push (No Commit)
```bash
git deploy
```
Or standard:
```bash
git push origin main
```

## Git Aliases (Already Configured)

```bash
# Push and deploy
git deploy

# Check deployment status
git deploy-status

# Quick commit all changes
git quick-commit "Your message"
```

## Shell Aliases (Optional - Add to ~/.zshrc)

Add this line to your `~/.zshrc` or `~/.bashrc`:
```bash
source ~/Cursor/Gait-Analysis/scripts/shell-aliases.sh
```

Then you can use:
```bash
gait               # Navigate to project
gait-deploy        # Push and deploy
gait-quick         # Quick deploy script
gait-status        # Git status
gait-logs          # View deployment logs
gait-azure-logs    # View Azure logs
gait-azure-status  # Check Azure status
```

## Deployment Workflow

### Standard Flow
```bash
# 1. Make changes to code
# (AI does this)

# 2. Commit changes
git add .
git commit -m "Your message"

# 3. Push and deploy
git deploy
# or
git push origin main
```

### Quick Flow
```bash
# All in one command
./scripts/deploy "Your commit message"
```

## Monitor Deployment

### GitHub Actions
- View all runs: https://github.com/hugh949/Gait-Analysis/actions
- View workflow: https://github.com/hugh949/Gait-Analysis/actions/workflows/deploy-integrated.yml

### Using CLI
```bash
# GitHub CLI
gh run list --limit 5
gh run watch  # Watch latest run

# Check Azure status
gait-azure-status

# View Azure logs
gait-azure-logs
```

## Troubleshooting

### Push Failed
```bash
# Check connection
curl -I https://github.com

# Try SSH instead
git remote set-url origin git@github.com:hugh949/Gait-Analysis.git
git push origin main
```

### Deployment Not Triggering
```bash
# Check workflow file exists
ls -la .github/workflows/deploy-integrated.yml

# Check branch
git branch --show-current  # Should be 'main'

# Manual trigger
gh workflow run deploy-integrated.yml
```

## What Happens After Push

1. **GitHub Actions triggers** (automatically)
2. **Builds frontend** (~2 min)
3. **Builds Docker image** (~3 min)
4. **Deploys to Azure** (~2 min)
5. **Health checks** (~1 min)

**Total time: 5-10 minutes**

## Current Status

To check what's ready to deploy:
```bash
# See pending commits
git log origin/main..HEAD --oneline

# See changed files
git status

# See all changes
git diff origin/main..HEAD
```
README_EOF

echo -e "${GREEN}  ✅ Deployment commands README created${NC}"
echo ""

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Deployment Automation Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📝 What was configured:${NC}"
echo ""
echo "  1. ✅ Git aliases (git deploy, git deploy-status, git quick-commit)"
echo "  2. ✅ Post-commit hook (reminds to push)"
echo "  3. ✅ Quick deploy script (./scripts/deploy)"
echo "  4. ✅ Shell aliases file (scripts/shell-aliases.sh)"
echo "  5. ✅ Updated .gitignore"
echo "  6. ✅ Deployment commands reference"
echo ""
echo -e "${YELLOW}🚀 Quick Start:${NC}"
echo ""
echo -e "  ${GREEN}One-line deploy:${NC}"
echo "    ./scripts/deploy \"Your commit message\""
echo ""
echo -e "  ${GREEN}Just push:${NC}"
echo "    git deploy"
echo ""
echo -e "  ${GREEN}Standard push:${NC}"
echo "    git push origin main"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC}"
echo "  - Read: DEPLOYMENT_COMMANDS.md"
echo "  - Read: FIX_DEPLOYMENT_NETWORK.md"
echo ""
echo -e "${YELLOW}⚙️  Optional: Add shell aliases to your terminal${NC}"
echo "  Add to ~/.zshrc:"
echo "    source ~/Cursor/Gait-Analysis/scripts/shell-aliases.sh"
echo ""
echo -e "${GREEN}Ready to deploy! Try: ./scripts/deploy${NC}"
echo ""
