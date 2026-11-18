#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "a59664b27a9441bcfdaa18d44ee937ffdce6a4a0ce3f10c1debc60bd2c24693b", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "tcl"}
# post-nodes-report.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Pfade
set scriptDir [file dirname [info script]]
set DASHBOARD_PATH [file join $scriptDir .. dashboards nodes-overview.md]
set REPORT_LOG [file join $scriptDir .. logs nodes-report.log]

# Farbcodes
array set C {
    green "\u001b\[32m"
    yellow "\u001b\[33m"
    red "\u001b\[31m"
    reset "\u001b\[0m"
}

proc postReport {} {
    global DASHBOARD_PATH REPORT_LOG C

    # Dashboard-Datei lesen
    if {![file exists $DASHBOARD_PATH]} {
        puts "${C(red)}❌ Fehler beim Lesen der Dashboard-Datei:${C(reset)} Datei nicht gefunden"
        return
    }

    set content ""
    if {[catch {
        set fh [open $DASHBOARD_PATH r]
        set content [read $fh]
        close $fh
    } err]} {
        puts "${C(red)}❌ Fehler beim Lesen der Dashboard-Datei:${C(reset)} $err"
        return
    }

    # Nachricht über OpenClaw message senden
    # JSON-Formatierung und Escape von Newlines
    set escapedContent [string map {"\n" "\\n" "\"" "\\\""} $content]
    set messageCmd "openclaw message send --target=main --message \"$escapedContent\""

    if {[catch {
        set result [exec {*}$messageCmd]
        puts "${C(green)}✅ Report erfolgreich im 'main'-Channel gepostet.${C(reset)}"
        
        # Log-Eintrag schreiben
        set timestamp [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]
        set fh [open $REPORT_LOG a]
        puts $fh "\[$timestamp\] Report posted."
        close $fh
    } err]} {
        puts "${C(red)}❌ Fehler beim Senden der Nachricht:${C(reset)} $err"
        
        # Fehler-Log-Eintrag schreiben
        set timestamp [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]
        set fh [open $REPORT_LOG a]
        puts $fh "\[$timestamp\] Failed to post: $err"
        close $fh
    }
}

# Hauptausführung
puts "${C(yellow)}📤 Sende Nodes-Übersicht in 'main'...${C(reset)}"
postReport
