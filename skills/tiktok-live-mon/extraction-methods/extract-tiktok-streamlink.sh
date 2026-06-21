#!/usr/bin/env bash
# LEGACY COPY: background reference only. Use the active fallback under
# /.openclaw/workspace/skills/tiktok-live-mon/scripts/extraction-methods/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../scripts/extraction-methods/extract-tiktok-streamlink.sh" "$@"
