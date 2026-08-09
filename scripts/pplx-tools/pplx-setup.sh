#!/usr/bin/env bash
# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.
set -euo pipefail

EXTPR="$(ls -d "$HOME"/.vscode-remote/extensions/nskha.perplexity-vscode-*/dist/node_modules/patchright 2>/dev/null | sort -V | tail -1 || true)"
if [ -z "$EXTPR" ]; then
  echo "[setup] extension patchright not found — is the Perplexity extension installed?"
  exit 0
fi

EXP="$(node -e "const {chromium}=require('$EXTPR');console.log(chromium.executablePath())" 2>/dev/null || true)"
if [ -n "$EXP" ] && [ -x "$EXP" ]; then
  echo "[setup] daemon browser already present: $EXP"
  exit 0
fi

echo "[setup] installing matching chromium for the extension daemon (expected: ${EXP:-unknown})..."
node "$EXTPR/cli.js" install chromium
echo "[setup] done."
