#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "af35c57289d82d3ad87a6df3cb34c0d365d1d72cd50aff0f5aeab3381852a4b1", "source_sha256": "2516612af0a0435eb92af19fa6d322dbf03b3c95168e1f623ea14087f9e79413", "target_language": "tcl"}
# run-vitest.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of run-vitest.mjs

# Global variables to mimic JavaScript constants
set TRUTHY_ENV_VALUES [dict create 1 1 true 1 yes 1 on 1]
set SUPPRESSED_VITEST_STDERR_PATTERNS [list "\[PLUGIN_TIMINGS\] Warning:"]

# Helper function to check truthy environment values
proc isTruthyEnvValue {value} {
    global TRUTHY_ENV_VALUES
    set trimmed [string trim [string tolower $value]]
    return [dict exists $TRUTHY_ENV_VALUES $trimmed]
}

# Resolve Vitest Node arguments
proc resolveVitestNodeArgs {{env ""}} {
    if {$env eq ""} {
        # Get environment variables
        array set envArray [array get ::env]
        set env [array get envArray]
    }
    
    # Convert env list to dict for easier access
    set envDict [dict create {*}$env]
    
    if {[dict exists $envDict OPENCLAW_VITEST_ENABLE_MAGLEV] && 
        [isTruthyEnvValue [dict get $envDict OPENCLAW_VITEST_ENABLE_MAGLEV]]} {
        return [list]
    }
    
    return [list "--no-maglev"]
}

# Resolve Vitest CLI entry point
proc resolveVitestCliEntry {} {
    # In Tcl we'll use a simplified approach since we don't have require.resolve
    # This assumes vitest is installed locally or globally accessible
    return "vitest"
}

# Resolve Vitest spawn parameters
proc resolveVitestSpawnParams {{env ""} {platform ""}} {
    if {$platform eq ""} {
        # Detect platform in Tcl
        switch $::tcl_platform(platform) {
            "windows" {
                set platform "win32"
            }
            default {
                set platform $::tcl_platform(os)
            }
        }
    }
    
    # Determine if detached process is needed
    set detached false
    if {$platform ne "win32"} {
        set detached true
    }
    
    return [list \
        env $env \
        detached $detached \
        stdin "inherit" \
        stdout "pipe" \
        stderr "pipe"]
}

# Check if stderr line should be suppressed
proc shouldSuppressVitestStderrLine {line} {
    global SUPPRESSED_VITEST_STDERR_PATTERNS
    foreach pattern $SUPPRESSED_VITEST_STDERR_PATTERNS {
        if {[string first $pattern $line] != -1} {
            return 1
        }
    }
    return 0
}

# Forward output from child process
proc forwardVitestOutput {stream target shouldSuppressLine} {
    # This is a placeholder as Tcl's exec doesn't provide the same streaming capabilities
    # In a real implementation, you would need to use pipes and fileevent
    return
}

# Main function
proc main {{argv ""}} {
    global argv
    
    if {$argv eq ""} {
        set argv $::argv
    }
    
    if {[llength $argv] == 0} {
        puts stderr "usage: tclsh run-vitest.tcl <vitest args...>"
        exit 1
    }
    
    # Build command
    set nodeArgs [resolveVitestNodeArgs]
    set cliEntry [resolveVitestCliEntry]
    
    # Construct the full command
    set cmd [list exec pnpm exec node {*}$nodeArgs $cliEntry {*}$argv]
    
    # Try to execute the command
    if {[catch {eval $cmd} result]} {
        puts stderr "Error running vitest: $result"
        exit 1
    } else {
        puts $result
    }
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main
}
