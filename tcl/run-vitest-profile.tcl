#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "09db0262f839c265c4ea5361e8563375325a0803a6ce58677e674738bb0b6d18", "source_sha256": "047c165dbfdfa71d13cb6cf0b23d2b60439a2e0ec23e6951411b25fd91c6dcab", "target_language": "tcl"}
# run-vitest-profile.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest-profile.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of run-vitest-profile.mjs

package require Tcl 8.6

# Helper functions to mimic Node.js behavior
proc path_resolve {paths} {
    return [file normalize [join $paths "/"]]
}

proc path_join {paths} {
    return [join $paths "/"]
}

proc os_tmpdir {} {
    global tcl_platform
    if {$tcl_platform(platform) eq "windows"} {
        return $::env(TEMP)
    } else {
        return "/tmp"
    }
}

proc fs_mkdtemp_sync {prefix} {
    set tmpdir [os_tmpdir]
    set template "${tmpdir}/${prefix}XXXXXX"
    # Create temporary directory - simplified version
    set dir [exec mktemp -d $template]
    return $dir
}

proc fs_mkdir_sync {dir} {
    file mkdir $dir
}

proc spawn_sync {command args} {
    set options [dict create]
    set stdio "inherit"
    set shell false
    
    # Parse options
    while {[llength $args] > 0} {
        set opt [lindex $args 0]
        switch $opt {
            "-stdio" {
                set stdio [lindex $args 1]
                set args [lrange $args 2 end]
            }
            "-shell" {
                set shell [lindex $args 1]
                set args [lrange $args 2 end]
            }
            "-env" {
                # Environment handling would go here
                set args [lrange $args 2 end]
            }
            default {
                break
            }
        }
    }
    
    # Execute command
    if {$stdio eq "inherit"} {
        if {[catch {exec $command {*}$args} result]} {
            return [dict create error $result status 1]
        } else {
            return [dict create status 0]
        }
    } else {
        if {[catch {exec $command {*}$args} result]} {
            return [dict create error $result status 1]
        } else {
            return [dict create stdout $result status 0]
        }
    }
}

proc format_error_message {error} {
    return "Error: $error"
}

proc parse_args {argv} {
    set args [dict create mode "" outputDir ""]
    
    # Check environment variable
    if {[info exists ::env(OPENCLAW_VITEST_PROFILE_DIR)]} {
        set env_dir [string trim $::env(OPENCLAW_VITEST_PROFILE_DIR)]
        if {$env_dir ne ""} {
            dict set args outputDir $env_dir
        }
    }
    
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        if {$arg eq "--output-dir"} {
            incr i
            if {$i < [llength $argv]} {
                dict set args outputDir [lindex $argv $i]
            } else {
                dict set args outputDir ""
            }
        } elseif {[dict get $args mode] eq ""} {
            dict set args mode $arg
        } else {
            error "Unknown argument: $arg"
        }
        incr i
    }
    
    set mode [dict get $args mode]
    if {$mode ne "main" && $mode ne "runner"} {
        error "Usage: tclsh run-vitest-profile.tcl <main|runner> \[--output-dir <dir>\]"
    }
    
    return $args
}

proc resolve_vitest_profile_dir {mode outputDir} {
    if {$outputDir ne ""} {
        return [path_resolve [list $outputDir]]
    }
    
    return [fs_mkdtemp_sync "openclaw-vitest-${mode}-profile-"]
}

proc build_vitest_profile_command {mode outputDir} {
    if {$mode eq "main"} {
        return [dict create \
            command $::tcl_platform(executable) \
            args [list \
                "--cpu-prof" \
                "--cpu-prof-dir=$outputDir" \
                "./node_modules/vitest/vitest.mjs" \
                "run" \
                "--config" \
                "test/vitest/vitest.unit.config.ts" \
                "--no-file-parallelism"]]
    }
    
    return [dict create \
        command "pnpm" \
        args [list \
            "vitest" \
            "run" \
            "--config" \
            "test/vitest/vitest.unit.config.ts" \
            "--no-file-parallelism" \
            "--execArgv=--cpu-prof" \
            "--execArgv=--cpu-prof-dir=$outputDir" \
            "--execArgv=--heap-prof" \
            "--execArgv=--heap-prof-dir=$outputDir"]]
}

proc main {} {
    # Get command line arguments (skip script name)
    set argv [lassign $::argv script_name]
    
    set parsed [parse_args $argv]
    set mode [dict get $parsed mode]
    set outputDir [dict get $parsed outputDir]
    
    set outputDir [resolve_vitest_profile_dir $mode $outputDir]
    fs_mkdir_sync $outputDir
    
    set plan [build_vitest_profile_command $mode $outputDir]
    
    set command [dict get $plan command]
    set args [dict get $plan args]
    
    puts "\[run-vitest-profile\] writing $mode profiles to $outputDir"
    
    # Determine if we need shell execution (Windows with pnpm)
    global tcl_platform
    set use_shell [expr {$tcl_platform(platform) eq "windows" && $command eq "pnpm"}]
    
    set result [spawn_sync $command {*}$args -stdio "inherit" -shell $use_shell]
    
    if {[dict exists $result error]} {
        error [dict get $result error]
    }
    
    set status [dict get $result status]
    if {$status eq ""} {
        exit 1
    } else {
        exit $status
    }
}

# Check if this script is being run directly
if {[info script] eq $::argv0} {
    if {[catch {main} error]} {
        puts stderr [format_error_message $error]
        exit 1
    }
}
