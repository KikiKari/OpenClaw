#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3515c7f6de385fc8b50031e34b999abd10dfca9134cd94e5eee931f8943e9fdf", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "tcl"}
# serve_compare_transfer.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

set COMPARE_DIR "/home/openclaw/.openclaw/workspace/vscode/compare"
set TRANSFER_DIR "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
set HOST_IP "89.58.15.220"
set PORT "80"
set SELF_PATH [file normalize $argv0]

# Finde alle Dateien im Verzeichnis
set FILES {}
set dirHandle [glob -nocomplain -directory $COMPARE_DIR -types f *]
foreach file $dirHandle {
    if {$file ne $SELF_PATH} {
        lappend FILES $file
    }
}

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
exec python3 -m http.server $PORT --bind 0.0.0.0
