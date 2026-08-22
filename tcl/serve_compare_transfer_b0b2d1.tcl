#!/usr/bin/env tclsh
# serve_compare_transfer.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

set COMPARE_DIR "/home/openclaw/.openclaw/workspace/vscode/compare"
set TRANSFER_DIR "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
set HOST_IP "89.58.15.220"
set PORT "80"
set SELF_PATH [file normalize $argv0]

# Finde alle Dateien im Vergleichsverzeichnis
set FILES {}
set dir_handle [open "|find \"$COMPARE_DIR\" -maxdepth 1 -type f -not -path \"$SELF_PATH\"" r]
while {[gets $dir_handle line] >= 0} {
    if {$line ne "" && [file exists $line]} {
        lappend FILES $line
    }
}
close $dir_handle

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

# Starte HTTP-Server
cd $COMPARE_DIR
exec python3 -m http.server $PORT --bind 0.0.0.0 &

# Warte auf Benutzereingabe zum Beenden
vwait forever
