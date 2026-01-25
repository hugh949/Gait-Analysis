#!/usr/bin/env python3
"""
Check Step 4 completion status for recent analyses
This helps diagnose if Step 4 database saves are failing
"""
import requests
import json
import sys
from datetime import datetime, timedelta

# API configuration
API_URL = "https://gaitanalysisapp.azurewebsites.net"  # Production
# API_URL = "http://localhost:8000"  # Local development

def check_recent_analyses():
    """Check recent analyses for Step 4 completion issues"""
    try:
        # Get list of analyses
        response = requests.get(f"{API_URL}/api/v1/analysis/list", timeout=10)
        if response.status_code != 200:
            print(f"❌ Failed to fetch analyses: {response.status_code}")
            return
        
        data = response.json()
        analyses = data.get('analyses', [])
        
        print("=" * 80)
        print("STEP 4 COMPLETION DIAGNOSTIC")
        print("=" * 80)
        print(f"Total analyses found: {len(analyses)}\n")
        
        # Filter for processing or recently completed analyses
        recent_analyses = []
        for analysis in analyses:
            status = analysis.get('status', 'unknown')
            current_step = analysis.get('current_step', 'unknown')
            step_progress = analysis.get('step_progress', 0)
            updated_at = analysis.get('updated_at') or analysis.get('created_at')
            
            # Check if it's in Step 4 or recently completed
            if (status == 'processing' and current_step == 'report_generation') or \
               (status == 'completed' and current_step == 'report_generation'):
                recent_analyses.append({
                    'id': analysis.get('id'),
                    'status': status,
                    'step': current_step,
                    'progress': step_progress,
                    'updated_at': updated_at,
                    'has_metrics': bool(analysis.get('metrics')),
                    'metrics_count': len(analysis.get('metrics', {}))
                })
        
        if not recent_analyses:
            print("✅ No analyses currently in Step 4 or recently completed")
            return
        
        print(f"Found {len(recent_analyses)} analyses in Step 4:\n")
        
        for analysis in recent_analyses:
            print(f"Analysis ID: {analysis['id'][:8]}...")
            print(f"  Status: {analysis['status']}")
            print(f"  Step: {analysis['step']}")
            print(f"  Progress: {analysis['progress']}%")
            print(f"  Updated: {analysis['updated_at']}")
            print(f"  Has Metrics: {analysis['has_metrics']} ({analysis['metrics_count']} metrics)")
            
            # Check if it's stuck
            if analysis['status'] == 'processing':
                try:
                    updated_time = datetime.fromisoformat(analysis['updated_at'].replace('Z', '+00:00'))
                    now = datetime.now(updated_time.tzinfo)
                    minutes_ago = (now - updated_time).total_seconds() / 60
                    
                    if minutes_ago > 5:
                        print(f"  ⚠️  STUCK: No update in {minutes_ago:.1f} minutes")
                        if analysis['progress'] >= 98:
                            print(f"  ⚠️  At 98%+ progress - likely database save issue")
                    else:
                        print(f"  ✅ Active: Updated {minutes_ago:.1f} minutes ago")
                except:
                    print(f"  ⚠️  Could not parse update time")
            
            # Check detailed status
            try:
                detail_response = requests.get(
                    f"{API_URL}/api/v1/analysis/{analysis['id']}",
                    timeout=10
                )
                if detail_response.status_code == 200:
                    detail = detail_response.json()
                    steps_completed = detail.get('steps_completed', {})
                    step4_complete = steps_completed.get('step_4_report_generation', False)
                    
                    if analysis['status'] == 'processing' and step4_complete:
                        print(f"  ⚠️  INCONSISTENCY: steps_completed says Step 4 is done, but status is 'processing'")
                    elif analysis['status'] == 'completed' and not step4_complete:
                        print(f"  ⚠️  INCONSISTENCY: Status is 'completed' but steps_completed says Step 4 not done")
                    else:
                        print(f"  ✅ Status consistent with steps_completed")
            except Exception as e:
                print(f"  ⚠️  Could not fetch detailed status: {e}")
            
            print()
        
        print("=" * 80)
        print("DIAGNOSIS:")
        print("=" * 80)
        
        stuck_count = sum(1 for a in recent_analyses if a['status'] == 'processing' and a['progress'] >= 98)
        if stuck_count > 0:
            print(f"⚠️  Found {stuck_count} analyses stuck at 98%+ progress")
            print("   This suggests database save is failing")
            print("   Check backend logs for:")
            print("   - 'Database update returned False'")
            print("   - 'Failed to mark analysis as completed'")
            print("   - 'CRITICAL: Analysis processing completed but database update failed'")
        else:
            print("✅ No stuck analyses found")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        print("   Make sure the API is accessible")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    check_recent_analyses()
