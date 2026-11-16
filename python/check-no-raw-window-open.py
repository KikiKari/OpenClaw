#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "106bc606c0d2ff4b7a1775f91dda8276199ae5a55e26561f9c6a80640bbac7cf", "source_sha256": "b77d7ac77e305afea60b0aa9579426471649732bc9d7cb3bce3f14575d0d0bb6", "target_language": "python"}
# check-no-raw-window-open.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-window-open.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import asyncio
from pathlib import Path
from typing import List, Set

# Since we don't have TypeScript parsing capabilities in Python by default,
# we'll implement a simple regex-based approach to detect raw window.open calls.
# This is not as robust as the AST-based approach but should work for most cases.

import re

def resolve_repo_root(script_path: str) -> str:
    """Resolve repository root based on script path"""
    script_dir = Path(script_path).parent
    # Walk up the directory tree to find repository root
    current = script_dir
    while current != current.parent:
        if (current / '.git').exists():
            return str(current)
        current = current.parent
    return str(script_dir)

def collect_typescript_files(directory: str, extra_test_suffixes: List[str] = None, 
                            ignore_missing: bool = True) -> List[str]:
    """Collect all TypeScript files in directory"""
    if extra_test_suffixes is None:
        extra_test_suffixes = []
    
    files = []
    try:
        path_obj = Path(directory)
        if not path_obj.exists():
            if not ignore_missing:
                raise FileNotFoundError(f"Directory not found: {directory}")
            return []
        
        # Collect .ts and .tsx files
        for suffix in ['*.ts', '*.tsx']:
            files.extend(path_obj.rglob(suffix))
            
        # Filter out test files unless they match extra suffixes
        filtered_files = []
        for f in files:
            str_f = str(f)
            is_test_file = '.test.' in str_f or '.spec.' in str_f
            if not is_test_file or any(str_f.endswith(suffix) for suffix in extra_test_suffixes):
                filtered_files.append(str(f))
                
        return sorted(filtered_files)
    except Exception as e:
        if not ignore_missing:
            raise
        return []

def unwrap_expression(expr: str) -> str:
    """Remove parentheses and other wrapping constructs"""
    expr = expr.strip()
    while expr.startswith('(') and expr.endswith(')'):
        expr = expr[1:-1].strip()
    return expr

def is_raw_window_open_call(call_expr: str) -> bool:
    """Check if this looks like a raw window.open call"""
    # Remove whitespace for easier matching
    call_expr = re.sub(r'\s+', '', call_expr)
    
    # Match patterns like window.open, globalThis.open
    patterns = [
        r'^window\.open\b',
        r'^globalThis\.open\b',
        r'^\(window\)\.open\b',
        r'^\(globalThis\)\.open\b'
    ]
    
    for pattern in patterns:
        if re.match(pattern, call_expr):
            return True
            
    return False

def to_line(content: str, offset: int) -> int:
    """Convert character offset to line number"""
    return content[:offset].count('\n') + 1

def find_raw_window_open_lines(content: str, file_name: str = "source.ts") -> List[int]:
    """Find lines with raw window.open calls"""
    lines = []
    
    # Find all potential call expressions that might be window.open
    # This is a simplified approach - looking for patterns like identifier.open(
    # We're looking for calls that look like window.open( or globalThis.open(
    
    # More comprehensive pattern matching
    # Look for: window.open(...), globalThis.open(...), etc.
    pattern = r'(?:(?:window|globalThis)(?:\.\w+)*)\.open\s*\('
    
    for match in re.finditer(pattern, content):
        # Check if it's actually a raw window.open call
        full_match = match.group(0)
        # Extract the part before .open
        prefix = content[match.start():match.start()+match.group(0).find('.open')]
        if is_raw_window_open_call(prefix + '.open'):
            line_number = to_line(content, match.start())
            lines.append(line_number)
    
    # Also check for more complex expressions that might wrap window
    complex_pattern = r'(?:\(\s*(?:window|globalThis)\s*\)|window|globalThis)\.open\s*\('
    for match in re.finditer(complex_pattern, content):
        line_number = to_line(content, match.start())
        if line_number not in lines:  # Avoid duplicates
            lines.append(line_number)
            
    return sorted(lines)

async def main():
    """Main execution function"""
    # Get paths
    script_path = __file__
    repo_root = resolve_repo_root(script_path)
    ui_source_dir = os.path.join(repo_root, "ui", "src", "ui")
    
    # Define allowed callsites
    allowed_callsites = {os.path.join(ui_source_dir, "open-external-url.ts")}
    
    # Collect files
    files = collect_typescript_files(ui_source_dir, 
                                    extra_test_suffixes=[".browser.test.ts", ".node.test.ts"],
                                    ignore_missing=True)
    
    violations = []
    
    for file_path in files:
        if file_path in allowed_callsites:
            continue
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            lines = find_raw_window_open_lines(content, file_path)
            for line in lines:
                rel_path = os.path.relpath(file_path, repo_root)
                violations.append(f"{rel_path}:{line}")
        except Exception as e:
            print(f"Warning: Could not read {file_path}: {e}", file=sys.stderr)
    
    if len(violations) == 0:
        return
    
    print("Found raw window.open usage outside safe helper:", file=sys.stderr)
    for violation in violations:
        print(f"- {violation}", file=sys.stderr)
    print("Use openExternalUrlSafe(...) from ui/src/ui/open-external-url.ts instead.", file=sys.stderr)
    sys.exit(1)

def run_as_script(script_path: str, main_func):
    """Run main function if this script is executed directly"""
    if __name__ == "__main__":
        asyncio.run(main_func())

# Run the script
if __name__ == "__main__":
    asyncio.run(main())
