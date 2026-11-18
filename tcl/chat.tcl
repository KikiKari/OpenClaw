#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "0a34e175ccfe1ed03b071b18e4e7e9498e8708d416ace6c7a4e7249f35d1267b", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "tcl"}
# chat.css — portiert nach tcl
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Portierung von chat.css nach Tcl 8.6
# Erzeugt die CSS-Imports als strukturierte Ausgabe

proc generate_chat_css {} {
    set imports [list \
        "./chat/layout.css" \
        "./chat/text.css" \
        "./chat/grouped.css" \
        "./chat/tool-cards.css" \
        "./chat/sidebar.css" \
    ]
    
    set output ""
    
    foreach import $imports {
        append output "@import \"$import\";\n"
    }
    
    return $output
}

proc write_css_to_file {filename} {
    set content [generate_chat_css]
    set fh [open $filename w]
    puts -nonewline $fh $content
    close $fh
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Aufruf: [info script] <ausgabedatei>"
    exit 1
}

set output_file [lindex $argv 0]
write_css_to_file $output_file
