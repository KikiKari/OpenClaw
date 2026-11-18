#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "50e5fe31d741498245d91ae175d1ad40f05cafbefd04d4ed517486fc45eaca6b", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "tcl"}
# run_sync_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.

# Füge Pfade zum auto_path hinzu (Tcl-Entsprechung zu sys.path)
lappend auto_path "/workspace/scripts"
lappend auto_path "/workspace/skills/clawhub-git-sync-agent/scripts"

# Lade das sync_agent Modul (in Tcl wird dies typischerweise durch sourcing realisiert)
# Wir nehmen an, dass sync_agent.tcl im entsprechenden Pfad liegt
if {[file exists "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.tcl"]} {
    source "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.tcl"
} elseif {[file exists "/workspace/scripts/sync_agent.tcl"]} {
    source "/workspace/scripts/sync_agent.tcl"
} else {
    puts stderr "Fehler: sync_agent.tcl nicht gefunden"
    exit 1
}

# Setze die Konstanten (in Tcl verwenden wir globale Variablen)
set WS "/workspace"
set ::CLAWHUB_DIR [file join $WS "skills"]
set ::GIT_DIR [file join $WS "git" "skills"]
set ::STATE_FILE [file join $WS "db" "sync_state.json"]

# Hauptprogramm ausführen
if {[info exists argv0] && [string equal $argv0 [info script]]} {
    main
}
