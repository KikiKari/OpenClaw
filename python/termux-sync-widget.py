#!/data/data/com.termux/files/usr/bin/python3
# abstraction-provenance: {"artifact_sha256": "24050d305a508683c14075fb56b14b24b96377f2ceb00da4e477f8b95a1a132d", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "python"}
# termux-sync-widget.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# OpenClaw OAuth Sync Widget
# Syncs Claude Code tokens to OpenClaw on l36 server
# Place in ~/.shortcuts/ on phone for Termux:Widget

import os
import subprocess
import sys

def run_command(command):
    """Run a shell command and return (exit_code, stdout, stderr)"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.returncode, result.stdout, result.stderr
    except Exception as e:
        return -1, "", str(e)

def termux_toast(message):
    """Show a toast message using termux-api"""
    run_command(f'termux-toast "{message}"')

def termux_vibrate(duration):
    """Vibrate the device using termux-api"""
    run_command(f'termux-vibrate -d {duration}')

def main():
    termux_toast("Syncing OpenClaw auth...")

    # Run sync on l36 server
    server = os.environ.get('OPENCLAW_SERVER', 'l36')
    command = f'ssh {server} \'/home/admin/openclaw/scripts/sync-claude-code-auth.sh\''
    exit_code, stdout, stderr = run_command(command)
    result = stdout if stdout else stderr

    if exit_code == 0:
        # Extract expiry time from output
        expiry = ""
        for line in result.split('\n'):
            if "Token expires:" in line:
                expiry = line.split(":", 1)[1] if ":" in line else ""
                break

        termux_vibrate(100)
        termux_toast(f"OpenClaw synced! Expires:{expiry}")

        # Optional: restart openclaw service
        run_command(f'ssh {server} \'systemctl --user restart openclaw\'')
    else:
        termux_vibrate(300)
        termux_toast(f"Sync failed: {result}")

if __name__ == "__main__":
    main()
