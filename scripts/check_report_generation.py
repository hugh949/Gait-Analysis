#!/usr/bin/env python3
"""
Diagnostic script to check if report generation is working
Checks if analyses are completing and if metrics are being saved
"""
import json
import subprocess
from datetime import datetime, timedelta

API_URL = "https://gaitanalysisapp.azurewebsites.net"

def check_analyses():
    """Check all analyses and their completion status"""
    print("=" * 80)
    print("REPORT GENERATION DIAGNOSTIC")
    print("=" * 80)
    print()
    
    try:
        # Get list of all analyses using curl
        result = subprocess.run(
            ["curl", "-s", f"{API_URL}/api/v1/analysis/list"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            print(f"❌ Failed to fetch analyses: {result.stderr}")
            return
        
        data = json.loads(result.stdout)
        analyses = data.get('analyses', [])
        
        print(f"📊 Total analyses found: {len(analyses)}")
        print()
        
        # Categorize analyses
        completed = []
        processing = []
        failed = []
        no_metrics = []
        
        for analysis in analyses:
            status = analysis.get('status', 'unknown')
            analysis_id = analysis.get('id', 'unknown')
            metrics = analysis.get('metrics', {})
            has_metrics = metrics and len(metrics) > 0
            current_step = analysis.get('current_step', 'unknown')
            step_progress = analysis.get('step_progress', 0)
            
            if status == 'completed':
                if has_metrics:
                    completed.append(analysis)
                else:
                    no_metrics.append(analysis)
            elif status == 'processing':
                processing.append(analysis)
            elif status == 'failed':
                failed.append(analysis)
        
        print("=" * 80)
        print("ANALYSIS STATUS SUMMARY")
        print("=" * 80)
        print(f"✅ Completed with metrics: {len(completed)}")
        print(f"⚠️  Completed but NO metrics: {len(no_metrics)}")
        print(f"🔄 Still processing: {len(processing)}")
        print(f"❌ Failed: {len(failed)}")
        print()
        
        # Detailed analysis of processing analyses
        if processing:
            print("=" * 80)
            print("PROCESSING ANALYSES (May be stuck)")
            print("=" * 80)
            for analysis in processing:
                analysis_id = analysis.get('id', 'unknown')
                current_step = analysis.get('current_step', 'unknown')
                step_progress = analysis.get('step_progress', 0)
                step_message = analysis.get('step_message', 'No message')
                created_at = analysis.get('created_at', 'unknown')
                
                # Calculate how long it's been processing
                try:
                    created_time = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                    elapsed = datetime.now(created_time.tzinfo) - created_time
                    elapsed_minutes = elapsed.total_seconds() / 60
                except:
                    elapsed_minutes = 0
                
                print(f"\n📋 Analysis ID: {analysis_id}")
                print(f"   Step: {current_step}")
                print(f"   Progress: {step_progress}%")
                print(f"   Message: {step_message}")
                print(f"   Created: {created_at}")
                print(f"   Elapsed: {elapsed_minutes:.1f} minutes")
                
                # Check if stuck in report_generation
                if current_step == 'report_generation' and step_progress >= 98:
                    print(f"   ⚠️  STUCK: In report_generation with {step_progress}% progress")
                    print(f"   ⚠️  This suggests the final database update may be failing")
        
        # Check completed analyses without metrics
        if no_metrics:
            print("=" * 80)
            print("COMPLETED ANALYSES WITHOUT METRICS (Problem!)")
            print("=" * 80)
            for analysis in no_metrics:
                analysis_id = analysis.get('id', 'unknown')
                print(f"❌ Analysis {analysis_id}: Status is 'completed' but has no metrics")
                print(f"   This means report generation didn't save metrics properly")
        
        # Check completed analyses with metrics
        if completed:
            print("=" * 80)
            print("SUCCESSFULLY COMPLETED ANALYSES (Reports Available)")
            print("=" * 80)
            for analysis in completed[:5]:  # Show first 5
                analysis_id = analysis.get('id', 'unknown')
                metrics = analysis.get('metrics', {})
                filename = analysis.get('filename', 'unknown')
                created_at = analysis.get('created_at', 'unknown')
                
                print(f"\n✅ Analysis ID: {analysis_id}")
                print(f"   Filename: {filename}")
                print(f"   Created: {created_at}")
                print(f"   Metrics count: {len(metrics)}")
                if 'cadence' in metrics:
                    print(f"   Cadence: {metrics.get('cadence')} steps/min")
                if 'walking_speed' in metrics:
                    print(f"   Walking Speed: {metrics.get('walking_speed')} mm/s")
                print(f"   Report URL: {API_URL}/report/{analysis_id}")
            
            if len(completed) > 5:
                print(f"\n... and {len(completed) - 5} more completed analyses")
        
        print()
        print("=" * 80)
        print("DIAGNOSIS")
        print("=" * 80)
        
        if len(completed) == 0:
            print("❌ CRITICAL: No analyses have completed successfully!")
            print("   This means report generation is NOT working.")
            print("   Possible causes:")
            print("   1. Database updates are failing silently")
            print("   2. Metrics are not being saved to database")
            print("   3. Status is not being updated to 'completed'")
        elif len(processing) > 0:
            stuck_in_report = [a for a in processing if a.get('current_step') == 'report_generation' and a.get('step_progress', 0) >= 98]
            if stuck_in_report:
                print(f"⚠️  WARNING: {len(stuck_in_report)} analyses are stuck in report_generation")
                print("   They have high progress (98-100%) but status is still 'processing'")
                print("   This suggests the final database update is failing")
        else:
            print("✅ Report generation appears to be working")
            print(f"   {len(completed)} analyses have completed with metrics")
        
    except Exception as e:
        print(f"❌ Error checking analyses: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    check_analyses()
