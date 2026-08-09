#!/usr/bin/env bash
# Quick status of the codespace Perplexity daemon session.
set -euo pipefail
CFG="${PERPLEXITY_CONFIG_DIR:-$HOME/.perplexity-mcp}"
PROFILE="${PERPLEXITY_PROFILE:-codespace}"
STAT="$CFG/profiles/$PROFILE/daemon-status.json"
if [ -f "$STAT" ]; then
  python3 -m json.tool "$STAT"
else
  echo "no daemon-status.json at $STAT"
fi
echo "--- recent auth lines ---"
grep -iE 'Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in' "$CFG/daemon.log" 2>/dev/null | tail -6 || true
