# Fix Deployment Network Issue

## Problem
The Cursor AI terminal environment has restricted network permissions that prevent:
- DNS resolution (cannot resolve github.com)
- Git push operations
- Network connections

However, **GitHub Actions deployments work automatically** - they run in the cloud, not locally. The issue is only with pushing code from this terminal.

## Solution Options

### Option 1: Use Your Own Terminal (Recommended)
Run these commands from your own terminal (Terminal.app, iTerm2, etc.):

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis
git push origin main
```

### Option 2: Use the Push Script
I've created a helper script that you can run from your terminal:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis
./scripts/push-and-deploy.sh
```

This script will:
- Check for uncommitted changes
- Show what will be pushed
- Push to GitHub
- Show deployment monitoring links

### Option 3: Switch to SSH (If HTTPS Fails)
If HTTPS continues to fail, configure git to use SSH:

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis

# Switch remote to SSH
git remote set-url origin git@github.com:hugh949/Gait-Analysis.git

# Verify
git remote -v

# Push
git push origin main
```

**Note:** You'll need SSH keys set up with GitHub. If not already done:
```bash
# Generate SSH key (if needed)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key and add to GitHub
cat ~/.ssh/id_ed25519.pub
# Then go to: https://github.com/settings/keys and add the key
```

### Option 4: Fix DNS Resolution
If DNS is the issue, try flushing DNS cache:

```bash
# Flush DNS cache (macOS)
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Or restart network services
sudo ifconfig en0 down && sudo ifconfig en0 up
```

## How Automatic Deployment Works

Once you push to GitHub:

1. **GitHub Actions triggers automatically** when you push to `main` branch
2. **Workflow runs in the cloud** (not on your machine)
3. **Builds and deploys** to Azure automatically
4. **No local network needed** after the push

The workflow file is: `.github/workflows/deploy-integrated.yml`

## Verify Deployment

After pushing, check deployment status:

1. **GitHub Actions**: https://github.com/hugh949/Gait-Analysis/actions
2. **Latest workflow**: https://github.com/hugh949/Gait-Analysis/actions/workflows/deploy-integrated.yml
3. **Azure Portal**: Check App Service logs

## Current Status

✅ **Code is ready**: Commit `604d410` is ready locally
✅ **Deployment workflow**: Configured and ready
❌ **Push blocked**: Terminal environment has network restrictions

**Next step**: Push from your own terminal using one of the options above.

## Troubleshooting

### "Could not resolve host: github.com"
- Use SSH instead of HTTPS (Option 3)
- Check your internet connection
- Try from a different terminal

### "Permission denied (publickey)"
- Set up SSH keys with GitHub (see Option 3)
- Or use HTTPS with personal access token

### "Authentication failed"
- Check git credentials: `git config --list | grep credential`
- Re-authenticate: `gh auth login` (if using GitHub CLI)

### Workflow Not Triggering
- Ensure you're pushing to `main` branch
- Check that files changed are in: `backend/**`, `frontend/**`, or workflow files
- Verify workflow file exists: `.github/workflows/deploy-integrated.yml`

## Quick Reference

```bash
# Check status
git status

# See what will be pushed
git log origin/main..HEAD --oneline

# Push (from your terminal)
git push origin main

# Monitor deployment
open https://github.com/hugh949/Gait-Analysis/actions
```
