#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "d40c794c5b307ccc0cf7c62cd8b3390cfbc35d600e8f9136210240bc9945cb6c", "source_sha256": "fb758d6839889536b8c614e3eeae8bf16b595283b7e0b680d6bbb9606448105e", "target_language": "tcl"}
# recover-orphaned-processes.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/recover-orphaned-processes.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Scan for orphaned coding agent processes after a gateway restart.
#
# Background coding agents (Claude Code, Codex CLI) spawned by the gateway
# can outlive the session that started them when the gateway restarts.
# This script finds them and reports their state.
#
# Usage:
#   recover-orphaned-processes.tcl
#
# Output: JSON object with `orphaned` array and `ts` timestamp.

package require json

proc usage {} {
    puts stderr {Usage: recover-orphaned-processes.tcl

Scans for likely orphaned coding agent processes and prints JSON.}
}

# Handle help arguments
if {[llength $argv] == 1 && ([lindex $argv 0] eq "--help" || [lindex $argv 0] eq "-h")} {
    usage
    exit 0
}

if {[llength $argv] > 0} {
    usage
    exit 2
}

# Check if node exists
if {![auto_execok node]} {
    set ts "unknown"
    if {[catch {exec date -u +%Y-%m-%dT%H:%M:%SZ} result]} {
        set ts "unknown"
    } else {
        set ts $result
    }
    puts [::json::encodeSafe [dict create error "node not found on PATH" orphaned [list] ts $ts]]
    exit 0
}

# Main logic in a separate procedure to allow local variables
proc main {} {
    set username [expr {[info exists ::env(USER)] ? $::env(USER) : ""}]
    if {$username eq "" && [info exists ::env(LOGNAME)]} {
        set username $::env(LOGNAME)
    }

    # Validate username
    if {$username ne "" && ![regexp {^[a-zA-Z0-9._-]+$} $username]} {
        set username ""
    }

    # Helper function to run commands safely
    proc runFile {file args} {
        if {[catch {exec $file {*}$args} result]} {
            if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
                # Return stdout even on error
                return [lindex $::errorCode 2]
            }
            return ""
        }
        return $result
    }

    # Resolve process start time
    proc resolveStarted {pid} {
        set started [string trim [runFile ps -o lstart= -p $pid]]
        return [expr {$started ne "" ? $started : "unknown"}]
    }

    # Resolve current working directory
    proc resolveCwd {pid} {
        global tcl_platform
        if {$tcl_platform(platform) eq "unix" && [file exists "/proc/$pid/cwd"]} {
            if {[catch {file link "/proc/$pid/cwd"} result]} {
                return "unknown"
            }
            return $result
        } else {
            if {[catch {exec lsof -a -d cwd -p $pid -Fn} result]} {
                if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
                    set result [lindex $::errorCode 2]
                } else {
                    return "unknown"
                }
            }
            if {[regexp {^n(.+)$} $result -> match]} {
                return $match
            }
            return "unknown"
        }
    }

    # Sanitize command line to remove sensitive information
    proc sanitizeCommand {cmd} {
        # Replace --token, --api-key, etc. values
        regsub -all {(--(?:token|api[-_]?key|password|secret|authorization)\s+)[^\s]+} $cmd {\1<redacted>} cmd
        # Replace token=value patterns
        regsub -all {((?:token|api[-_]?key|password|secret|authorization)=)[^\s]+} $cmd {\1<redacted>} cmd
        # Replace Bearer tokens
        regsub -all {(Bearer\s+)[A-Za-z0-9._~+/=-]+} $cmd {\1<redacted>} cmd
        return $cmd
    }

    # Find candidate PIDs using pgrep
    set pgrepUnavailable false
    set pgrepResult ""
    
    if {$username ne ""} {
        if {[catch {exec pgrep -u $username -f {codex|claude}} pgrepResult]} {
            if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "POSIX" && [lindex $::errorCode 1] eq "ENOENT"} {
                set pgrepUnavailable true
                set pgrepResult ""
            } else {
                # pgrep exit code 1 means no matches
                set pgrepResult ""
            }
        }
    } else {
        if {[catch {exec pgrep -f {codex|claude}} pgrepResult]} {
            if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "POSIX" && [lindex $::errorCode 1] eq "ENOENT"} {
                set pgrepUnavailable true
                set pgrepResult ""
            } else {
                set pgrepResult ""
            }
        }
    }

    # Parse candidate PIDs
    set candidatePids {}
    foreach line [split $pgrepResult \n] {
        set trimmed [string trim $line]
        if {$trimmed ne "" && [string is integer -strict $trimmed]} {
            lappend candidatePids $trimmed
        }
    }

    # Get process information
    set lines {}
    if {[llength $candidatePids] > 0} {
        if {[catch {exec ps -o pid=,command= -p [join $candidatePids ,]} result]} {
            if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
                set result [lindex $::errorCode 2]
            }
        }
        set lines [split $result \n]
    } elseif {$pgrepUnavailable && $username ne ""} {
        if {[catch {exec ps -U $username -o pid=,command=} result]} {
            if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
                set result [lindex $::errorCode 2]
            }
        }
        set lines [split $result \n]
    } elseif {$pgrepUnavailable} {
        if {[catch {exec ps -axo pid=,command=} result]} {
            if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
                set result [lindex $::errorCode 2]
            }
        }
        set lines [split $result \n]
    } else {
        set lines {}
    }

    # Filter patterns
    set includePattern {(?i)(codex|claude)}
    set excludePatterns {
        {(?i)openclaw-gateway}
        {(?i)signal-cli}
        {(?i)node_modules/\.bin/openclaw}
        {(?i)recover-orphaned-processes\.(sh|tcl)}
    }

    set orphaned {}
    set currentPid [pid]

    foreach rawLine $lines {
        set line [string trim $rawLine]
        if {$line eq ""} continue
        
        if {[regexp {^(\d+)\s+(.+)$} $line -> pidStr cmd]} {
            set pid [expr {int($pidStr)}]
            
            # Skip invalid PIDs and self
            if {$pid <= 0 || $pid == $currentPid} continue
            
            # Check include pattern
            if {![regexp $includePattern $cmd]} continue
            
            # Check exclude patterns
            set excluded false
            foreach pattern $excludePatterns {
                if {[regexp $pattern $cmd]} {
                    set excluded true
                    break
                }
            }
            if {$excluded} continue
            
            lappend orphaned [dict create \
                pid $pid \
                cmd [sanitizeCommand $cmd] \
                cwd [resolveCwd $pid] \
                started [resolveStarted $pid]]
        }
    }

    # Create and output JSON result
    set resultDict [dict create \
        orphaned $orphaned \
        ts [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
    
    puts [::json::encodeSafe $resultDict]
}

# Run main procedure
main
