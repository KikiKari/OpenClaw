#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "c33373476a961795c112880dcc91e951f94c77e5fb1cdd714f6aae3ad6066844", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "python"}
# generated-output-utils.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import sys
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import url2pathname

def write_text_file_if_changed(file_path, content):
    """Write text file if content has changed"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            current = f.read()
    except FileNotFoundError:
        current = None
    
    if current != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def read_if_exists(file_path):
    """Read file content if exists, otherwise return None"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        return None

def write_generated_output(params):
    """Write generated output file"""
    output_path = os.path.abspath(os.path.join(params['repo_root'], params['output_path']))
    current = read_if_exists(output_path)
    changed = current != params['next']
    
    if params.get('check', False):
        return {
            'changed': changed,
            'wrote': False,
            'output_path': output_path,
        }
    
    wrote = write_text_file_if_changed(output_path, params['next']) if changed else False
    return {
        'changed': changed,
        'wrote': wrote,
        'output_path': output_path,
    }

def report_generated_output_cli(params):
    """Report generated output via CLI"""
    # Convert import_meta_url to file path for comparison
    if params['import_meta_url'] != f"file://{os.path.abspath(sys.argv[0])}":
        return
    
    check = '--check' in sys.argv
    result = params['run']({'check': check})
    
    if not result['changed']:
        return
    
    relative_output_path = os.path.relpath(result['output_path'], os.getcwd())
    
    if check:
        print(f"[{params['label']}] stale generated output at {relative_output_path}", file=sys.stderr)
        sys.exit(1)
        return
    
    print(f"[{params['label']}] wrote {relative_output_path}")
