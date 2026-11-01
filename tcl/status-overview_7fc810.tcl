#!/usr/bin/env tclsh
# status-overview.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 Script zur Erstellung der status-overview.html
# Portiert von HTML zu dynamischem Tcl-Code

proc create_status_overview {filename} {
    set html {}
    
    # HTML5 DOCTYPE und Basisstruktur
    append html "<!doctype html>\n"
    append html "<html lang=\"de\">"
    append html "<head>"
    append html "<meta charset=\"utf-8\">"
    append html "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
    append html "<title>STATUS-Overview</title>"
    append html "<link rel=\"stylesheet\" href=\"status-overview.css\">"
    append html "</head>\n"
    append html "<body>"
    append html "<main id=\"grid\" aria-label=\"LIVE-Übersicht\"></main>"
    append html "<script src=\"vendor-mpegts.js\"></script>"
    append html "<script src=\"status-overview-player.js\"></script>"
    append html "</body>"
    append html "</html>\n"
    
    # Schreiben in Datei
    set fh [open $filename w]
    puts -nonewline $fh $html
    close $fh
}

# Hauptprogramm - prüft Kommandozeilenargument
if {$argc != 1} {
    puts stderr "Aufruf: [info script] <dateiname>"
    exit 1
}

set filename [lindex $argv 0]
create_status_overview $filename
