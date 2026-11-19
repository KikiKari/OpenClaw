#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "a3f82f19a8db168de82922cb95bb5e571efb71fb2b3181380bbcbb874f0a52d7", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "tcl"}
# serve_compare_transfer.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

set COMPARE_DIR "/home/openclaw/.openclaw/workspace/vscode/compare"
set TRANSFER_DIR "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
set HOST_IP "152.53.145.65"
set PORT "80"
set SELF_PATH [file normalize $argv0]

# Sammle alle Dateien im Verzeichnis (ausser diesem Skript)
set FILES {}
catch {
    set dir_handle [open "|find \"$COMPARE_DIR\" -maxdepth 1 -type f" r]
    while {[gets $dir_handle line] >= 0} {
        if {$line ne $SELF_PATH} {
            lappend FILES $line
        }
    }
    close $dir_handle
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
if {[catch {exec python3 -m http.server $PORT --bind 0.0.0.0 &} err]} {
    puts "Fehler beim Starten des Servers: $err"
    exit 1
}

# Warte auf Benutzereingabe zum Beenden
puts "Drücke ENTER zum Beenden..."
gets stdin
exec kill %1
exit 0
