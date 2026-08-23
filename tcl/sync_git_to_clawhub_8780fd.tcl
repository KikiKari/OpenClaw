#!/usr/bin/env tclsh
# sync_git_to_clawhub.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Sync die 4 Git-Repos zu ClawHub

# Füge das Verzeichnis zum Tcl-Suchpfad hinzu
lappend auto_path /home/openclaw/.openclaw/workspace/scripts

# Lade das sync_clawhub_git Modul
package require sync_clawhub_git

# Die 4 Git-Repos die zu ClawHub müssen
set git_repos [list \
    "abstractions-utils" \
    "sub-agents-utils" \
    "multi-nodes-utils" \
    "Abstraktionen" \
]

# Check if in git/
set git_path "/home/openclaw/.openclaw/workspace/git"
foreach repo $git_repos {
    if {[file exists "$git_path/$repo"]} {
        puts "Syncing $repo from Git to ClawHub..."
        # Rename für sync function
        if {$repo eq "Abstraktionen"} {
            continue  ;# Skip - ist kein Skill
        }
        sync_to_clawhub $repo false
        puts "✅ $repo synced to ClawHub"
    }
}
