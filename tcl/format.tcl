#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "e4f0d963c8c0d51ee4c48a27fded5f89dafa5c6eab5376bbfdeb838f1141fdd0", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "tcl"}
# format.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require fileutil

# Bestimme das Wurzelverzeichnis relativ zum Skriptverzeichnis
set scriptDir [file dirname [file normalize $argv0]]
set rootDir [file normalize [file join $scriptDir ".."]]

# Konfigurationsdatei und Zielverzeichnis
set config "$rootDir/.swiftformat"
set sourcesDir "$rootDir/Sources"

# Prüfe, ob swiftformat verfügbar ist
if {[catch {exec which swiftformat}]} {
    puts stderr "swiftformat nicht gefunden"
    exit 1
}

# Führe swiftformat aus
if {[catch {exec swiftformat --config $config $sourcesDir} result]} {
    puts stderr "Fehler bei der Ausführung von swiftformat: $result"
    exit 1
}
