#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "a51eed2ac1b5ffe829746203e879978f4b0d4d35cb3a2e9f6e82f6a1d92a6c13", "source_sha256": "c76d61da97f14736857987d3dd8234160c73b0a1b52ade5aac72de04cc61e7e6", "target_language": "python"}
# check-no-conflict-markers.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-conflict-markers.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import subprocess
import os
import sys
from pathlib import Path

def is_binary_buffer(buffer):
    """Check if buffer contains binary data."""
    return b'\x00' in buffer

def find_conflict_marker_lines(content):
    """Find lines containing git conflict markers."""
    lines = content.splitlines()
    matches = []
    for index, line in enumerate(lines):
        stripped_line = line.strip()
        if (stripped_line.startswith('<<<<<<< ') or 
            stripped_line.startswith('||||||| ') or 
            stripped_line == '=======' or 
            stripped_line.startswith('>>>>>>> ')):
            matches.append(index + 1)
    return matches

def list_tracked_files(cwd=None):
    """List all tracked files in the git repository."""
    if cwd is None:
        cwd = os.getcwd()
    
    result = subprocess.run(
        ['git', 'ls-files', '-z'],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True
    )
    
    # Split by null byte and filter out empty strings
    files = [f for f in result.stdout.split('\x00') if f]
    return [os.path.join(cwd, f) for f in files]

def find_conflict_markers_in_files(file_paths, read_file=None):
    """Find conflict markers in the given files."""
    if read_file is None:
        def read_file_default(path):
            with open(path, 'rb') as f:
                return f.read()
        read_file = read_file_default
    
    violations = []
    for file_path in file_paths:
        try:
            content = read_file(file_path)
        except Exception:
            continue
            
        if not isinstance(content, bytes):
            content = str(content).encode('utf-8')
            
        if is_binary_buffer(content):
            continue
            
        lines = find_conflict_marker_lines(content.decode('utf-8'))
        if lines:
            violations.append({
                'filePath': file_path,
                'lines': lines
            })
    
    return violations

def main():
    """Main function to check for conflict markers in tracked files."""
    cwd = os.getcwd()
    violations = find_conflict_markers_in_files(list_tracked_files(cwd))
    
    if not violations:
        return
    
    print("Found unresolved merge conflict markers:", file=sys.stderr)
    for violation in violations:
        relative_path = os.path.relpath(violation['filePath'], cwd) or violation['filePath']
        print(f"- {relative_path}:{','.join(map(str, violation['lines']))}", file=sys.stderr)
    
    sys.exit(1)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(error, file=sys.stderr)
        sys.exit(1)
