#!/bin/bash
# Pre-commit validation script for Python syntax and indentation
# This script should be run before any commit to catch syntax errors early

set -e  # Exit on error

echo "🔍 Validating Python syntax and indentation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
FILES_CHECKED=0

# Function to check a Python file
check_python_file() {
    local file=$1
    FILES_CHECKED=$((FILES_CHECKED + 1))
    
    echo -n "  Checking $file... "
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}SKIP (not found)${NC}"
        return 0
    fi
    
    # Compile check (catches syntax errors)
    if python3 -m py_compile "$file" 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗ Syntax error${NC}"
        python3 -m py_compile "$file" 2>&1 | head -5
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Check all Python files in backend
echo "📁 Checking backend Python files..."

# Critical files that must be valid
CRITICAL_FILES=(
    "backend/main_integrated.py"
    "backend/app/api/v1/analysis_azure.py"
    "backend/app/services/gait_analysis.py"
    "backend/app/core/database_azure_sql.py"
    "backend/app/core/middleware.py"
    "backend/app/core/schemas.py"
    "backend/app/core/exceptions.py"
)

for file in "${CRITICAL_FILES[@]}"; do
    check_python_file "$file"
done

# Check all Python files in backend/app
echo ""
echo "📁 Checking all Python files in backend/app..."
find backend/app -name "*.py" -type f | while read -r file; do
    check_python_file "$file"
done

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All $FILES_CHECKED Python files are valid!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s) in $FILES_CHECKED file(s)${NC}"
    echo -e "${RED}Please fix syntax errors before committing.${NC}"
    exit 1
fi
