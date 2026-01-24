#!/usr/bin/env python3
"""
Automated Testing and Bug Fixing Loop
Continuously tests the application and attempts to fix detected bugs
"""

import requests
import time
import json
import subprocess
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import traceback

# Configuration
BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
TEST_INTERVAL = int(os.getenv("TEST_INTERVAL", "30"))  # seconds
MAX_FIX_ATTEMPTS = 3
LOG_FILE = "auto_test_fix.log"
RESULTS_FILE = "test_results.json"

# Test results storage
test_results = {
    "start_time": datetime.now().isoformat(),
    "tests_run": 0,
    "tests_passed": 0,
    "tests_failed": 0,
    "bugs_fixed": 0,
    "errors": [],
    "fix_attempts": []
}

def log(message: str, level: str = "INFO"):
    """Log message to console and file"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_msg = f"[{timestamp}] [{level}] {message}"
    print(log_msg)
    with open(LOG_FILE, "a") as f:
        f.write(log_msg + "\n")

def save_results():
    """Save test results to JSON file"""
    test_results["end_time"] = datetime.now().isoformat()
    with open(RESULTS_FILE, "w") as f:
        json.dump(test_results, f, indent=2)

class BugFixer:
    """Handles bug detection and fixing"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.project_root = Path(__file__).parent.parent
        
    def test_endpoint(self, path: str, method: str = "GET", data: Optional[Dict] = None, 
                     files: Optional[Dict] = None, expected_status: int = 200) -> Tuple[bool, Dict]:
        """Test an endpoint and return (success, response_data)"""
        try:
            url = f"{self.base_url}{path}"
            if method == "GET":
                response = requests.get(url, timeout=10)
            elif method == "POST":
                if files:
                    response = requests.post(url, files=files, data=data, timeout=60)
                else:
                    response = requests.post(url, json=data, timeout=10)
            else:
                return False, {"error": f"Unsupported method: {method}"}
            
            success = response.status_code == expected_status
            try:
                response_data = response.json()
            except:
                response_data = {"text": response.text[:500]}
            
            return success, {
                "status_code": response.status_code,
                "data": response_data,
                "success": success
            }
        except requests.exceptions.RequestException as e:
            return False, {"error": str(e), "type": type(e).__name__}
        except Exception as e:
            return False, {"error": str(e), "type": type(e).__name__, "traceback": traceback.format_exc()}
    
    def detect_bugs(self) -> List[Dict]:
        """Run all tests and detect bugs"""
        bugs = []
        
        log("🔍 Starting bug detection cycle...")
        
        # Test 1: Root endpoint
        log("Testing root endpoint (/)...")
        success, result = self.test_endpoint("/")
        if not success:
            bugs.append({
                "type": "root_endpoint_failed",
                "severity": "high",
                "description": f"Root endpoint failed: {result}",
                "result": result
            })
        else:
            log("✅ Root endpoint OK")
        
        # Test 2: Health endpoint
        log("Testing /health endpoint...")
        success, result = self.test_endpoint("/health")
        if not success:
            bugs.append({
                "type": "health_check_failed",
                "severity": "critical",
                "description": f"Health check failed: {result}",
                "result": result
            })
        else:
            log("✅ Health endpoint OK")
        
        # Test 3: API health endpoint
        log("Testing /api/v1/health endpoint...")
        success, result = self.test_endpoint("/api/v1/health")
        if not success:
            bugs.append({
                "type": "api_health_failed",
                "severity": "critical",
                "description": f"API health check failed: {result}",
                "result": result
            })
        else:
            log("✅ API health endpoint OK")
        
        # Test 4: Debug routes endpoint
        log("Testing /api/v1/debug/routes endpoint...")
        success, result = self.test_endpoint("/api/v1/debug/routes")
        if not success:
            bugs.append({
                "type": "debug_routes_failed",
                "severity": "medium",
                "description": f"Debug routes endpoint failed: {result}",
                "result": result
            })
        else:
            log("✅ Debug routes endpoint OK")
            # Check if upload endpoint is registered
            if success and "data" in result and isinstance(result["data"], dict):
                routes = result["data"].get("routes", [])
                upload_route = any("/api/v1/analysis/upload" in str(r) for r in routes)
                if not upload_route:
                    bugs.append({
                        "type": "upload_endpoint_missing",
                        "severity": "critical",
                        "description": "Upload endpoint not found in registered routes",
                        "result": {"routes": routes}
                    })
                else:
                    log("✅ Upload endpoint registered")
        
        # Test 5: List analyses endpoint
        log("Testing /api/v1/analysis/list endpoint...")
        success, result = self.test_endpoint("/api/v1/analysis/list")
        if not success:
            bugs.append({
                "type": "list_analyses_failed",
                "severity": "medium",
                "description": f"List analyses endpoint failed: {result}",
                "result": result
            })
        else:
            log("✅ List analyses endpoint OK")
        
        # Test 6: Check for syntax errors in Python files
        log("Checking for Python syntax errors...")
        syntax_errors = self.check_python_syntax()
        if syntax_errors:
            bugs.append({
                "type": "python_syntax_error",
                "severity": "critical",
                "description": "Python syntax errors detected",
                "result": {"errors": syntax_errors}
            })
        else:
            log("✅ No Python syntax errors")
        
        # Test 7: Check backend file structure
        log("Checking backend file structure...")
        structure_issues = self.check_file_structure()
        if structure_issues:
            bugs.append({
                "type": "file_structure_issue",
                "severity": "medium",
                "description": "Backend file structure issues detected",
                "result": {"issues": structure_issues}
            })
        else:
            log("✅ Backend file structure OK")
        
        return bugs
    
    def check_python_syntax(self) -> List[str]:
        """Check for Python syntax errors in backend files"""
        errors = []
        backend_dir = self.project_root / "backend"
        
        if not backend_dir.exists():
            return ["Backend directory not found"]
        
        # Check main files
        important_files = [
            "main_integrated.py",
            "app/api/v1/analysis_azure.py",
            "app/core/database_azure_sql.py",
            "app/services/gait_analysis.py"
        ]
        
        for file_path in important_files:
            full_path = backend_dir / file_path
            if full_path.exists():
                try:
                    result = subprocess.run(
                        [sys.executable, "-m", "py_compile", str(full_path)],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    if result.returncode != 0:
                        errors.append(f"{file_path}: {result.stderr}")
                except Exception as e:
                    errors.append(f"{file_path}: {str(e)}")
        
        return errors
    
    def check_file_structure(self) -> List[str]:
        """Check if required files exist"""
        issues = []
        backend_dir = self.project_root / "backend"
        
        required_files = [
            "main_integrated.py",
            "app/api/v1/analysis_azure.py",
            "app/core/database_azure_sql.py",
            "requirements.txt"
        ]
        
        for file_path in required_files:
            full_path = backend_dir / file_path
            if not full_path.exists():
                issues.append(f"Missing file: {file_path}")
        
        return issues
    
    def fix_bug(self, bug: Dict) -> Tuple[bool, str]:
        """Attempt to fix a detected bug"""
        bug_type = bug.get("type")
        log(f"🔧 Attempting to fix bug: {bug_type}")
        
        try:
            if bug_type == "python_syntax_error":
                return self.fix_syntax_errors(bug)
            elif bug_type == "upload_endpoint_missing":
                return self.fix_missing_upload_endpoint(bug)
            elif bug_type == "file_structure_issue":
                return self.fix_file_structure(bug)
            elif bug_type in ["health_check_failed", "api_health_failed", "root_endpoint_failed"]:
                return self.fix_application_startup(bug)
            else:
                return False, f"No fix available for bug type: {bug_type}"
        except Exception as e:
            return False, f"Error during fix attempt: {str(e)}"
    
    def fix_syntax_errors(self, bug: Dict) -> Tuple[bool, str]:
        """Attempt to fix Python syntax errors"""
        errors = bug.get("result", {}).get("errors", [])
        if not errors:
            return False, "No specific syntax errors to fix"
        
        log(f"Found {len(errors)} syntax error(s)")
        # For now, just report - actual fixing would require parsing and fixing code
        # This is a placeholder for future enhancement
        return False, "Syntax errors detected - manual fix required (auto-fix not implemented)"
    
    def fix_missing_upload_endpoint(self, bug: Dict) -> Tuple[bool, str]:
        """Attempt to fix missing upload endpoint"""
        log("Checking upload endpoint registration...")
        
        # Check if the route file exists
        route_file = self.project_root / "backend" / "app" / "api" / "v1" / "analysis_azure.py"
        if not route_file.exists():
            return False, "Upload route file not found"
        
        # Check main_integrated.py for router inclusion
        main_file = self.project_root / "backend" / "main_integrated.py"
        if not main_file.exists():
            return False, "main_integrated.py not found"
        
        try:
            with open(main_file, "r") as f:
                content = f.read()
            
            # Check if router is included
            if "analysis_azure" in content and "include_router" in content:
                log("Router appears to be included in main file")
                # The issue might be runtime - suggest restart
                return False, "Router appears registered in code - may need application restart"
            else:
                return False, "Router not found in main file - code fix required"
        except Exception as e:
            return False, f"Error checking main file: {str(e)}"
    
    def fix_file_structure(self, bug: Dict) -> Tuple[bool, str]:
        """Attempt to fix file structure issues"""
        issues = bug.get("result", {}).get("issues", [])
        if not issues:
            return True, "No file structure issues"
        
        log(f"Found {len(issues)} file structure issue(s)")
        # Most file structure issues require manual intervention
        return False, f"File structure issues detected: {', '.join(issues)}"
    
    def fix_application_startup(self, bug: Dict) -> Tuple[bool, str]:
        """Attempt to fix application startup issues"""
        log("Application appears to be down or not responding")
        
        # Check if it's a local development environment
        if "localhost" in self.base_url or "127.0.0.1" in self.base_url:
            log("Local environment detected - checking if server is running")
            # Could attempt to start the server, but that's risky
            return False, "Application not responding - may need manual restart"
        else:
            # Production environment - can't restart directly
            return False, "Application not responding - may need deployment restart"
    
    def run_test_cycle(self) -> Dict:
        """Run a complete test cycle"""
        log("=" * 60)
        log("Starting new test cycle")
        log("=" * 60)
        
        test_results["tests_run"] += 1
        
        # Detect bugs
        bugs = self.detect_bugs()
        
        if not bugs:
            log("✅ All tests passed - no bugs detected!")
            test_results["tests_passed"] += 1
            return {
                "success": True,
                "bugs_found": 0,
                "bugs_fixed": 0
            }
        
        log(f"❌ Found {len(bugs)} bug(s)")
        test_results["tests_failed"] += 1
        
        # Attempt to fix bugs
        bugs_fixed = 0
        for bug in bugs:
            log(f"\n🐛 Bug detected: {bug['type']} (severity: {bug['severity']})")
            log(f"   Description: {bug['description']}")
            
            # Attempt fix
            for attempt in range(MAX_FIX_ATTEMPTS):
                fixed, message = self.fix_bug(bug)
                log(f"   Fix attempt {attempt + 1}/{MAX_FIX_ATTEMPTS}: {message}")
                
                if fixed:
                    bugs_fixed += 1
                    test_results["bugs_fixed"] += 1
                    log(f"   ✅ Bug fixed!")
                    break
                elif attempt < MAX_FIX_ATTEMPTS - 1:
                    time.sleep(2)  # Wait before retry
            
            if not fixed:
                test_results["errors"].append({
                    "time": datetime.now().isoformat(),
                    "bug": bug,
                    "fix_attempts": MAX_FIX_ATTEMPTS
                })
        
        return {
            "success": bugs_fixed == len(bugs),
            "bugs_found": len(bugs),
            "bugs_fixed": bugs_fixed,
            "bugs": bugs
        }

def main():
    """Main testing loop"""
    log("🚀 Starting Automated Testing and Bug Fixing Loop")
    log(f"Base URL: {BASE_URL}")
    log(f"Test Interval: {TEST_INTERVAL} seconds")
    log(f"Max Fix Attempts: {MAX_FIX_ATTEMPTS}")
    log("=" * 60)
    
    fixer = BugFixer(BASE_URL)
    
    try:
        cycle_count = 0
        while True:
            cycle_count += 1
            log(f"\n🔄 Test Cycle #{cycle_count}")
            
            result = fixer.run_test_cycle()
            
            test_results["fix_attempts"].append({
                "cycle": cycle_count,
                "time": datetime.now().isoformat(),
                "result": result
            })
            
            save_results()
            
            if result["success"]:
                log(f"✅ Cycle #{cycle_count} completed successfully")
            else:
                log(f"⚠️ Cycle #{cycle_count} found {result['bugs_found']} bug(s), fixed {result['bugs_fixed']}")
            
            log(f"⏳ Waiting {TEST_INTERVAL} seconds before next cycle...")
            time.sleep(TEST_INTERVAL)
            
    except KeyboardInterrupt:
        log("\n🛑 Testing loop stopped by user")
    except Exception as e:
        log(f"❌ Fatal error in testing loop: {str(e)}")
        log(traceback.format_exc())
    finally:
        save_results()
        log("📊 Test results saved")
        log(f"Total tests: {test_results['tests_run']}")
        log(f"Passed: {test_results['tests_passed']}")
        log(f"Failed: {test_results['tests_failed']}")
        log(f"Bugs fixed: {test_results['bugs_fixed']}")

if __name__ == "__main__":
    main()
