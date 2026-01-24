#!/bin/bash
# Wrapper script to run the automated testing loop

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
BASE_URL="${BASE_URL:-http://localhost:8000}"
TEST_INTERVAL="${TEST_INTERVAL:-30}"

echo "🚀 Starting Automated Testing and Bug Fixing Loop"
echo "Project Root: $PROJECT_ROOT"
echo "Base URL: $BASE_URL"
echo "Test Interval: ${TEST_INTERVAL}s"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found"
    exit 1
fi

# Check if requests library is available
if ! python3 -c "import requests" 2>/dev/null; then
    echo "⚠️  Warning: requests library not found. Installing..."
    pip3 install requests --quiet
fi

# Run the testing loop
export BASE_URL
export TEST_INTERVAL

python3 "$SCRIPT_DIR/auto_test_and_fix.py" "$@"
