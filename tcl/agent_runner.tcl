#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "513eaa61a56b268b8896ac0dbdf02dce58a9d1fe44b5c84fc7aaa60ba68bec56", "source_sha256": "bb3a3622a1b49888ef51f2b6fac687955ed97e97b6ee7a16d4e47117a764be29", "target_language": "tcl"}
# agent_runner.py — portiert nach tcl
# Quelle: python, workspace@local:skills/sub-agents-utils/scripts/agent_runner.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Run a gateway-only OpenClaw agent turn for a porting task.

package require json
package require uuid

proc allowed_models {config_path} {
    set models [dict create]
    
    if {[file exists $config_path]} {
        set fp [open $config_path r]
        set content [read $fp]
        close $fp
        
        if {[catch {::json::json2dict $content} config]} {
            return $models
        }
        
        if {[dict exists $config agents defaults]} {
            set defaults [dict get $config agents defaults]
            
            if {[dict exists $defaults models]} {
                set model_list [dict get $defaults models]
                if {[llength $model_list] > 0} {
                    foreach m $model_list {
                        dict set models $m 1
                    }
                }
            }
            
            if {[dict exists $defaults model]} {
                set selected [dict get $defaults model]
                if {[string length $selected] > 0} {
                    dict set models $selected 1
                } elseif {[dict size $selected] > 0} {
                    # Handle dict case with primary and fallbacks
                    if {[dict exists $selected primary]} {
                        set primary [dict get $selected primary]
                        if {[string length $primary] > 0} {
                            dict set models $primary 1
                        }
                    }
                    if {[dict exists $selected fallbacks]} {
                        set fallbacks [dict get $selected fallbacks]
                        foreach fb $fallbacks {
                            if {[string length $fb] > 0} {
                                dict set models $fb 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    return [dict keys $models]
}

proc run {task model timeout} {
    # Validate task
    set task [string trim $task]
    if {[string length $task] == 0 || [string length $task] > 500} {
        error "task must contain 1–500 characters"
    }
    
    # Validate timeout
    if {$timeout < 1 || $timeout > 7200} {
        error "timeout must be between 1 and 7200 seconds"
    }
    
    # Get config path
    set config_env [getenv OPENCLAW_CONFIG ""]
    if {$config_env eq ""} {
        set home_dir [getenv HOME [pwd]]
        set config_path [file join $home_dir .openclaw openclaw.json]
    } else {
        set config_path $config_env
    }
    
    # Check if model is allowed
    set allowed [allowed_models $config_path]
    if {$model ni $allowed} {
        error "model is not in the configured OpenClaw model allowlist"
    }
    
    # Parse model provider/id
    set parts [split $model "/"]
    if {[llength $parts] != 2 || [lindex $parts 0] eq "" || [lindex $parts 1] eq ""} {
        error "model must have provider/model form"
    }
    set provider [lindex $parts 0]
    set model_id [lindex $parts 1]
    
    # Generate run ID
    set run_id [::uuid::uuid generate]
    
    # Prepare parameters
    set params [dict create \
        message $task \
        provider $provider \
        model $model_id \
        sessionKey "agent:main:abstraction-runner:$run_id" \
        idempotencyKey $run_id \
        timeout $timeout \
        deliver false]
    
    # Convert to JSON
    set params_json [::json::dict2json $params]
    
    # Build command
    set command [list openclaw gateway call agent \
        --params $params_json \
        --expect-final --json \
        --timeout [expr {($timeout + 10) * 1000}]]
    
    # Execute command with timeout
    if {[catch {
        set result [exec {*}$command]
    } error]} {
        puts stderr $error
        return 1
    }
    
    # Parse response
    if {[catch {::json::json2dict $result} response]} {
        error "OpenClaw returned invalid JSON"
    }
    
    if {![dict exists $response status] || [dict get $response status] ne "ok"} {
        error "OpenClaw did not return a completed agent result"
    }
    
    if {![dict exists $response result]} {
        error "OpenClaw returned no agent result"
    }
    
    set agent_result [dict get $response result]
    
    # Check meta info
    if {[dict exists $agent_result meta]} {
        set meta [dict get $agent_result meta]
        if {[dict exists $meta aborted] && [dict get $meta aborted]} {
            error "OpenClaw agent execution did not complete successfully"
        }
        if {[dict exists $meta error] && [dict get $meta error]} {
            error "OpenClaw agent execution did not complete successfully"
        }
    }
    
    # Check payloads
    set payloads {}
    if {[dict exists $agent_result payloads]} {
        set payloads [dict get $agent_result payloads]
    }
    
    set has_valid_text 0
    foreach item $payloads {
        if {[dict exists $item isError] && [dict get $item isError]} {
            error "OpenClaw agent returned an error"
        }
        if {[dict exists $item text]} {
            set text [dict get $item text]
            if {[string length [string trim $text]] > 0} {
                set has_valid_text 1
            }
        }
    }
    
    if {!$has_valid_text} {
        error "OpenClaw agent returned no text"
    }
    
    puts $result
    return 0
}

proc main {} {
    global argv
    
    # Parse arguments manually since we don't have argparse
    set task ""
    set model ""
    set timeout 1800
    set gateway_only 0
    
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        
        switch -exact -- $arg {
            --task {
                if {$i >= [llength $argv]} {
                    puts stderr "Missing value for --task"
                    return 1
                }
                set task [lindex $argv $i]
                incr i
            }
            --model {
                if {$i >= [llength $argv]} {
                    puts stderr "Missing value for --model"
                    return 1
                }
                set model [lindex $argv $i]
                incr i
            }
            --timeout {
                if {$i >= [llength $argv]} {
                    puts stderr "Missing value for --timeout"
                    return 1
                }
                set timeout [lindex $argv $i]
                incr i
            }
            --gateway-only {
                set gateway_only 1
            }
            default {
                puts stderr "Unknown argument: $arg"
                return 1
            }
        }
    }
    
    # Check required arguments
    if {$task eq ""} {
        puts stderr "Missing required argument --task"
        return 1
    }
    if {$model eq ""} {
        puts stderr "Missing required argument --model"
        return 1
    }
    
    if {!$gateway_only} {
        puts stderr "agent_runner: no worker/relay transport configured; gateway-only requires --gateway-only"
        return 1
    }
    
    if {[catch {
        return [run $task $model $timeout]
    } error]} {
        puts stderr "agent_runner: $error"
        return 1
    }
}

# Helper proc to get environment variable with default
proc getenv {name {default ""}} {
    if {[info exists ::env($name)]} {
        return $::env($name)
    } else {
        return $default
    }
}

# Load required packages
if {[catch {package require json}]} {
    puts stderr "Required package 'json' not found"
    exit 1
}
if {[catch {package require uuid}]} {
    puts stderr "Required package 'uuid' not found"
    exit 1
}

# Call main function
exit [main()]
