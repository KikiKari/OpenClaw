#!/bin/bash
set -euo pipefail
DURATION="${1:-300}"
UNIT_NAME="tiktok-api-window-$(date +%s)"
systemd-run --unit="$UNIT_NAME" --property=User=openclaw --description="TikTok API transient run" /usr/local/bin/tiktok-api-launch.sh &
sleep "$DURATION"
systemctl stop "$UNIT_NAME" || true
exit 0
