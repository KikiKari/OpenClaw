#!/data/data/com.termux/files/usr/bin/python3
# abstraction-provenance: {"artifact_sha256": "02717ed62640e4f61f9ced57b2c4311e0aa8846fa6a10c669636db591ae55c22", "source_sha256": "32acbaa2d9f84dca0c2fd8f987ab23e0153c0e63d20e7ee9c3e279058ab681c6", "target_language": "python"}
# termux-quick-auth.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-quick-auth.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import time

# Quick Auth Check - Minimal widget for Termux
# Place in ~/.shortcuts/ for Termux:Widget
#
# One-tap: shows status toast
# If expired: directly opens auth URL

SERVER = os.environ.get('OPENCLAW_SERVER', 'l36')

try:
    result = subprocess.run([
        'ssh', '-o', 'ConnectTimeout=5', SERVER,
        '$HOME/openclaw/scripts/claude-auth-status.sh simple'
    ], capture_output=True, text=True, timeout=10)
    STATUS = result.stdout.strip()
except subprocess.TimeoutExpired:
    STATUS = "Connection error"
except Exception:
    STATUS = "Connection error"

if STATUS == "OK":
    subprocess.run(['termux-toast', '-s', 'Auth OK'])
elif "EXPIRING" in STATUS:
    subprocess.run(['termux-vibrate', '-d', '100'])
    subprocess.run(['termux-toast', 'Auth expiring soon - tap again if needed'])
elif "EXPIRED" in STATUS or "MISSING" in STATUS:
    subprocess.run(['termux-vibrate', '-d', '200'])
    subprocess.run(['termux-toast', 'Auth expired - opening console...'])
    subprocess.run(['termux-open-url', 'https://console.anthropic.com/settings/api-keys'])
    time.sleep(2)
    subprocess.run([
        'termux-notification', '-t', 'OpenClaw Re-Auth', '-c',
        f'After getting key, run: ssh {SERVER} \'~/openclaw/scripts/mobile-reauth.sh\'',
        '--id', 'openclaw-auth'
    ])
else:
    subprocess.run(['termux-toast', 'Connection error'])
