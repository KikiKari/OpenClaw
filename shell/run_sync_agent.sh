#!/bin/bash
# run_sync_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-02 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sandbox-Wrapper fuer sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.

# Aendere das Python-Suchverzeichnis (sys.path)
export PYTHONPATH="/workspace/scripts:/workspace/skills/clawhub-git-sync-agent/scripts:$PYTHONPATH"

# Setze die entspr. Variablen in der sync_agent-Umgebung
CLAWHUB_DIR="/workspace/skills"
GIT_DIR="/workspace/git/skills"
STATE_FILE="/workspace/db/sync_state.json"

# Fuehre das Python-Skript mit den modifizierten Umgebungsvariablen aus
exec env CLAWHUB_DIR="$CLAWHUB_DIR" GIT_DIR="$GIT_DIR" STATE_FILE="$STATE_FILE" \
     python3 -c "
import sys
sys.path.insert(0, '/workspace/scripts')
sys.path.insert(0, '/workspace/skills/clawhub-git-sync-agent/scripts')
import sync_agent
sync_agent.CLAWHUB_DIR = '$CLAWHUB_DIR'
sync_agent.GIT_DIR = '$GIT_DIR'
sync_agent.STATE_FILE = '$STATE_FILE'
sync_agent.main()
" "$@"
