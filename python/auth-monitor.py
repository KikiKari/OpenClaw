#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "9425096cfe41c68a970ec93bc4e705900f7139153d8ef83c83479c6e5e2253c1", "source_sha256": "1a67bf0d8a66b56fba5df9f18c7370e48304461313b9611ab6f238f553332b50", "target_language": "python"}
# auth-monitor.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/auth-monitor.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Auth Expiry Monitor
# Run via cron or systemd timer to get proactive notifications
# before Claude Code auth expires.
#
# Suggested cron: */30 * * * * /home/admin/openclaw/scripts/auth-monitor.sh
#
# Environment variables:
#   NOTIFY_PHONE - Phone number to send OpenClaw notification (e.g., +1234567890)
#   NOTIFY_NTFY  - ntfy.sh topic for push notifications (e.g., openclaw-alerts)
#   WARN_HOURS   - Hours before expiry to warn (default: 2)

import os
import sys
import json
import subprocess
import requests
from pathlib import Path
from datetime import datetime

def main():
    script_dir = Path(__file__).parent.resolve()
    claude_creds = Path.home() / '.claude/.credentials.json'
    state_file = Path.home() / '.openclaw/auth-monitor-state'

    # Configuration
    warn_hours = int(os.environ.get('WARN_HOURS', '2'))
    notify_phone = os.environ.get('NOTIFY_PHONE', '')
    notify_ntfy = os.environ.get('NOTIFY_NTFY', '')

    # State tracking to avoid spam
    state_file.parent.mkdir(parents=True, exist_ok=True)
    try:
        last_notified = int(state_file.read_text().strip())
    except (FileNotFoundError, ValueError):
        last_notified = 0

    now = int(datetime.now().timestamp())

    # Only notify once per hour max
    min_interval = 3600

    def send_notification(message, priority='default'):
        print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {message}")

        # Check if we notified recently
        if now - last_notified < min_interval:
            print("Skipping notification (sent recently)")
            return

        # Send via OpenClaw if phone configured and auth still valid
        if notify_phone:
            # Check if we can still use openclaw
            try:
                result = subprocess.run(
                    [script_dir / 'claude-auth-status.sh', 'simple'],
                    capture_output=True,
                    text=True,
                    check=True
                )
                if 'OK' in result.stdout or 'EXPIRING' in result.stdout:
                    print(f"Sending via OpenClaw to {notify_phone}...")
                    subprocess.run(
                        ['openclaw', 'send', '--to', notify_phone, '--message', message],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
            except subprocess.CalledProcessError:
                pass

        # Send via ntfy.sh if configured
        if notify_ntfy:
            print(f"Sending via ntfy.sh to {notify_ntfy}...")
            try:
                requests.post(
                    f'https://ntfy.sh/{notify_ntfy}',
                    data=message,
                    headers={
                        'Title': 'OpenClaw Auth Alert',
                        'Priority': priority,
                        'Tags': 'warning,key'
                    },
                    timeout=10
                )
            except requests.RequestException:
                pass

        # Update state
        state_file.write_text(str(now))

    # Check auth status
    if not claude_creds.exists():
        send_notification("Claude Code credentials missing! Run: claude setup-token", "high")
        sys.exit(1)

    try:
        creds_data = json.loads(claude_creds.read_text())
        expires_at = creds_data.get('claudeAiOauth', {}).get('expiresAt', 0)
    except (json.JSONDecodeError, KeyError):
        expires_at = 0

    now_ms = now * 1000
    diff_ms = expires_at - now_ms
    hours_left = diff_ms // 3600000
    mins_left = (diff_ms % 3600000) // 60000

    if diff_ms < 0:
        send_notification("Claude Code auth EXPIRED! OpenClaw is down. Run: ssh l36 '~/openclaw/scripts/mobile-reauth.sh'", "urgent")
        sys.exit(1)
    elif hours_left < warn_hours:
        send_notification(f"Claude Code auth expires in {hours_left}h {mins_left}m. Consider re-auth soon.", "high")
        sys.exit(0)
    else:
        print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Auth OK: {hours_left}h {mins_left}m remaining")
        sys.exit(0)

if __name__ == '__main__':
    main()
