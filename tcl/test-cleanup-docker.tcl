#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "52dee7884234428d920f0bb8499a2adaf52c7d88be55b49740d4ea483eb2a718", "source_sha256": "df77fd3273a53bf6d33c1c4df50c24d9526e06de477779a9b7a58f5b8ce3ed1d", "target_language": "tcl"}
# test-cleanup-docker.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/test-cleanup-docker.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

proc main {} {
    # Bestimme das Wurzelverzeichnis
    set script_dir [file dirname [info script]]
    set root_dir [file normalize "$script_dir/../.."]
    
    # Lade die Logging-Bibliothek (wird hier inline implementiert)
    source "$root_dir/scripts/lib/docker-e2e-logs.tcl"
    
    # Setze Umgebungsvariablen mit Standardwerten
    set image_name [expr {[info exists ::env(OPENCLAW_CLEANUP_SMOKE_IMAGE)] ? $::env(OPENCLAW_CLEANUP_SMOKE_IMAGE) : "openclaw-cleanup-smoke:local"}]
    set platform [expr {[info exists ::env(OPENCLAW_CLEANUP_SMOKE_PLATFORM)] ? $::env(OPENCLAW_CLEANUP_SMOKE_PLATFORM) : "linux/amd64"}]
    
    puts "==> Build image: $image_name"
    
    # Führe den Build-Befehl mit Logging aus
    run_logged "cleanup-build" "docker" "build" \
        "-t" "$image_name" \
        "-f" "$root_dir/scripts/docker/cleanup-smoke/Dockerfile" \
        "$root_dir"
    
    puts "==> Run cleanup smoke test"
    
    # Führe den Docker-Run-Befehl aus
    exec docker run --rm --platform "$platform" -t "$image_name"
}

# Inline-Implementierung der Logging-Funktionen
proc run_logged {log_name cmd args} {
    # In einer realen Implementierung würde dies die Ausgabe loggen
    # Hier führen wir den Befehl direkt aus
    set cmdline [concat [list $cmd] $args]
    if {[catch {exec {*}$cmdline} result]} {
        puts stderr "Fehler beim Ausführen von: [join $cmdline { }]"
        puts stderr "Fehlermeldung: $result"
        exit 1
    } else {
        puts $result
    }
}

# Starte das Hauptprogramm
main
