#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "b7c3df39cbef2883ca2cf719953f0f02428118bb65beae7a01e662ef3d262947", "source_sha256": "1a472288a0369d1ab50d7682ef1fd8fb0f3252b751dcc14dceeea89b1522ec52", "target_language": "perl6"}
# ABSTRACTIONS_MANAGER.py — portiert nach perl6
# Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Skill-Einstieg fuer den kanonischen Abstractions Manager.

use v6;

# Konstante fuer den Pfad zum kanonischen Manager
my $KANONISCHER_MANAGER = "/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py";

# Hauptprogramm
sub MAIN() {
    # Pruefe ob die Datei existiert
    unless $KANONISCHER_MANAGER.IO.f {
        die "Kanonischer Abstractions Manager fehlt: $KANONISCHER_MANAGER";
    }
    
    # Fuehre das Python-Skript aus
    run("python3", $KANONISCHER_MANAGER);
}
