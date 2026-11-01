#!/usr/bin/env tclsh
# status-overview.css — portiert nach tcl
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.css
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

# Tcl script to generate CSS content and write it to a file
# This script replicates the functionality of creating the CSS document
# and writing it to a specified output file.

proc generate_css_content {} {
    set css_content {
* {
    box-sizing: border-box;
}

html, body {
    margin: 0;
    min-height: 100%;
    background: #101015;
    color: #fff;
    font: 14px system-ui, sans-serif;
}

body {
    display: flex;
    flex-direction: column;
    height: 100vh;
}

header {
    display: flex;
    gap: 1em;
    align-items: baseline;
    padding: 0 12px;
}

h1 {
    font-size: 17px;
    margin: 8px 0;
}

header p {
    font-size: 12px;
    color: #bbb;
    margin: 0;
}

main {
    flex: 1;
    min-height: 0;
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    grid-template-rows: repeat(3, minmax(0, 1fr));
    gap: 4px;
    padding: 0;
}

.tile {
    min-width: 0;
    min-height: 0;
    display: flex;
    flex-direction: column;
    background: #202026;
    border: 1px solid #393940;
}

.tile h2 {
    font-size: 13px;
    margin: 3px 8px;
}

.tile video {
    min-height: 0;
    width: 100%;
    flex: 1;
    object-fit: contain;
    background: #000;
}

.tile p {
    font-size: 11px;
    margin: 3px 8px;
    color: #ddd;
}

main.grid2 {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-template-rows: repeat(2, minmax(0, 1fr));
}

.tile[hidden] {
    display: none;
}
    }
    
    # Trim leading/trailing whitespace while preserving internal formatting
    return [string trim $css_content]
}

proc write_css_to_file {filename} {
    set css_content [generate_css_content]
    
    # Open file for writing
    if {[catch {open $filename w} fileId]} {
        error "Could not open file '$filename' for writing"
    }
    
    # Write content to file
    puts -nonewline $fileId $css_content
    
    # Close file
    close $fileId
    
    puts "CSS content written to $filename"
}

# Main execution
if {$argc != 1} {
    puts "Usage: $argv0 <output_filename>"
    exit 1
}

set output_filename [lindex $argv 0]
write_css_to_file $output_filename
