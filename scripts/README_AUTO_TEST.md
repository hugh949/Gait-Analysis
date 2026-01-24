# Automated Testing and Bug Fixing Loop

This directory contains automated testing scripts that continuously test the application and attempt to fix detected bugs.

## Scripts

### 1. `auto_test_and_fix.py`
Basic automated testing loop that:
- Tests all API endpoints
- Detects bugs and errors
- Attempts to fix common issues
- Logs all results
- Runs continuously

### 2. `auto_test_enhanced.py`
Advanced version with:
- Code analysis for common Python issues
- Auto-fixing of UnboundLocalError (removes local imports)
- Auto-fixing of missing module imports
- Syntax error detection
- More comprehensive bug detection

### 3. `run_auto_test.sh`
Wrapper script to easily run the testing loop

## Usage

### Basic Usage
```bash
# Test against localhost
./scripts/run_auto_test.sh

# Test against production
BASE_URL=https://your-app.azurewebsites.net ./scripts/run_auto_test.sh

# Custom test interval (default: 30 seconds)
TEST_INTERVAL=60 ./scripts/run_auto_test.sh
```

### Direct Python Usage
```bash
# Basic version
python3 scripts/auto_test_and_fix.py

# Enhanced version
python3 scripts/auto_test_enhanced.py

# With environment variables
BASE_URL=http://localhost:8000 TEST_INTERVAL=30 python3 scripts/auto_test_and_fix.py
```

## What It Tests

1. **Root Endpoint** (`/`)
2. **Health Endpoint** (`/health`)
3. **API Health** (`/api/v1/health`)
4. **Debug Routes** (`/api/v1/debug/routes`)
   - Verifies upload endpoint is registered
5. **List Analyses** (`/api/v1/analysis/list`)
6. **Python Syntax** - Checks for syntax errors
7. **File Structure** - Verifies required files exist
8. **Code Issues** (enhanced version):
   - UnboundLocalError (local imports)
   - Missing module imports
   - Unclosed try blocks

## What It Can Fix

### Auto-Fixable Issues:
- ✅ Missing module-level imports (os, threading)
- ✅ Local imports that cause UnboundLocalError
- ✅ File structure verification

### Manual Fix Required:
- ❌ Syntax errors (reports but doesn't fix)
- ❌ Application startup issues (reports but doesn't restart)
- ❌ Database connection issues (reports only)

## Output Files

- `auto_test_fix.log` - Detailed log of all tests and fixes
- `test_results.json` - JSON summary of test results

## Example Output

```
[2026-01-23 10:00:00] [INFO] 🚀 Starting Automated Testing Loop
[2026-01-23 10:00:00] [INFO] 🔍 Starting bug detection cycle...
[2026-01-23 10:00:00] [INFO] Testing root endpoint (/)
[2026-01-23 10:00:00] [INFO] ✅ Root endpoint OK
[2026-01-23 10:00:00] [INFO] Testing /health endpoint...
[2026-01-23 10:00:00] [INFO] ✅ Health endpoint OK
...
[2026-01-23 10:00:05] [INFO] ✅ All tests passed - no bugs detected!
```

## Running in Background

```bash
# Run in background
nohup ./scripts/run_auto_test.sh > test_output.log 2>&1 &

# Check status
tail -f auto_test_fix.log

# Stop
pkill -f auto_test_and_fix.py
```

## Integration with CI/CD

You can integrate this into your CI/CD pipeline:

```yaml
# Example GitHub Actions step
- name: Run automated tests
  run: |
    python3 scripts/auto_test_enhanced.py &
    sleep 300  # Run for 5 minutes
    pkill -f auto_test_enhanced.py
```

## Customization

Edit the scripts to:
- Add more test cases
- Implement additional auto-fixes
- Change test intervals
- Add notifications (email, Slack, etc.)
- Integrate with monitoring systems
