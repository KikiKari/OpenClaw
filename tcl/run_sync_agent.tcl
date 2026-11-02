#!/usr/bin/env tclsh
# run_sync_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-02 durch ABSTRACTIONS_MANAGER.py

# Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.

# Füge Pfade zum Python-Suchpfad hinzu
lappend auto_path "/workspace/scripts"
lappend auto_path "/workspace/skills/clawhub-git-sync-agent/scripts"

# Lade das sync_agent Modul
package require sync_agent

# Setze die globalen Variablen
set WS "/workspace"
set ::sync_agent::CLAWHUB_DIR "$WS/skills"
set ::sync_agent::GIT_DIR "$WS/git/skills"
set ::sync_agent::STATE_FILE "$WS/db/sync_state.json"

# Hauptprogramm ausführen
if {![info exists ::argv0] || [string equal $::argv0 [info script]]} {
    ::sync_agent::main
}
