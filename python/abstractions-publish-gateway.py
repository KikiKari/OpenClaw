#!/usr/bin/env python3
# abstractions-publish-gateway.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-publish-gateway.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Workspace-visible wrapper for the gateway publish job.
import subprocess
import sys
import os

# Execute the gateway publish job script with all arguments passed to this script
script_path = '/home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh'
subprocess.run([script_path] + sys.argv[1:], check=True)
