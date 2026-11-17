#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "cf45401abd5de0026aa7c08aaeaf8575bd711ddcefb4ec2305486bf655c74df9", "source_sha256": "1a472288a0369d1ab50d7682ef1fd8fb0f3252b751dcc14dceeea89b1522ec52", "target_language": "tcl"}
# ABSTRACTIONS_MANAGER.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Skill-Einstieg fuer den kanonischen Abstractions Manager.

package require fileutil

set KANONISCHER_MANAGER "/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py"

if {![file isfile $KANONISCHER_MANAGER]} {
    puts stderr "Kanonischer Abstractions Manager fehlt: $KANONISCHER_MANAGER"
    exit 1
}

# Führe das Python-Skript aus
if {[catch {exec python3 $KANONISCHER_MANAGER} result]} {
    puts stderr $result
    exit 1
}
