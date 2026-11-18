#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "d707d6a03ebb1a735a1bd6ddcd5e38ea7bd602a3cf30d94ee594a5b2ea08e755", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "shell"}
# run_sync_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.

# Füge Python-Pfade hinzu
export PYTHONPATH="/workspace/scripts:/workspace/skills/clawhub-git-sync-agent/scripts:$PYTHONPATH"

# Setze Umgebungsvariablen für sync_agent
export CLAWHUB_DIR="/workspace/skills"
export GIT_DIR="/workspace/git/skills"
export STATE_FILE="/workspace/db/sync_state.json"

# Führe sync_agent.py aus
python3 /workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py "$@"
