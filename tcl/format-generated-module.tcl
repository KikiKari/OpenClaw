#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "e2135460846d494d91d80164ea86a8a2967f213361ba1410e4dc560403c92e49", "source_sha256": "5826d57477404d40d10bccd3a144f22f3f46ce4897073fa71d1d3868edfe8719", "target_language": "tcl"}
# format-generated-module.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/format-generated-module.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Tcl does not have built-in modules like JavaScript, so we'll create a procedure instead.
# The exported function becomes a regular proc in Tcl.

proc formatGeneratedModule {source optionsDict} {
    # Extract options with defaults
    set repoRoot [dict get $optionsDict repoRoot]
    set outputPath [dict get $optionsDict outputPath]
    set errorLabel [dict get $optionsDict errorLabel]

    # Resolve paths - Tcl doesn't have path.resolve, so we implement basic resolution
    set resolvedRepoRoot [file normalize $repoRoot]
    
    # Handle absolute vs relative paths for outputPath
    if {[string match "/*" $outputPath] || [string match "*:/*" $outputPath]} {
        # outputPath is absolute, make it relative to repoRoot
        set resolvedOutputPath [file join $resolvedRepoRoot [file relatif $resolvedRepoRoot $outputPath]]
    } else {
        # outputPath is already relative
        set resolvedOutputPath [file join $resolvedRepoRoot $outputPath]
    }

    # Check for direct formatter (oxfmt)
    set directFormatterPath [file join $resolvedRepoRoot "node_modules" ".bin" "oxfmt"]
    set useDirectFormatter 0
    
    # On non-Windows platforms, check if oxfmt exists
    if {$::tcl_platform(platform) ne "windows"} {
        if {[file exists $directFormatterPath] && [file executable $directFormatterPath]} {
            set useDirectFormatter 1
        }
    }
    
    set command ""
    if {$useDirectFormatter} {
        set command $directFormatterPath
    } else {
        set command "pnpm"
    }

    # Create temporary directory
    set tempDir [exec mktemp -d "/tmp/openclaw-generated-format-XXXXXX"]
    set tempOutputPath [file join $tempDir [file tail $resolvedOutputPath]]

    # Ensure cleanup happens even if errors occur
    set cleanupNeeded 1
    if {1} {
        # Try block equivalent
        # Write source to temp file
        set fh [open $tempOutputPath w]
        puts -nonewline $fh $source
        close $fh

        # Prepare arguments
        set args {}
        if {$useDirectFormatter} {
            lappend args "--write"
            lappend args $tempOutputPath
        } else {
            lappend args "exec"
            lappend args "oxfmt"
            lappend args "--write"
            lappend args $tempOutputPath
        }

        # Execute formatter
        if {$::tcl_platform(platform) eq "windows"} {
            # Windows needs shell execution
            set cmd "$command [join $args " "]"
            if {[catch {exec /bin/sh -c $cmd} output]} {
                set formatterError $output
                set formatterStatus 1
            } else {
                set formatterOutput $output
                set formatterStatus 0
            }
        } else {
            if {[catch {exec $command {*}$args} output]} {
                set formatterError $output
                set formatterStatus 1
            } else {
                set formatterOutput $output
                set formatterStatus 0
            }
        }

        # Check for formatter errors
        if {$formatterStatus != 0} {
            set details ""
            if {[info exists formatterError] && [string length [string trim $formatterError]] > 0} {
                set details [string trim $formatterError]
            } elseif {[info exists formatterOutput] && [string length [string trim $formatterOutput]] > 0} {
                set details [string trim $formatterOutput]
            } else {
                set details "unknown formatter failure"
            }
            error "failed to format generated $errorLabel: $details"
        }

        # Read formatted content
        set fh [open $tempOutputPath r]
        set result [read $fh]
        close $fh
        
        # Cleanup will happen in finally block
    }

    # Finally block - always execute cleanup
    if {[info exists cleanupNeeded]} {
        if {[file exists $tempDir]} {
            file delete -force $tempDir
        }
    }

    return $result
}
