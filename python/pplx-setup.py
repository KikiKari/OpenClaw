#!/usr/bin/env python3
# pplx-setup.sh — portiert nach python
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys
from pathlib import Path

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.

def main():
    # Find the latest patchright directory
    ext_dirs = sorted(Path.home().glob('.vscode-remote/extensions/nskha.perplexity-vscode-*/dist/node_modules/patchright'))
    if not ext_dirs:
        print("[setup] extension patchright not found — is the Perplexity extension installed?")
        return 0
    
    extpr = str(ext_dirs[-1])
    
    # Get expected chromium path
    try:
        result = subprocess.run([
            'node', '-e', 
            f"const {{chromium}}=require('{extpr}');console.log(chromium.executablePath())"
        ], capture_output=True, text=True, check=True)
        exp = result.stdout.strip()
    except subprocess.CalledProcessError:
        exp = ""
    
    # Check if browser already exists
    if exp and os.path.exists(exp) and os.access(exp, os.X_OK):
        print(f"[setup] daemon browser already present: {exp}")
        return 0
    
    print(f"[setup] installing matching chromium for the extension daemon (expected: {exp or 'unknown'})...")
    try:
        subprocess.run(['node', f'{extpr}/cli.js', 'install', 'chromium'], check=True)
        print("[setup] done.")
    except subprocess.CalledProcessError as e:
        return e.returncode
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
