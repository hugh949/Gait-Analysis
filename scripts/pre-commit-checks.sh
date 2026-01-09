#!/bin/bash
# Comprehensive pre-commit validation
# Run this before every commit to ensure code quality

set -e

echo "🚀 Running pre-commit validation checks..."
echo ""

# Run Python syntax validation
if ! ./scripts/validate-python-syntax.sh; then
    echo ""
    echo "❌ Pre-commit checks failed. Please fix errors before committing."
    exit 1
fi

echo ""
echo "✅ All pre-commit checks passed!"
echo ""
