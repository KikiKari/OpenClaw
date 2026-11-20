#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "bbe4426422fef2e0c644f280f5b59c93c5eb2f3851f3f7fd1d8d75dd2ab77ee9", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "tcl"}
# styles.css — portiert nach tcl
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

# Tcl-Script zum Erstellen der styles.css
# Portiert von CSS zu Tcl 8.6

proc writeStylesCss {filename} {
    set fp [open $filename w]
    
    # Schreibe die @import-Anweisungen
    puts $fp "@import \"./styles/base.css\";"
    puts $fp "@import \"./styles/layout.css\";"
    puts $fp "@import \"./styles/layout.mobile.css\";"
    puts $fp "@import \"./styles/components.css\";"
    puts $fp "@import \"./styles/chat.css\";"
    puts $fp "@import \"./styles/config.css\";"
    puts $fp "@import \"./styles/usage.css\";"
    puts $fp "@import \"./styles/dreams.css\";"
    puts $fp "@import \"@create-markdown/preview/themes/system.css\";"
    puts $fp ""
    
    # Schreibe die .cm-preview-Klasse
    puts $fp ".cm-preview {"
    puts $fp "  --cm-mono: var(--mono);"
    puts $fp "  --cm-link: var(--accent);"
    puts $fp "  --cm-info: var(--info);"
    puts $fp "  --cm-warning: var(--warn);"
    puts $fp "  --cm-success: var(--ok);"
    puts $fp "  --cm-danger: var(--danger);"
    puts $fp "}"
    
    close $fp
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Verwendung: $argv0 <ausgabedatei>"
    exit 1
}

set outputFile [lindex $argv 0]
writeStylesCss $outputFile
