#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3c79123841ba456dec9f28477d0161c7d7d8281d59d426e7dd3ca992415f117d", "source_sha256": "8621f6f7e524474de82b3d877ee62bbcbd9fa3b247b69c437b063b71fa995f5a", "target_language": "tcl"}
# ops-hub-heartbeat.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
    
    # Aktuelle Zeit im deutschen Format (europäische Zeitzone)
    set now [clock format [clock seconds] -format "%d.%m.%Y, %H:%M:%S" -timezone :Europe/Berlin]
    
    # Ersetze den Heartbeat-Zeitstempel
    set updated [regsub {(Letzter Heartbeat:) \[^\n\]*} $content "\$1 $now"]
    
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
