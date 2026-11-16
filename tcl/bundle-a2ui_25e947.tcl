#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "5e7ff4af85de1bb723db8d01dfaede066eae3edcfe1fa428237ac9d88002a6c0", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "tcl"}
# bundle-a2ui.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Bestimme das Stammverzeichnis relativ zum Skriptverzeichnis
set scriptDir [file dirname [file normalize $argv0]]
set rootDir [file normalize [file join $scriptDir ..]]

# Führe das Node.js-Skript mit allen Argumenten aus
set nodeScript [file join $rootDir scripts bundle-a2ui.mjs]
exec node $nodeScript {*}$argv
