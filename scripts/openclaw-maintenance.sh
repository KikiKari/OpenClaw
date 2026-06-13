#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_BIN="${OPENCLAW_BIN:-$HOME/.local/bin/openclaw}"

if [[ ! -x "$OPENCLAW_BIN" ]]; then
  echo "ERROR: OpenClaw binary not found: $OPENCLAW_BIN" >&2
  exit 1
fi

echo "Using OpenClaw: $("$OPENCLAW_BIN" --version)"

# === 1. Service-/Config-Drift ===
"$OPENCLAW_BIN" doctor

# === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
"$OPENCLAW_BIN" plugins registry --refresh
if [[ "${RUN_PLUGIN_UPDATE:-0}" == "1" ]]; then
  "$OPENCLAW_BIN" plugins update --all
else
  echo "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable."
fi

# === 3. Tasks ===
"$OPENCLAW_BIN" tasks maintenance --apply

# === 4. Sessions – alle Agents auf einmal ===
"$OPENCLAW_BIN" sessions cleanup --enforce --all-agents

# === 5. Memory – status/index decken alle Agents ab ===
"$OPENCLAW_BIN" memory status --deep --fix
"$OPENCLAW_BIN" memory index --force

# === 6. Memory promote – MUSS pro Agent ===
for AGENT in main knecht docs ops-hub cron; do
  "$OPENCLAW_BIN" memory promote --apply --agent "$AGENT"
done

# === 7. Secrets ===
"$OPENCLAW_BIN" secrets reload
