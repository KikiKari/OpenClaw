#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "2ad4f306f24990db00eef65edadba83626b83fe6dfeb2e9e441493b9b3c91219", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "python"}
# source-file-scan-cache.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import asyncio
import json
import os
from pathlib import Path
from typing import List, Dict, Set, Tuple, Any

scan_cache: Dict[str, asyncio.Future] = {}

def normalize_repo_path(repo_root: str, file_path: str) -> str:
    """Convert a file path to a normalized repository-relative path"""
    rel_path = os.path.relpath(file_path, repo_root)
    return rel_path.replace(os.sep, "/")

async def walk_files(params: Dict[str, Any], root_dir: str) -> List[str]:
    """Recursively walk directory tree and collect matching files"""
    out = []
    try:
        entries = os.scandir(root_dir)
        sorted_entries = sorted(entries, key=lambda e: e.name)
    except FileNotFoundError:
        return out
    except Exception:
        raise
    
    for entry in sorted_entries:
        entry_path = os.path.join(root_dir, entry.name)
        if entry.is_dir():
            if entry.name not in params["ignoredDirNames"]:
                sub_files = await walk_files(params, entry_path)
                out.extend(sub_files)
            continue
        if entry.is_file() and os.path.splitext(entry.name)[1] in params["scanExtensions"]:
            out.append(entry_path)
    
    return out

async def _collect_source_files_task(params: Dict[str, Any]) -> List[Dict[str, str]]:
    """Internal task to collect source files and their contents"""
    # Collect all files from all scan roots
    all_files = []
    for root in params["scanRoots"]:
        root_path = os.path.join(params["repoRoot"], root)
        files = await walk_files(params, root_path)
        all_files.extend(files)
    
    # Sort files by their normalized repository paths
    all_files.sort(key=lambda f: normalize_repo_path(params["repoRoot"], f))
    
    # Read contents of all files
    result = []
    for file_path in all_files:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        result.append({
            "filePath": file_path,
            "relativeFile": normalize_repo_path(params["repoRoot"], file_path),
            "content": content
        })
    
    return result

async def collectSourceFileContents(params: Dict[str, Any]) -> List[Dict[str, str]]:
    """Collect source file contents with caching based on parameters"""
    # Create cache key from parameters
    cache_key_data = {
        "repoRoot": params["repoRoot"],
        "scanRoots": sorted(params["scanRoots"]),
        "scanExtensions": sorted(list(params["scanExtensions"])),
        "ignoredDirNames": sorted(list(params["ignoredDirNames"]))
    }
    cache_key = json.dumps(cache_key_data, sort_keys=True)
    
    # Check if we have cached result
    if cache_key in scan_cache:
        return await scan_cache[cache_key]
    
    # Create new task and cache it
    task = asyncio.create_task(_collect_source_files_task(params))
    scan_cache[cache_key] = task
    
    try:
        result = await task
        return result
    except Exception:
        # Remove failed task from cache
        if cache_key in scan_cache:
            del scan_cache[cache_key]
        raise
