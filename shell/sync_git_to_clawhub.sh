#!/usr/bin/env bash
# sync_git_to_clawhub.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sync die aktiven Skill-Repositories zu ClawHub.

# Füge das Skript-Verzeichnis zum Pfad hinzu
SCRIPT_DIR="/home/openclaw/.openclaw/workspace/scripts"
PATH="$SCRIPT_DIR:$PATH"

# Nur aktive Skill-Repositories synchronisieren.
git_repos=("sub-agents-utils" "multi-nodes-utils")

# Check if in git/
git_path="/home/openclaw/.openclaw/workspace/git"
for repo in "${git_repos[@]}"; do
    if [[ -d "$git_path/$repo" ]]; then
        echo "Syncing $repo from Git to ClawHub..."
        sync_clawhub_git.sh "$repo" false
        echo "✅ $repo synced to ClawHub"
    fi
done
