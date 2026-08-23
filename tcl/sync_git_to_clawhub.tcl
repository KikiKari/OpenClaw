#!/usr/bin/env tclsh
# sync_git_to_clawhub.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Sync die aktiven Skill-Repositories zu ClawHub.

# Füge das Skriptverzeichnis zum Pfad hinzu
lappend auto_path /home/openclaw/.openclaw/workspace/scripts
package require sync_clawhub_git

# Nur aktive Skill-Repositories synchronisieren.
set git_repos [list \
    "sub-agents-utils" \
    "multi-nodes-utils" \
]

# Check if in git/
set git_path "/home/openclaw/.openclaw/workspace/git"
foreach repo $git_repos {
    if {[file exists "$git_path/$repo"]} {
        sync_clawhub_git::log "Syncing $repo from Git to ClawHub..."
        sync_clawhub_git::sync_to_clawhub $repo 0
        sync_clawhub_git::log "✅ $repo synced to ClawHub"
    }
}
