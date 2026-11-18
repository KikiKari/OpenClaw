#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "c04c95cf56870fa5b1040f1e972707c83beb8edbd6c10fa09910deb5b44fd8c5", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "tcl"}
# copy-plugin-sdk-root-alias.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 doesn't have built-in modules or import statements
# We'll implement the functionality directly

# Function to read file content
proc readFile {filename} {
    set fh [open $filename r]
    set content [read $fh]
    close $fh
    return $content
}

# Function to write text file if changed
proc writeTextFileIfChanged {filepath content} {
    # Check if file exists and content is different
    set shouldWrite 1
    if {[file exists $filepath]} {
        set fh [open $filepath r]
        set existingContent [read $fh]
        close $fh
        if {$existingContent eq $content} {
            set shouldWrite 0
        }
    }
    
    # Write file if needed
    if {$shouldWrite} {
        # Create directory if it doesn't exist
        set dir [file dirname $filepath]
        if {![file exists $dir]} {
            file mkdir $dir
        }
        
        set fh [open $filepath w]
        puts -nonewline $fh $content
        close $fh
        puts "Wrote $filepath"
    } else {
        puts "No changes to $filepath"
    }
}

# Main function
proc copyPluginSdkRootAlias {{params ""}} {
    # Get current working directory
    if {$params ne "" && [dict exists $params cwd]} {
        set cwd [dict get $params cwd]
    } else {
        set cwd [pwd]
    }
    
    # Resolve source and target paths
    set source [file normalize [file join $cwd src plugin-sdk root-alias.cjs]]
    set target [file normalize [file join $cwd dist plugin-sdk root-alias.cjs]]
    
    # Read source file and write to target
    if {[file exists $source]} {
        set content [readFile $source]
        writeTextFileIfChanged $target $content
    } else {
        error "Source file does not exist: $source"
    }
}

# Check if script is run directly (equivalent to import.meta check)
# In Tcl, this is always the main script when executed
if {[info script] eq $argv0} {
    copyPluginSdkRootAlias
}
