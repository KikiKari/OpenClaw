#!/usr/bin/env tclsh
# offscreen.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
# auch in: Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
# auch in: 2 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 Skript zur Erzeugung der HTML-Struktur fuer TikTok LIVE Companion Sprachausgabe
# Uebernimmt die Funktion des Originals offscreen.html

proc create_html_file {filename} {
    # Oeffne Datei zum Schreiben
    set fd [open $filename w]
    
    # Schreibe HTML-Grundstruktur
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
    
    # Schliesse Datei
    close $fd
}

# Hauptprogramm: Pruefe Kommandozeilenargument
if {$argc != 1} {
    puts stderr "Aufruf: [info script] <dateiname>"
    exit 1
}

# Erzeuge HTML-Datei mit uebergebenem Namen
create_html_file [lindex $argv 0]
