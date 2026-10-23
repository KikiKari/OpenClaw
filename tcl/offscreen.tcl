#!/usr/bin/env tclsh
# offscreen.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 Script zur Erzeugung der HTML-Struktur von offscreen.html
# Dieses Skript erzeugt dynamisch das HTML-Dokument und speichert es in eine Datei

proc generate_offscreen_html {filename} {
    # Oeffne die Zieldatei zum Schreiben
    set fd [open $filename w]
    
    # Schreibe die HTML-Struktur
    puts $fd "<!doctype html>"
    puts $fd "<html lang=\"de\">"
    puts $fd "<head>"
    puts $fd "  <meta charset=\"utf-8\">"
    puts $fd "  <title>TikTok LIVE Companion Sprachausgabe</title>"
    puts $fd "</head>"
    puts $fd "<body>"
    puts $fd "  <script src=\"offscreen.js\"></script>"
    puts $fd "</body>"
    puts $fd "</html>"
    
    # Schliesse die Datei
    close $fd
}

# Hauptprogramm
if {$argc != 1} {
    puts "Verwendung: [info script] <ausgabedatei>"
    exit 1
}

set output_file [lindex $argv 0]
generate_offscreen_html $output_file
puts "HTML-Datei wurde erfolgreich erstellt: $output_file"
