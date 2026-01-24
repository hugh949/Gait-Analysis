# Standard Development Practices

## Critical Practice: Check Logs Before Making Changes

**ALWAYS check Azure Log Stream logs before making any changes to understand current app behavior.**

### Why This Matters
- Prevents breaking working functionality
- Identifies root cause before applying fixes
- Shows actual runtime behavior vs. expected behavior
- Reveals patterns in failures
- Helps make targeted, minimal changes

### When to Check Logs
1. **Before any bug fix** - Understand what's actually happening
2. **Before adding new features** - See current state
3. **After user reports an issue** - Get real error messages
4. **Before refactoring** - Understand current flow
5. **When investigating failures** - See exact failure points

### How to Check Logs

#### Option 1: Use Scripts (Recommended)
```bash
# Fetch recent logs
./scripts/fetch_azure_logs.sh

# Fetch and filter for specific patterns
./scripts/fetch_azure_logs_filtered.sh "STEP 3"
./scripts/fetch_azure_logs_filtered.sh "STEP 4"
./scripts/fetch_azure_logs_filtered.sh "ERROR"
```

#### Option 2: Azure Portal
1. Go to Azure Portal
2. Navigate to App Service: `gaitanalysisapp`
3. Go to "Log stream" in left menu
4. Filter/search for relevant patterns

#### Option 3: Azure CLI
```bash
az webapp log tail --name gaitanalysisapp --resource-group gait-analysis-rg
```

### What to Look For

#### Step 3 Logs
- `[STEP 3 ENTRY]` - Step 3 started
- `✅ Step 3 validation passed` - Input validation succeeded
- `🔍 Calling _calculate_gait_metrics()` - Metrics calculation started
- `✅ Gait metrics calculated` - Metrics calculation completed
- `✅ Metrics in result` - Metrics included in result
- `❌` - Any errors

#### Step 4 Logs
- `[STEP 4 ENTRY]` - Step 4 started
- `🔍 Metrics validation` - Metrics validation in progress
- `✅ Metrics validation PASSED` - Validation succeeded
- `✅ Verification passed - analysis marked as completed` - Completion succeeded
- `❌` - Any errors

#### General Patterns
- `❌` - Errors (critical)
- `⚠️` - Warnings (important)
- `✅` - Success indicators
- `🔍` - Diagnostic/info logs

### Code Integrity Principles

1. **Don't Break Working Systems**
   - Steps 1-2 are working - don't modify them
   - Upload endpoint works - don't change it
   - Only fix what's broken

2. **Minimal, Targeted Changes**
   - Fix only the specific issue
   - Don't refactor unnecessarily
   - Test each change independently

3. **Verify Before Committing**
   - Check syntax: `python3 -m py_compile`
   - Review changes: `git diff`
   - Understand impact before pushing

4. **Track Changes**
   - Clear commit messages
   - Document what was changed and why
   - Reference issue/request in commits

### Workflow

1. **User reports issue or requests change**
2. **Check Azure Log Stream logs** ← CRITICAL STEP
3. **Analyze logs to understand current behavior**
4. **Identify root cause**
5. **Make minimal targeted fix**
6. **Test and verify**
7. **Commit with clear message**

### Log Analysis Checklist

Before making changes, verify:
- [ ] What is the current behavior? (from logs)
- [ ] Where exactly does it fail? (error location)
- [ ] What error messages appear? (exact text)
- [ ] Are there patterns? (repeated failures)
- [ ] What was the last successful operation? (baseline)
- [ ] What changed since it last worked? (if known)

### Remember

**Logs tell the truth. Code tells intentions.**
Always check logs first to see what's actually happening, not what we think should happen.
