#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3631efa92d1e6d649f3c55f010ce33b326b4a8963cfd66475076d4ee6e6f2348", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "tcl"}
# generated-output-utils.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have built-in modules like JavaScript, so we'll define procedures directly.
# We also need to simulate some of the Node.js functionality using Tcl's standard libraries.

# Import necessary packages
package require fileutil
package require uri

# Simulate path resolution and relative paths
proc path_resolve {args} {
    set resolved [file normalize [join $args "/"]]
    return $resolved
}

proc path_relative {from to} {
    # Simplified implementation for common cases
    set from_norm [file normalize $from]
    set to_norm [file normalize $to]
    # This is a basic approximation; real implementation would be more complex
    return [string range $to_norm [string length $from_norm]+1 end]
}

# Simulate reading file content if exists
proc readIfExists {filePath} {
    if {[file exists $filePath]} {
        set fh [open $filePath r]
        set content [read $fh]
        close $fh
        return $content
    } else {
        return ""
    }
}

# Simulate writeTextFileIfChanged
proc writeTextFileIfChanged {filePath nextContent} {
    set current [readIfExists $filePath]
    if {$current ne $nextContent} {
        set fh [open $filePath w]
        puts -nonewline $fh $nextContent
        close $fh
        return 1
    } else {
        return 0
    }
}

# Main function equivalent to writeGeneratedOutput
proc writeGeneratedOutput {paramsDict} {
    dict with paramsDict {}
    
    set outputPath [path_resolve $repoRoot $outputPath]
    set current [readIfExists $outputPath]
    set changed [expr {$current ne $next}]
    
    if {$check} {
        return [dict create changed $changed wrote 0 outputPath $outputPath]
    }
    
    set wrote [writeTextFileIfChanged $outputPath $next]
    return [dict create changed $changed wrote $wrote outputPath $outputPath]
}

# CLI reporting function equivalent to reportGeneratedOutputCli
proc reportGeneratedOutputCli {paramsDict} {
    dict with paramsDict {}
    
    # In Tcl, there's no direct equivalent to import.meta.url or process.argv[1],
    # but we can simulate this by checking if this script is being run directly.
    # For now, we'll assume it's always run directly unless otherwise specified.
    # You might want to add logic here based on how you invoke the script.
    
    global argv
    set check [expr {[lsearch $argv "--check"] != -1}]
    
    # Call the run procedure/function passed in params
    # Assuming 'run' is a command name passed as string
    set resultDict [uplevel #0 $run [list check $check]]
    
    if {![dict get $resultDict changed]} {
        return
    }
    
    set outputPath [dict get $resultDict outputPath]
    set relativeOutputPath [path_relative [pwd] $outputPath]
    
    if {$check} {
        puts stderr "\[[dict get $paramsDict label]\] stale generated output at $relativeOutputPath"
        exit 1
    } else {
        puts "\[[dict get $paramsDict label]\] wrote $relativeOutputPath"
    }
}
