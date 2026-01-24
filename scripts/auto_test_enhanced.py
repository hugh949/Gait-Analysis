#!/usr/bin/env python3
"""
Enhanced Automated Testing and Bug Fixing Loop
With advanced bug detection and auto-fixing capabilities
"""

import requests
import time
import json
import subprocess
import sys
import os
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import traceback

# Configuration
BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
TEST_INTERVAL = int(os.getenv("TEST_INTERVAL", "30"))
MAX_FIX_ATTEMPTS = 3
LOG_FILE = "auto_test_fix.log"
RESULTS_FILE = "test_results.json"

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
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_msg = f"[{timestamp}] [{level}] {message}"
    print(log_msg)
    with open(LOG_FILE, "a") as f:
        f.write(log_msg + "\n")

def save_results():
    test_results["end_time"] = datetime.now().isoformat()
    with open(RESULTS_FILE, "w") as f:
        json.dump(test_results, f, indent=2)

class AdvancedBugFixer:
    """Advanced bug detection and fixing with code analysis"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.project_root = Path(__file__).parent.parent
        self.backend_dir = self.project_root / "backend"
        
    def test_endpoint(self, path: str, method: str = "GET", **kwargs) -> Tuple[bool, Dict]:
        """Test an endpoint"""
        try:
            url = f"{self.base_url}{path}"
            timeout = kwargs.get("timeout", 10)
            
            if method == "GET":
                response = requests.get(url, timeout=timeout)
            elif method == "POST":
                response = requests.post(url, timeout=timeout, **kwargs)
            else:
                return False, {"error": f"Unsupported method: {method}"}
            
            success = response.status_code == kwargs.get("expected_status", 200)
            try:
                response_data = response.json()
            except:
                response_data = {"text": response.text[:500]}
            
            return success, {
                "status_code": response.status_code,
                "data": response_data,
                "success": success
            }
        except Exception as e:
            return False, {"error": str(e), "type": type(e).__name__}
    
    def check_code_issues(self) -> List[Dict]:
        """Check for common code issues"""
        issues = []
        
        # Check for common Python issues in analysis_azure.py
        analysis_file = self.backend_dir / "app" / "api" / "v1" / "analysis_azure.py"
        if analysis_file.exists():
            with open(analysis_file, "r") as f:
                content = f.read()
            
            # Check for unbound local errors (import os inside function)
            if re.search(r'def\s+\w+.*:\s*\n\s*import\s+os', content, re.MULTILINE):
                issues.append({
                    "type": "unbound_local_import",
                    "file": str(analysis_file.relative_to(self.project_root)),
                    "description": "Import statement inside function can cause UnboundLocalError",
                    "fixable": True
                })
            
            # Check for unclosed try blocks
            try_count = content.count("try:")
            except_count = content.count("except")
            finally_count = content.count("finally:")
            if try_count > (except_count + finally_count):
                issues.append({
                    "type": "unclosed_try_block",
                    "file": str(analysis_file.relative_to(self.project_root)),
                    "description": f"Potential unclosed try block (try: {try_count}, except: {except_count}, finally: {finally_count})",
                    "fixable": False
                })
            
            # Check for variable scope issues
            if re.search(r'except.*:\s*\n\s*.*\b(os|threading)\b', content):
                # Check if os/threading are imported at module level
                if "import os" not in content[:500] or "import threading" not in content[:500]:
                    issues.append({
                        "type": "missing_module_import",
                        "file": str(analysis_file.relative_to(self.project_root)),
                        "description": "os or threading used in exception handler but may not be imported at module level",
                        "fixable": True
                    })
        
        return issues
    
    def fix_unbound_local_import(self, issue: Dict) -> Tuple[bool, str]:
        """Fix unbound local import issues"""
        file_path = self.project_root / issue["file"]
        if not file_path.exists():
            return False, "File not found"
        
        try:
            with open(file_path, "r") as f:
                lines = f.readlines()
            
            # Find function definitions with local imports
            fixed = False
            new_lines = []
            i = 0
            while i < len(lines):
                line = lines[i]
                
                # Check if this is a function definition
                if re.match(r'^\s*def\s+\w+', line):
                    # Look ahead for import os/threading inside function
                    func_lines = [line]
                    j = i + 1
                    indent_level = len(line) - len(line.lstrip())
                    
                    while j < len(lines):
                        next_line = lines[j]
                        next_indent = len(next_line) - len(next_line.lstrip())
                        
                        # Still in function
                        if next_indent > indent_level:
                            func_lines.append(next_line)
                            # Check for local import
                            if re.match(r'^\s+import\s+(os|threading)', next_line):
                                # Remove this line (it's a local import that should be global)
                                log(f"Removing local import: {next_line.strip()}")
                                fixed = True
                                j += 1
                                continue
                            j += 1
                        else:
                            break
                    
                    new_lines.extend(func_lines)
                    i = j
                else:
                    new_lines.append(line)
                    i += 1
            
            if fixed:
                with open(file_path, "w") as f:
                    f.writelines(new_lines)
                return True, "Removed local imports that could cause UnboundLocalError"
            else:
                return False, "No local imports found to fix"
                
        except Exception as e:
            return False, f"Error fixing file: {str(e)}"
    
    def fix_missing_module_import(self, issue: Dict) -> Tuple[bool, str]:
        """Ensure os and threading are imported at module level"""
        file_path = self.project_root / issue["file"]
        if not file_path.exists():
            return False, "File not found"
        
        try:
            with open(file_path, "r") as f:
                content = f.read()
            
            # Check what's missing
            needs_os = "import os" not in content[:1000]
            needs_threading = "import threading" not in content[:1000]
            
            if not needs_os and not needs_threading:
                return False, "All required imports already present"
            
            # Find the import section (usually at the top)
            lines = content.split("\n")
            import_end = 0
            for i, line in enumerate(lines[:50]):  # Check first 50 lines
                if line.strip().startswith("import ") or line.strip().startswith("from "):
                    import_end = i + 1
                elif line.strip() and not line.strip().startswith("#") and import_end > 0:
                    break
            
            # Add missing imports
            new_lines = lines[:import_end]
            if needs_os:
                new_lines.append("import os")
            if needs_threading:
                new_lines.append("import threading")
            new_lines.extend(lines[import_end:])
            
            with open(file_path, "w") as f:
                f.write("\n".join(new_lines))
            
            imports_added = []
            if needs_os:
                imports_added.append("os")
            if needs_threading:
                imports_added.append("threading")
            
            return True, f"Added module-level imports: {', '.join(imports_added)}"
            
        except Exception as e:
            return False, f"Error adding imports: {str(e)}"
    
    def detect_bugs(self) -> List[Dict]:
        """Detect all bugs"""
        bugs = []
        
        log("🔍 Starting comprehensive bug detection...")
        
        # Test endpoints
        endpoints = [
            ("/", "root"),
            ("/health", "health"),
            ("/api/v1/health", "api_health"),
            ("/api/v1/debug/routes", "debug_routes"),
            ("/api/v1/analysis/list", "list_analyses")
        ]
        
        for path, name in endpoints:
            log(f"Testing {name} endpoint...")
            success, result = self.test_endpoint(path)
            if not success:
                bugs.append({
                    "type": f"{name}_endpoint_failed",
                    "severity": "high" if "health" in name else "medium",
                    "description": f"{name} endpoint failed: {result}",
                    "result": result
                })
            else:
                log(f"✅ {name} endpoint OK")
        
        # Check code issues
        log("Checking for code issues...")
        code_issues = self.check_code_issues()
        bugs.extend(code_issues)
        
        # Check syntax
        log("Checking Python syntax...")
        syntax_errors = self.check_syntax()
        if syntax_errors:
            bugs.append({
                "type": "syntax_error",
                "severity": "critical",
                "description": "Python syntax errors detected",
                "result": {"errors": syntax_errors}
            })
        
        return bugs
    
    def check_syntax(self) -> List[str]:
        """Check Python syntax"""
        errors = []
        important_files = [
            "main_integrated.py",
            "app/api/v1/analysis_azure.py"
        ]
        
        for file_path in important_files:
            full_path = self.backend_dir / file_path
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
    
    def fix_bug(self, bug: Dict) -> Tuple[bool, str]:
        """Attempt to fix a bug"""
        bug_type = bug.get("type")
        log(f"🔧 Attempting to fix: {bug_type}")
        
        if bug_type == "unbound_local_import":
            return self.fix_unbound_local_import(bug)
        elif bug_type == "missing_module_import":
            return self.fix_missing_module_import(bug)
        elif bug_type == "syntax_error":
            return False, "Syntax errors require manual review"
        else:
            return False, f"No auto-fix available for {bug_type}"
    
    def run_test_cycle(self) -> Dict:
        """Run test cycle"""
        log("=" * 60)
        log("Starting test cycle")
        log("=" * 60)
        
        test_results["tests_run"] += 1
        
        bugs = self.detect_bugs()
        
        if not bugs:
            log("✅ All tests passed!")
            test_results["tests_passed"] += 1
            return {"success": True, "bugs_found": 0, "bugs_fixed": 0}
        
        log(f"❌ Found {len(bugs)} bug(s)")
        test_results["tests_failed"] += 1
        
        bugs_fixed = 0
        for bug in bugs:
            log(f"\n🐛 Bug: {bug['type']} ({bug.get('severity', 'unknown')} severity)")
            
            if bug.get("fixable", True):
                for attempt in range(MAX_FIX_ATTEMPTS):
                    fixed, message = self.fix_bug(bug)
                    log(f"   Fix attempt {attempt + 1}: {message}")
                    
                    if fixed:
                        bugs_fixed += 1
                        test_results["bugs_fixed"] += 1
                        log(f"   ✅ Fixed!")
                        break
                    time.sleep(1)
            else:
                log(f"   ⚠️  Not auto-fixable")
        
        return {
            "success": bugs_fixed == len(bugs),
            "bugs_found": len(bugs),
            "bugs_fixed": bugs_fixed
        }

def main():
    log("🚀 Enhanced Automated Testing Loop")
    log(f"Base URL: {BASE_URL}")
    log(f"Interval: {TEST_INTERVAL}s")
    
    fixer = AdvancedBugFixer(BASE_URL)
    
    try:
        cycle = 0
        while True:
            cycle += 1
            log(f"\n🔄 Cycle #{cycle}")
            
            result = fixer.run_test_cycle()
            test_results["fix_attempts"].append({
                "cycle": cycle,
                "time": datetime.now().isoformat(),
                "result": result
            })
            save_results()
            
            log(f"⏳ Waiting {TEST_INTERVAL}s...")
            time.sleep(TEST_INTERVAL)
            
    except KeyboardInterrupt:
        log("\n🛑 Stopped")
    finally:
        save_results()

if __name__ == "__main__":
    main()
