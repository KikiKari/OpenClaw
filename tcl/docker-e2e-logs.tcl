#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "d05ebb790f055b93784e1635d809a52879b2189864dd799933b0e4ced7d892e9", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "tcl"}
# docker-e2e-logs.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc run_logged {label args} {
    # Erstelle temporäre Logdatei
    set tempdir [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : "/tmp"}]
    set log_file [exec mktemp "${tempdir}/openclaw-${label}.XXXXXX.log"]
    
    # Führe Befehl aus und leite Ausgabe in Logdatei um
    if {[catch {exec {*}$args > $log_file 2>@1} result]} {
        # Bei Fehler: Zeige Logdatei-Inhalt an
        if {[file exists $log_file]} {
            set fh [open $log_file r]
            set content [read $fh]
            close $fh
            puts -nonewline stdout $content
        }
        # Lösche Logdatei
        if {[file exists $log_file]} {
            file delete $log_file
        }
        return -code error $result
    }
    
    # Lösche Logdatei bei Erfolg
    if {[file exists $log_file]} {
        file delete $log_file
    }
    
    return $result
}
