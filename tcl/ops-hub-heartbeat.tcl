#!/usr/bin/env tclsh
# ops-hub-heartbeat.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Aktualisiere den Statusbericht mit aktueller Zeit
set statusPath [file join [file dirname [file dirname [info script]]] docs ops-hub status.md]

proc updateHeartbeat {} {
    global statusPath
    
    # Lies den Inhalt der Datei
    if {[catch {open $statusPath r} fh]} {
        puts stderr "❌ Konnte status.md nicht lesen: $fh"
        return
    }
    set content [read $fh]
    close $fh
    
    # Aktuelle Zeit im deutschen Format (Berlin)
    set now [clock format [clock seconds] -format "%d.%m.%Y, %H:%M:%S" -timezone :Europe/Berlin]
    
    # Ersetze die Zeile mit dem Heartbeat
    set updated [regsub {(Letzter Heartbeat:) [^\n]*} $content "\\1 $now"]
    
    # Schreibe den aktualisierten Inhalt zurück
    if {[catch {open $statusPath w} fh]} {
        puts stderr "❌ Konnte status.md nicht schreiben: $fh"
        return
    }
    puts $fh $updated
    close $fh
    
    puts "✅ Heartbeat aktualisiert: $now"
}

updateHeartbeat
