#!/usr/bin/env bash
# Refresh the codespace Perplexity session from a locally-exported cookie.
#
# Usage:
#   ./pplx-refresh.sh [cookie-file]
#
# cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
# __Secure-next-auth.session-token value (raw), or the whole Cookie header,
# or a JSON cookie export, into that file first.
#
# Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
#        -> trigger reinit -> verify authenticated.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${PERPLEXITY_CONFIG_DIR:-$HOME/.perplexity-mcp}"
PROFILE="${PERPLEXITY_PROFILE:-codespace}"
COOKIE_FILE="${1:-$HOME/pplx-cookies.txt}"

if [ ! -s "$COOKIE_FILE" ]; then
  echo "✗ Cookie file empty/missing: $COOKIE_FILE"
  echo "  Export __Secure-next-auth.session-token from your local browser"
  echo "  (DevTools → Application → Cookies → www.perplexity.ai) into that file."
  exit 1
fi

# 1. ensure the extension daemon has a usable browser (idempotent)
bash "$HERE/pplx-setup.sh"

# 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
LOCK="$CFG/daemon.lock"
[ -f "$LOCK" ] || { echo "✗ no daemon.lock at $LOCK — is the extension running?"; exit 1; }
PID="$(python3 -c "import json;print(json.load(open('$LOCK'))['pid'])")"
ps -p "$PID" -o pid= >/dev/null 2>&1 || { echo "✗ daemon pid $PID not running"; exit 1; }
PASS="$(tr '\0' '\n' < "/proc/$PID/environ" | sed -n 's/^PERPLEXITY_VAULT_PASSPHRASE=//p')"
[ -n "$PASS" ] || { echo "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env"; exit 1; }

# 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
DIST="$(find "$HOME/.npm/_npx" -type d -path '*perplexity-user-mcp/dist' 2>/dev/null | head -1 || true)"
if [ -z "$DIST" ]; then
  npx -y perplexity-user-mcp --version >/dev/null 2>&1 || true
  DIST="$(find "$HOME/.npm/_npx" -type d -path '*perplexity-user-mcp/dist' 2>/dev/null | head -1 || true)"
fi

# 4. inject
PERPLEXITY_VAULT_PASSPHRASE="$PASS" PERPLEXITY_CONFIG_DIR="$CFG" PERPLEXITY_PROFILE="$PROFILE" PPLX_DIST="$DIST" \
  node "$HERE/pplx-inject.mjs" "$COOKIE_FILE"

# 5. trigger daemon reinit
date +%s > "$CFG/profiles/$PROFILE/.reinit"
echo "→ reinit triggered, waiting for daemon..."

# 6. verify
STAT="$CFG/profiles/$PROFILE/daemon-status.json"
for i in $(seq 1 20); do
  sleep 1.5
  AUTH="$(python3 -c "import json;print(json.load(open('$STAT')).get('authenticated'))" 2>/dev/null || echo)"
  TIER="$(python3 -c "import json;print(json.load(open('$STAT')).get('tier'))" 2>/dev/null || echo)"
  if [ "$AUTH" = "True" ]; then echo "✅ authenticated — tier: $TIER"; exit 0; fi
done
echo "⚠️  not authenticated yet. Check: tail -20 $CFG/daemon.log"
exit 1
