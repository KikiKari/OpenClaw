#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "d8d603c354e1914bc41387849aa99dc9b5dcbcb0f8d4802bae5b121c653f54c0", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "python"}
# pplx-status.sh — portiert nach python
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Quick status of the codespace Perplexity daemon session.
import os
import sys
import json
import subprocess

CFG = os.environ.get('PERPLEXITY_CONFIG_DIR', os.path.expanduser('~/.perplexity-mcp'))
PROFILE = os.environ.get('PERPLEXITY_PROFILE', 'codespace')
STAT = os.path.join(CFG, 'profiles', PROFILE, 'daemon-status.json')

if os.path.isfile(STAT):
    with open(STAT, 'r') as f:
        data = json.load(f)
    print(json.dumps(data, indent=2))
else:
    print(f"no daemon-status.json at {STAT}")

print("--- recent auth lines ---")
try:
    result = subprocess.run(['grep', '-iE', 'Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in', 
                             os.path.join(CFG, 'daemon.log')], 
                           capture_output=True, text=True, timeout=10)
    if result.returncode in [0, 1]:  # grep returns 1 when no matches found, which is ok
        lines = result.stdout.strip().split('\n') if result.stdout else []
        # Print last 6 lines, or all lines if fewer than 6
        for line in lines[-6:] if len(lines) > 6 else lines:
            print(line)
except (subprocess.TimeoutExpired, FileNotFoundError):
    pass
except Exception:
    pass
