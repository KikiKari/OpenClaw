#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# auch in: Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Tcl-Skript zur Erstellung der index.html-Datei
# Portiert von HTML zu Tcl 8.6

proc create_index_html {filename} {
    set fp [open $filename w]
    
    # Schreiben des DOCTYPE
    puts $fp "<!doctype html>"
    
    # Öffnendes HTML-Tag mit Attribut
    puts $fp "<html lang=\"de\">"
    
    # Head-Bereich
    puts $fp "  <head>"
    puts $fp "    <meta charset=\"UTF-8\" />"
    puts $fp "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />"
    puts $fp "    <meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />"
    puts $fp "    <meta name=\"theme-color\" content=\"#ffffff\" />"
    puts $fp "    <link rel=\"icon\" type=\"image/png\" href=\"/branding/staenderglobus-ios.png\" />"
    puts $fp "    <link rel=\"apple-touch-icon\" href=\"/branding/staenderglobus-ios.png\" />"
    puts $fp "    <title>TikTok LIVE Companion – Dokumentation</title>"
    puts $fp "  </head>"
    
    # Body-Bereich
    puts $fp "  <body>"
    puts $fp "    <div id=\"root\"></div>"
    puts $fp "    <script type=\"module\" src=\"/src/main.tsx\"></script>"
    puts $fp "  </body>"
    
    # Schließendes HTML-Tag
    puts $fp "</html>"
    
    close $fp
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Verwendung: $argv0 <ausgabedatei>"
    exit 1
}

set output_file [lindex $argv 0]
create_index_html $output_file
