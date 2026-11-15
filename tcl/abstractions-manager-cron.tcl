#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "b0713e96d7fdddcf04764738552eab8462bf268440e7f429a3b05640ccc73043", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "tcl"}
# abstractions-manager-cron.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# Setzen der Umgebungsvariablen
set env(PATH) "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Laden der Umgebungsvariablen aus der .env Datei
if {[catch {exec /usr/bin/cat /home/openclaw/.openclaw/.env} env_data]} {
    puts stderr "Fehler beim Lesen der .env Datei"
    exit 1
}

# Verarbeiten der Umgebungsvariablen
foreach line [split $env_data "\n"] {
    if {[string match {*=*} $line] && ![string match {#*} $line]} {
        set parts [split $line "="]
        set key [lindex $parts 0]
        # Entferne führende und abschließende Anführungszeichen falls vorhanden
        set value [string trim [join [lrange $parts 1 end] "="] "\"'"]
        set env($key) $value
    }
}

# Prüfen ob OPENROUTER_API_KEY gesetzt ist
if {![info exists env(OPENROUTER_API_KEY)] || $env(OPENROUTER_API_KEY) eq ""} {
    puts stderr "OPENROUTER_API_KEY fehlt"
    exit 1
}

# Setzen des GITHUB_TOKEN mit Fallback-Werten
if {![info exists env(GITHUB_TOKEN)] || $env(GITHUB_TOKEN) eq ""} {
    if {[info exists env(GH_TOKEN)] && $env(GH_TOKEN) ne ""} {
        set env(GITHUB_TOKEN) $env(GH_TOKEN)
    } elseif {[info exists env(GH_ACCESS_TOKEN)] && $env(GH_ACCESS_TOKEN) ne ""} {
        set env(GITHUB_TOKEN) $env(GH_ACCESS_TOKEN)
    }
}

# Ausführen des eigentlichen Kommandos mit flock
if {[catch {
    # Versuch das Lock zu erhalten und das Python-Skript auszuführen
    set lock_file "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
    set python_script "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"
    
    # Prüfen ob flock verfügbar ist
    if {[catch {exec /usr/bin/which flock}]} {
        puts stderr "flock nicht gefunden"
        exit 1
    }
    
    # Erstellen des Kommandostrings mit allen Argumenten
    set cmd [list /usr/bin/flock --nonblock $lock_file /usr/bin/python3 $python_script]
    
    # Hinzufügen der übergebenen Argumente
    foreach arg $argv {
        lappend cmd $arg
    }
    
    # Ausführen des Kommandos
    exec {*}$cmd
} result]} {
    # Wenn ein Fehler auftritt, geben wir ihn aus und beenden mit Fehlercode
    puts stderr $result
    exit 1
}
