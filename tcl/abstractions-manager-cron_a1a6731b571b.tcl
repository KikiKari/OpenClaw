#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "47dc92fb73034a9b862c0ac40013af6a00b49f6c4d1e585322744cb22c73f016", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "tcl"}
# abstractions-manager-cron.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Setzen der Umgebungsvariablen für PATH
set env(PATH) "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Laden der Umgebungsvariablen aus der .env Datei
if {[file exists "/home/openclaw/.openclaw/.env"]} {
    set fp [open "/home/openclaw/.openclaw/.env" r]
    while {[gets $fp line] >= 0} {
        if {[regexp {^([^#=][^=]*)=(.*)$} $line -> key value]} {
            set env($key) $value
        }
    }
    close $fp
}

# Prüfen ob OPENROUTER_API_KEY gesetzt ist
if {![info exists env(OPENROUTER_API_KEY)] || $env(OPENROUTER_API_KEY) eq ""} {
    puts stderr "OPENROUTER_API_KEY fehlt"
    exit 1
}

# Setzen des GITHUB_TOKEN mit Fallbacks
if {![info exists env(GITHUB_TOKEN)] || $env(GITHUB_TOKEN) eq ""} {
    if {[info exists env(GH_TOKEN)] && $env(GH_TOKEN) ne ""} {
        set env(GITHUB_TOKEN) $env(GH_TOKEN)
    } elseif {[info exists env(GH_ACCESS_TOKEN)] && $env(GH_ACCESS_TOKEN) ne ""} {
        set env(GITHUB_TOKEN) $env(GH_ACCESS_TOKEN)
    }
}

# Erstellen des Lock-Files und Ausführen des Python-Skripts
set lockfile "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
set python_script "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"

# Versuchen das Lock zu erhalten (non-blocking)
if {[catch {open $lockfile w} lock_fd]} {
    puts stderr "Kann Lock-Datei nicht öffnen: $lockfile"
    exit 1
}

if {[catch {chan lock $lock_fd -nowait} result]} {
    # Lock konnte nicht erhalten werden
    close $lock_fd
    exit 0
}

# Lock erhalten, nun Python-Skript ausführen
set cmd [list exec /usr/bin/python3 $python_script {*}$argv]

if {[catch {$cmd} output]} {
    puts stderr "Fehler beim Ausführen des Python-Skripts: $output"
    close $lock_fd
    exit 1
} else {
    puts -nonewline $output
}

close $lock_fd
exit 0
