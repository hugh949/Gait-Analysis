#!/usr/bin/env python3
"""
Script to fix stuck analyses using the force-complete endpoint
Finds analyses stuck in report_generation and marks them as completed
"""
import json
import subprocess
import sys

API_URL = "https://gaitanalysisapp.azurewebsites.net"

def get_stuck_analyses():
    """Get list of analyses stuck in report_generation"""
    print("=" * 80)
    print("FIXING STUCK ANALYSES")
    print("=" * 80)
    print()
    
    try:
        # Get list of all analyses
        result = subprocess.run(
            ["curl", "-s", f"{API_URL}/api/v1/analysis/list"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            print(f"❌ Failed to fetch analyses: {result.stderr}")
            return []
        
        data = json.loads(result.stdout)
        analyses = data.get('analyses', [])
        
        # Find stuck analyses
        stuck = []
        for analysis in analyses:
            status = analysis.get('status', 'unknown')
            current_step = analysis.get('current_step', 'unknown')
            step_progress = analysis.get('step_progress', 0)
            metrics = analysis.get('metrics', {})
            
            # Stuck if: processing status, report_generation step, high progress, has metrics
            if (status == 'processing' and 
                current_step == 'report_generation' and 
                step_progress >= 98 and
                metrics and len(metrics) > 0):
                stuck.append(analysis)
        
        return stuck
        
    except Exception as e:
        print(f"❌ Error getting stuck analyses: {e}")
        return []

def force_complete(analysis_id):
    """Force complete an analysis"""
    try:
        result = subprocess.run(
            ["curl", "-s", "-X", "POST", f"{API_URL}/api/v1/analysis/{analysis_id}/force-complete"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            return {"success": False, "error": result.stderr}
        
        response = json.loads(result.stdout)
        return response
        
    except Exception as e:
        return {"success": False, "error": str(e)}

def main():
    stuck = get_stuck_analyses()
    
    if not stuck:
        print("✅ No stuck analyses found!")
        return
    
    print(f"Found {len(stuck)} stuck analyses:")
    for analysis in stuck:
        analysis_id = analysis.get('id', 'unknown')
        step_progress = analysis.get('step_progress', 0)
        metrics_count = len(analysis.get('metrics', {}))
        print(f"  - {analysis_id} ({step_progress}% progress, {metrics_count} metrics)")
    print()
    
    # Ask for confirmation
    response = input(f"Fix {len(stuck)} stuck analyses? (yes/no): ")
    if response.lower() != 'yes':
        print("Cancelled.")
        return
    
    print()
    print("Fixing analyses...")
    print()
    
    fixed = 0
    failed = 0
    
    for analysis in stuck:
        analysis_id = analysis.get('id', 'unknown')
        print(f"Fixing {analysis_id}...", end=" ")
        
        result = force_complete(analysis_id)
        
        if result.get('status') == 'success':
            print("✅ Fixed!")
            fixed += 1
        else:
            print(f"❌ Failed: {result.get('message', result.get('error', 'Unknown error'))}")
            failed += 1
    
    print()
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"✅ Fixed: {fixed}")
    print(f"❌ Failed: {failed}")
    print(f"📊 Total: {len(stuck)}")
    
    if fixed > 0:
        print()
        print("✅ Successfully fixed analyses! Reports should now be available.")

if __name__ == "__main__":
    main()
