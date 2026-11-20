#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "707dbd3b8fca5d43c414a11cb13edebbac19b34c40ef745af5529abf355d97a9", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "tcl"}
# filter-staged-files.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Prints selected files as NUL-delimited tokens to stdout.
#
# Usage:
#   tclsh filter-staged-files.tcl lint -- <files...>
#   tclsh filter-staged-files.tcl format -- <files...>
#
# Keep this dependency-free: the pre-commit hook runs in many environments.

# Extract command line arguments
lassign $argv mode rawArgs

# Process files list
set files {}
if {[lindex $rawArgs 0] eq "--"} {
    set files [lrange $rawArgs 1 end]
} else {
    set files $rawArgs
}

# Validate mode
if {$mode ne "lint" && $mode ne "format"} {
    puts stderr "usage: filter-staged-files.tcl <lint|format> -- <files...>"
    exit 2
}

# Define extension sets
set lintExts [dict create .ts {} .tsx {} .js {} .jsx {} .mjs {} .cjs {}]
set formatExts [dict create .ts {} .tsx {} .js {} .jsx {} .mjs {} .cjs {} .json {} .md {} .mdx {}]
set formatIgnoredPaths [dict create src/canvas-host/a2ui/a2ui.bundle.js {}]

# Function to determine if a file should be selected
proc shouldSelect {filePath mode lintExts formatExts formatIgnoredPaths} {
    # Extract file extension
    set ext [string tolower [file extension $filePath]]
    
    if {$mode eq "lint"} {
        return [dict exists $lintExts $ext]
    }
    
    if {[dict exists $formatIgnoredPaths $filePath]} {
        return 0
    }
    
    return [dict exists $formatExts $ext]
}

# Process each file
foreach file $files {
    if {[shouldSelect $file $mode $lintExts $formatExts $formatIgnoredPaths]} {
        puts -nonewline stdout $file
        puts -nonewline stdout "\0"
    }
}
