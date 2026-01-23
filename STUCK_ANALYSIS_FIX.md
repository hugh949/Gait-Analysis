# Stuck Analysis Fix - Auto-Detection and Recovery

## Problem
- Analyses were getting stuck in `report_generation` with 100% progress but status remained 'processing'
- When users visited the app URL, it would automatically resume these stuck analyses
- Users couldn't start new analyses because the app kept showing the old stuck one
- Users had to manually cancel to start again

## Root Cause
The frontend's resume logic (`checkExistingAnalysis`) was automatically resuming ANY analysis with `status='processing'`, including stuck ones that had been processing for hours.

## Fixes Implemented

### 1. Auto-Detection of Stuck Analyses ✅
**Criteria for "stuck":**
- `current_step === 'report_generation'`
- `step_progress >= 98%`
- Processing for >5 minutes
- Has metrics (indicating processing actually completed)

### 2. Auto-Fix Mechanism ✅
When a stuck analysis is detected:
1. Automatically calls `/api/v1/analysis/{id}/force-complete` endpoint
2. If successful, marks analysis as completed
3. If failed, skips resuming it and clears localStorage

### 3. Updated Resume Logic ✅
**In `checkExistingAnalysis` function:**
- Filters out stuck analyses before resuming
- Only resumes valid, actively processing analyses
- Clears localStorage for stuck analyses that can't be fixed
- Prevents showing old stuck analyses when visiting the URL

**In localStorage fallback:**
- Checks if analysis from localStorage is stuck
- Attempts auto-fix if stuck
- Only resumes if not stuck or auto-fix successful

## How It Works

1. **On Page Load:**
   - Checks for processing analyses from API
   - Filters out stuck analyses
   - Attempts to auto-fix stuck analyses in background
   - Only resumes valid analyses

2. **From localStorage:**
   - Checks if stored analysis ID is stuck
   - Attempts auto-fix if stuck
   - Updates to completed state if auto-fix succeeds
   - Clears localStorage if stuck and can't be fixed

3. **User Experience:**
   - No more seeing old stuck analyses
   - Can immediately start new analyses
   - Stuck analyses are automatically fixed in background

## Testing

After deployment, verify:
1. Visit app URL - should not show stuck analyses
2. Start new analysis - should work immediately
3. Check console logs - should see auto-fix attempts for stuck analyses
4. Run diagnostic script - should show fewer stuck analyses

## Manual Fix (if needed)

If auto-fix doesn't work, manually fix stuck analyses:
```bash
python3 scripts/fix_stuck_analyses.py
```

Or via API:
```bash
curl -X POST https://gaitanalysisapp.azurewebsites.net/api/v1/analysis/{analysis_id}/force-complete
```
