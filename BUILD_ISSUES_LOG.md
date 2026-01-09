# Build Issues Log

This document tracks recurring build issues to prevent them from resurfacing.

## Critical Issues to Always Check

### 1. Python Syntax and Indentation Errors
**Issue**: Syntax errors and indentation mistakes prevent modules from loading, causing "name 'X' is not defined" errors.

**Common Causes**:
- Missing or incorrect indentation in try/except blocks
- Incorrect indentation in function arguments
- Missing docstring quotes
- Inconsistent indentation levels

**Prevention**:
- Always run `python3 -m py_compile <file>` before committing
- Use `scripts/validate-python-syntax.sh` before commits
- Check indentation in:
  - Try/except blocks
  - Function definitions
  - Nested function calls
  - Dictionary/list literals in function calls

**Files Most Affected**:
- `backend/app/api/v1/analysis_azure.py` (large file, many nested blocks)
- `backend/app/services/gait_analysis.py`
- `backend/main_integrated.py`

### 2. Missing Imports
**Issue**: Using modules/functions before importing them.

**Prevention**:
- Always import at the top of the file
- Check for circular imports
- Verify all imports are present before using

**Common Missing Imports**:
- `threading` (used in analysis_azure.py)
- `time` (used in multiple files)
- `os` (used in multiple files)

### 3. Module Import Failures
**Issue**: "Failed to import analysis router: name 'X' is not defined"

**Root Cause**: Usually a syntax error preventing the module from loading, not actually a missing import.

**Prevention**:
- Always validate syntax before committing
- Check that all imports are at module level (not inside functions)
- Verify no code executes at module level that uses unimported modules

### 4. Indentation in Function Calls
**Issue**: Multi-line function calls with incorrect indentation.

**Example**:
```python
# WRONG
await process_analysis_azure(
analysis_id,  # Missing indentation
video_url,
)

# CORRECT
await process_analysis_azure(
    analysis_id,  # Properly indented
    video_url,
)
```

**Prevention**:
- Always indent continuation lines in function calls
- Use consistent indentation (4 spaces)
- Check all multi-line function calls

### 5. Try/Except Block Indentation
**Issue**: Code inside try/except blocks not properly indented.

**Example**:
```python
# WRONG
try:
code_here()  # Missing indentation
except:
    pass

# CORRECT
try:
    code_here()  # Properly indented
except:
    pass
```

**Prevention**:
- Always indent code inside try/except blocks
- Check that except blocks align with try
- Verify finally blocks are properly indented

## Validation Checklist

Before every commit, verify:

- [ ] All Python files compile: `python3 -m py_compile <file>`
- [ ] No syntax errors in critical files
- [ ] All imports are present and correct
- [ ] Indentation is consistent (4 spaces)
- [ ] Try/except blocks are properly indented
- [ ] Function call arguments are properly indented
- [ ] Docstrings are properly quoted
- [ ] No module-level code uses unimported modules

## Automated Validation

Run before committing:
```bash
./scripts/pre-commit-checks.sh
```

Or validate specific files:
```bash
./scripts/validate-python-syntax.sh
```

## History of Issues

### 2026-01-09: Multiple Indentation Errors
- **Files**: `backend/app/api/v1/analysis_azure.py`
- **Issues**: 
  - Missing indentation in try blocks (lines 52, 248, 261, 391, 718, 740, 769, 851, 1628, 1705, 1792, 1837)
  - Incorrect indentation in function calls (lines 527-534)
  - Missing docstring quotes (line 635)
- **Impact**: Module failed to load, causing "name 'threading' is not defined" error
- **Resolution**: Fixed all indentation errors systematically
- **Prevention**: Created validation scripts and this log
