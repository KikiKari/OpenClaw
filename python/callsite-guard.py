#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "a9a7f756768d5be92b8c27892d7491cf5dba83bc6e569c897bc73c86f05f43de", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "python"}
# callsite-guard.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import asyncio
import os
from pathlib import Path
from typing import List, Optional, Callable, Any

# Importiere benötigte Funktionen aus ts_guard_utils.py
# (entsprechend der JavaScript-Version)
from ts_guard_utils import (
    collect_typescript_files_from_roots,
    resolve_repo_root,
    resolve_source_roots
)

async def run_callsite_guard(params: dict) -> None:
    """
    Hauptfunktion für den Callsite-Guard.
    
    Args:
        params: Dictionary mit Konfigurationsparametern
    """
    repo_root = resolve_repo_root(params['import_meta_url'])
    source_roots = resolve_source_roots(repo_root, params['source_roots'])
    
    files = await collect_typescript_files_from_roots(source_roots, {
        'extra_test_suffixes': params.get('extra_test_suffixes', [])
    })
    
    violations: List[str] = []
    
    for file_path in files:
        rel_path = os.path.relpath(file_path, repo_root).replace(os.sep, "/")
        
        skip_relative_path_func = params.get('skip_relative_path')
        if skip_relative_path_func and skip_relative_path_func(rel_path):
            continue
            
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        find_call_lines_func = params['find_call_lines']
        for line in find_call_lines_func(content, file_path):
            callsite = f"{rel_path}:{line}"
            
            allow_callsite_func = params.get('allow_callsite')
            if allow_callsite_func and allow_callsite_func(callsite):
                continue
                
            violations.append(callsite)
    
    if len(violations) == 0:
        return
    
    print(params['header'], file=sys.stderr)
    
    sort_violations = params.get('sort_violations', True)
    output = violations if not sort_violations else sorted(violations)
    
    for violation in output:
        print(f"- {violation}", file=sys.stderr)
        
    footer = params.get('footer')
    if footer:
        print(footer, file=sys.stderr)
        
    exit(1)
