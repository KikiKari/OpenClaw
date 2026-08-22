#!/usr/bin/env python3
# pplx-status.sh — portiert nach python
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

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
    with open(os.path.join(CFG, 'daemon.log'), 'r') as f:
        lines = f.readlines()
    
    # Filter lines matching the grep pattern (case insensitive)
    pattern_lines = []
    for line in lines:
        if any(keyword in line.lower() for keyword in [
            'authenticated as user',
            'account tier',
            'injected',
            'cookies',
            'reinit requested',
            'not-logged-in'
        ]):
            pattern_lines.append(line.rstrip())
    
    # Print last 6 matching lines
    for line in pattern_lines[-6:]:
        print(line)
        
except FileNotFoundError:
    pass
except Exception:
    pass
