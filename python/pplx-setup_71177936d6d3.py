#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "18ac5c8a0783205db8ecc84c155245b4ef28d7aaddf8fa51a9eeef7e315ef5f8", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "python"}
# pplx-setup.sh — portiert nach python
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys
from pathlib import Path

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.

def main():
    # Find the extension's patchright directory
    extpr = None
    vscode_remote_extensions = Path.home() / '.vscode-remote' / 'extensions'
    
    if vscode_remote_extensions.exists():
        patchright_dirs = list(vscode_remote_extensions.glob('nskha.perplexity-vscode-*/dist/node_modules/patchright'))
        if patchright_dirs:
            # Sort by version and get the latest
            patchright_dirs.sort(key=lambda x: x.parent.parent.name)
            extpr = str(patchright_dirs[-1])

    if not extpr:
        print("[setup] extension patchright not found — is the Perplexity extension installed?")
        return 0

    # Try to get the expected chromium path
    exp = None
    try:
        result = subprocess.run(
            ['node', '-e', f"const {{chromium}}=require('{extpr}');console.log(chromium.executablePath())"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            exp = result.stdout.strip()
    except Exception:
        pass

    # Check if the executable already exists
    if exp and os.path.isfile(exp) and os.access(exp, os.X_OK):
        print(f"[setup] daemon browser already present: {exp}")
        return 0

    # Install the matching chromium
    print(f"[setup] installing matching chromium for the extension daemon (expected: {exp or 'unknown'})...")
    try:
        subprocess.run(['node', f'{extpr}/cli.js', 'install', 'chromium'], check=True)
        print("[setup] done.")
    except subprocess.CalledProcessError:
        return 1

    return 0

if __name__ == '__main__':
    sys.exit(main())
