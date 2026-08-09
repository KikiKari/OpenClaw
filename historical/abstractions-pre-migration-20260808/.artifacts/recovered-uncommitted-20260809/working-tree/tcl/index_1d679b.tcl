#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# auch in: Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

proc writeIndexHtml {filename} {
    set html [list]
    lappend html {<!doctype html>}
    lappend html {<html lang="de">}
    lappend html {  <head>}
    lappend html {    <meta charset="UTF-8" />}
    lappend html {    <meta name="viewport" content="width=device-width, initial-scale=1.0" />}
    lappend html {    <meta name="description" content="Dokumentation für TikTok LIVE Companion 0.7.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />}
    lappend html {    <meta name="theme-color" content="#ffffff" />}
    lappend html {    <title>TikTok LIVE Companion – Dokumentation</title>}
    lappend html {  </head>}
    lappend html {  <body>}
    lappend html {    <div id="root"></div>}
    lappend html {    <script type="module" src="/src/main.tsx"></script>}
    lappend html {  </body>}
    lappend html {</html>}

    set f [open $filename w]
    puts $f [join $html "\n"]
    close $f
}

if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

writeIndexHtml [lindex $argv 0]
