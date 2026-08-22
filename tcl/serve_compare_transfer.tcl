#!/usr/bin/env tclsh
# serve_compare_transfer.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

set COMPARE_DIR "/home/openclaw/.openclaw/workspace/vscode/compare"
set TRANSFER_DIR "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
set HOST_IP "152.53.145.65"
set PORT "80"
set SELF_PATH [file normalize $argv0]

# Finde alle Dateien im Vergleichsverzeichnis
set FILES {}
set fd [open "|find \"$COMPARE_DIR\" -maxdepth 1 -type f -not -path \"$SELF_PATH\"" r]
while {[gets $fd line] >= 0} {
    lappend FILES $line
}
close $fd

# Sortiere die Dateien
set FILES [lsort $FILES]

if {[llength $FILES] == 0} {
    puts "Keine Dateien in $COMPARE_DIR gefunden."
    exit 1
}

puts ""
puts "Bereitgestellte Dateien aus $COMPARE_DIR:"
foreach src $FILES {
    puts "- [file tail $src]"
}

puts ""
puts "Copy/Paste auf anderem Gateway (Download nach $TRANSFER_DIR):"
foreach src $FILES {
    set file [file tail $src]
    puts "curl -fL --retry 3 --connect-timeout 10 -o $TRANSFER_DIR/$file http://$HOST_IP:$PORT/$file"
}

puts ""
puts "Server auf Port $PORT aktiv. Beenden mit STRG+C."
puts ""

# Wechsle ins Vergleichsverzeichnis und starte den HTTP-Server
cd $COMPARE_DIR

# Erstelle einen einfachen HTTP-Server
proc handle_request {sock addr port} {
    if {[catch {gets $sock request}]} {
        close $sock
        return
    }
    
    if {[regexp {GET /([^ ]+)} $request -> filename]} {
        set filepath [file join [pwd] $filename]
        if {[file exists $filepath] && [file isfile $filepath]} {
            if {[catch {open $filepath r} fp]} {
                puts $sock "HTTP/1.1 403 Forbidden"
                puts $sock "Content-Type: text/plain"
                puts $sock ""
                puts $sock "403 Forbidden"
                close $sock
                return
            }
            
            # Bestimme den Content-Type
            set ext [string tolower [file extension $filepath]]
            switch $ext {
                ".txt" - ".log" {
                    set content_type "text/plain"
                }
                ".html" - ".htm" {
                    set content_type "text/html"
                }
                ".css" {
                    set content_type "text/css"
                }
                ".js" {
                    set content_type "application/javascript"
                }
                default {
                    set content_type "application/octet-stream"
                }
            }
            
            # Lese die Dateigröße
            set filesize [file size $filepath]
            
            puts $sock "HTTP/1.1 200 OK"
            puts $sock "Content-Type: $content_type"
            puts $sock "Content-Length: $filesize"
            puts $sock ""
            
            # Sende den Dateiinhalt
            set buffer [read $fp]
            puts -nonewline $sock $buffer
            close $fp
        } else {
            puts $sock "HTTP/1.1 404 Not Found"
            puts $sock "Content-Type: text/plain"
            puts $sock ""
            puts $sock "404 Not Found"
        }
    } else {
        puts $sock "HTTP/1.1 400 Bad Request"
        puts $sock "Content-Type: text/plain"
        puts $sock ""
        puts $sock "400 Bad Request"
    }
    
    flush $sock
    close $sock
}

# Starte den Server
socket -server handle_request $PORT 0.0.0.0
puts "HTTP-Server läuft auf Port $PORT"

# Halte das Skript am Laufen
vwait forever
