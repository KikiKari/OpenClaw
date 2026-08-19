#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, Projects@Program-Derivation:public/index.html
# auch in: Projects@Vision-Check:public/index.html
# auch in: Projects@Weather-Check:public/index.html
# auch in: Projects@abstractions:public/index.html
# auch in: 5 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Tcl-Skript zur Erstellung der HTML-Datei index.html
# Erzeugt eine Weiterleitungsseite zur 3D-Ansicht

proc create_index_html {filename} {
    set fp [open $filename w]
    
    # HTML-Kopf und DOCTYPE
    puts $fp "<!DOCTYPE html>"
    puts $fp "<html lang=\"de\">"
    puts $fp "<head>"
    
    # Metadaten
    puts $fp "<meta charset=\"utf-8\">"
    puts $fp "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    puts $fp "<meta http-equiv=\"refresh\" content=\"0; url=3d.html\">"
    
    # Titel
    puts $fp "<title>Weiterleitung zur 3D-Ansicht</title>"
    
    # Canonical Link
    puts $fp "<link rel=\"canonical\" href=\"3d.html\">"
    
    # JavaScript für sofortige Weiterleitung
    puts $fp "<script>location.replace('3d.html');</script>"
    
    # Abschluss head, Beginn body
    puts $fp "</head>"
    puts $fp "<body>"
    
    # Inhalt mit Link
    puts $fp "<p><a href=\"3d.html\">3D-Ansicht öffnen</a></p>"
    
    # Abschluss
    puts $fp "</body>"
    puts $fp "</html>"
    
    close $fp
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Aufruf: [info script] <ziel_datei>"
    exit 1
}

set target_file [lindex $argv 0]
create_index_html $target_file
