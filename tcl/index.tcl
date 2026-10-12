#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

proc writeIndexHtml {filename} {
    set f [open $filename w]
    
    puts $f {<!doctype html>}
    puts $f {<html lang="de">}
    puts $f "  <head>"
    puts $f {    <meta charset="UTF-8" />}
    puts $f {    <meta name="viewport" content="width=device-width, initial-scale=1.0" />}
    puts $f {    <meta name="description" content="Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />}
    puts $f {    <meta name="theme-color" content="#ffffff" />}
    puts $f {    <link rel="icon" type="image/png" href="/branding/staenderglobus-ios.png" />}
    puts $f {    <link rel="apple-touch-icon" href="/branding/staenderglobus-ios.png" />}
    puts $f {    <title>TikTok LIVE Companion – Dokumentation</title>}
    puts $f "  </head>"
    puts $f "  <body>"
    puts $f {    <div id="root"></div>}
    puts $f {    <script type="module" src="/src/main.tsx"></script>}
    puts $f "  </body>"
    puts $f "</html>"
    
    close $f
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Verwendung: [info script] <ausgabedatei>"
    exit 1
}

set outputFile [lindex $argv 0]
writeIndexHtml $outputFile
