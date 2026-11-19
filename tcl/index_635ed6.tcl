#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "fc15302d3040b51e663b77228a49051d964fe38212fb5812b6be8e407f5239b2", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "tcl"}
# index.html — portiert nach tcl
# Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc generateHTML {} {
    set html {}
    
    # Doctype declaration (as comment since Tcl doesn't directly support it)
    lappend html {<!doctype html>}
    
    # HTML tag with language attribute
    lappend html {<html lang="en">}
    
    # Head section
    lappend html {  <head>}
    lappend html {    <meta charset="utf-8" />}
    lappend html {    <meta name="viewport" content="width=device-width, initial-scale=1" />}
    lappend html {    <meta name="color-scheme" content="light dark" />}
    lappend html {    <title>QA Lab</title>}
    lappend html {  </head>}
    
    # Body section
    lappend html {  <body>}
    lappend html {    <div id="app"></div>}
    lappend html {    <script type="module" src="/src/main.ts"></script>}
    lappend html {  </body>}
    
    # Close HTML tag
    lappend html {</html>}
    
    return [join $html "\n"]
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set outputFile [lindex $argv 0]

# Generate the HTML content
set htmlContent [generateHTML]

# Write to file
if {[catch {open $outputFile w} fileId]} {
    puts stderr "Error: Could not open file '$outputFile' for writing"
    exit 1
}

puts $fileId $htmlContent
close $fileId

puts "HTML file generated successfully: $outputFile"
