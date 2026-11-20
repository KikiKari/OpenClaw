#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "b99a2d2a3b5fd7d1680fb5ecf8d1abbfcdb38bf6de55f4626343aa0436439926", "source_sha256": "969958657b3b071c8b5067af0ac0287ac68f3fbc6c5832a0339555e3a87d3357", "target_language": "tcl"}
# glossary.go — portiert nach tcl
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/glossary.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Tcl equivalent of glossary.go

# Define a procedure to load glossary from JSON file
proc LoadGlossary {path} {
    # Check if file exists
    if {![file exists $path]} {
        return {}
    }
    
    # Read the file content
    if {[catch {open $path r} fh]} {
        error "Failed to open file: $fh"
    }
    
    set data {}
    if {[catch {read $fh} data]} {
        close $fh
        error "Failed to read file: $data"
    }
    close $fh
    
    # Parse JSON data
    if {[catch {::json::json2dict $data} parsed_data]} {
        error "glossary parse failed: $parsed_data"
    }
    
    # Convert to list of dictionaries (entries)
    set entries {}
    foreach entry $parsed_data {
        lappend entries $entry
    }
    
    return $entries
}

# Note: This requires the json package
package require json
