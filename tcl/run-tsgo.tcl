#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "8d376564d874acad820e680da8c92e4d1d924a2473f44530e7a7e17f22159b85", "source_sha256": "5425378c778f4ef6ac0e8404ecffe774c2d3aea6bad539b4fd772554e566f469", "target_language": "tcl"}
# run-tsgo.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-tsgo.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have native module imports like JavaScript.
# We'll need to implement or source equivalent functionality.

# Since Tcl doesn't have built-in child_process or fs modules,
# we will use exec for subprocesses and file commands for filesystem operations.

# The following procedures are assumed to be defined elsewhere or implemented here:
# - applyLocalTsgoPolicy
# - acquireLocalHeavyCheckLockSync
# For this translation, I'll create placeholder implementations that match the behavior.

proc applyLocalTsgoPolicy {args env} {
    # Placeholder implementation - in real scenario would modify args and env as needed
    return [list args $args env $env]
}

proc acquireLocalHeavyCheckLockSync {options} {
    # Placeholder for lock acquisition logic
    # In practice, this might involve creating a lock file or similar mechanism
    puts "Acquiring local heavy check lock..."
    return {releaseLock}
}

proc releaseLock {} {
    # Placeholder for releasing the lock
    puts "Releasing local heavy check lock."
}

proc readFlagValue {args name} {
    set len [llength $args]
    for {set index 0} {$index < $len} {incr index} {
        set arg [lindex $args $index]
        if {$arg eq $name} {
            incr index
            if {$index < $len} {
                return [lindex $args $index]
            }
        } elseif {[string first "$name=" $arg] == 0} {
            return [string range $arg [string length "$name="] end]
        }
    }
    return ""
}

# Main script starts here

# Get command line arguments (excluding script name)
lassign $argv argv0 argv1 argv2 argv3 argv4 argv5 argv6 argv7 argv8 argv9
set all_args [list $argv0 $argv1 $argv2 $argv3 $argv4 $argv5 $argv6 $argv7 $argv8 $argv9]

# Filter out empty elements due to limitation of lassign with variable number of args
set filtered_args {}
foreach item $all_args {
    if {$item ne ""} {
        lappend filtered_args $item
    }
}

# Apply policy (placeholder)
array set policy_result [applyLocalTsgoPolicy $filtered_args [array get env]]
set finalArgs $policy_result(args)

# Determine tsgo path
set tsgoPath [file normalize "node_modules/.bin/tsgo"]

# Handle --tsBuildInfoFile flag
set tsBuildInfoFile [readFlagValue $finalArgs "--tsBuildInfoFile"]
if {$tsBuildInfoFile ne ""} {
    set dir [file dirname [file normalize $tsBuildInfoFile]]
    if {![file exists $dir]} {
        file mkdir $dir
    }
}

# Acquire lock
set lockHandle [acquireLocalHeavyCheckLockSync [list cwd [pwd] env [array get env] toolName "tsgo"]]

# Try block simulation using catch
if {[catch {
    # Execute tsgo with finalArgs
    # Note: Tcl's exec behaves differently than Node.js spawnSync
    # This is a simplified version assuming tsgo can be executed directly
    set cmd [concat $tsgoPath $finalArgs]
    set result [exec {*}$cmd]
    puts $result
    set exitCode 0
} errorResult]} {
    # Error occurred during execution
    puts stderr "Error executing tsgo: $errorResult"
    set exitCode 1
} finally {
    # Release lock regardless of outcome
    releaseLock
}

# Exit with appropriate code
exit $exitCode
