#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "951643090b64def8fea334942b64dd3ef9c28b709b0e87280f85d8829ea3f7e4", "source_sha256": "8537e4253cc6ca148bc7b8cee5f458bfd0843576263cad8e98ca2c46fa47f2f1", "target_language": "python"}
# build-stamp.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-stamp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import subprocess
import json
import os
import sys
from pathlib import Path


def resolve_git_head(cwd=None, spawn_sync=None):
    """
    Resolve the current git HEAD commit hash.
    
    Args:
        cwd: Current working directory (default: current directory)
        spawn_sync: Function to use for spawning git command (default: subprocess.run)
    
    Returns:
        str or None: The git HEAD commit hash or None if not available
    """
    if cwd is None:
        cwd = os.getcwd()
    
    if spawn_sync is None:
        spawn_sync = subprocess.run
    
    try:
        result = spawn_sync(
            ["git", "rev-parse", "HEAD"],
            cwd=cwd,
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            return None
            
        head = result.stdout.strip()
        return head if head else None
    except Exception:
        return None


def write_build_stamp(cwd=None, fs_impl=None, now_func=None, spawn_sync=None):
    """
    Write a build timestamp file with git HEAD information.
    
    Args:
        cwd: Current working directory (default: current directory)
        fs_impl: File system implementation (unused in Python version)
        now_func: Function that returns current timestamp (default: lambda: int(time.time() * 1000))
        spawn_sync: Function to use for spawning git command (default: subprocess.run)
    
    Returns:
        str: Path to the created build stamp file
    """
    if cwd is None:
        cwd = os.getcwd()
    
    if now_func is None:
        import time
        now_func = lambda: int(time.time() * 1000)
    
    dist_root = Path(cwd) / "dist"
    build_stamp_path = dist_root / ".buildstamp"
    head = resolve_git_head(cwd=cwd, spawn_sync=spawn_sync)
    
    dist_root.mkdir(parents=True, exist_ok=True)
    
    with open(build_stamp_path, "w", encoding="utf-8") as f:
        f.write(f"{json.dumps({'builtAt': now_func(), 'head': head})}\n")
    
    return str(build_stamp_path)


if __name__ == "__main__":
    try:
        write_build_stamp()
    except Exception as error:
        print(error, file=sys.stderr)
        sys.exit(1)
