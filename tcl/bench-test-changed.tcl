#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "abbc6e85bca25c67e409770db0482dc94a8531c3fc5b6c40c3c88c880616351b", "source_sha256": "671775b966561d4c6120ff043a4bb70e355d548215a9adf110f38e78918fc1e2", "target_language": "tcl"}
# bench-test-changed.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bench-test-changed.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Helper function to join paths
proc path_join {args} {
    return [join $args "/"]
}

# Helper function to resolve path
proc path_resolve {path} {
    # Simplified resolution - in real scenario would need proper implementation
    return [file normalize $path]
}

# Parse command line arguments
proc parseArgs {argv} {
    global argc argv0
    
    set opts(cwd) [pwd]
    set opts(ref) "origin/main"
    set opts(rss) [expr {[platform] eq "darwin"}]
    set opts(mode) "ref"
    set opts(maxWorkers) ""
    
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        
        switch -- $arg {
            "--cwd" {
                if {$i < [llength $argv]} {
                    set opts(cwd) [lindex $argv $i]
                    incr i
                }
            }
            "--ref" {
                if {$i < [llength $argv]} {
                    set opts(ref) [lindex $argv $i]
                    incr i
                }
            }
            "--max-workers" {
                if {$i < [llength $argv]} {
                    set val [lindex $argv $i]
                    if {[string is double $val] && $val >= 1} {
                        set opts(maxWorkers) [expr {int($val)}]
                    }
                    incr i
                }
            }
            "--no-rss" {
                set opts(rss) false
            }
            "--worktree" {
                set opts(mode) "worktree"
            }
            default {
                # Ignore unknown options as per original behavior
            }
        }
    }
    
    set opts(cwd) [path_resolve $opts(cwd)]
    return [array get opts]
}

# Quote argument for shell execution
proc quoteArg {arg} {
    if {[regexp {[^A-Za-z0-9_./:-]} $arg]} {
        # Simple quoting - replace with proper shell escaping if needed
        return "'$arg'"
    }
    return $arg
}

# Run git command and return list of lines
proc runGitList {args cwd} {
    set cmd [list exec git {*}$args]
    if {[catch {exec git {*}$args 2>@1} result]} {
        error "git [join $args " "] failed: $result"
    }
    
    set lines {}
    foreach line [split $result "\n"] {
        set trimmed [string trim $line]
        if {[string length $trimmed] > 0} {
            lappend lines $trimmed
        }
    }
    return $lines
}

# List changed paths based on mode
proc listChangedPaths {opts_array} {
    upvar 1 $opts_array opts
    
    if {$opts(mode) eq "worktree"} {
        set diff_files [runGitList [list "diff" "--name-only" "--relative" "HEAD" "--"] $opts(cwd)]
        set untracked_files [runGitList [list "ls-files" "--others" "--exclude-standard"] $opts(cwd)]
        
        set all_files [concat $diff_files $untracked_files]
        set unique_files [lsort -unique $all_files]
        return $unique_files
    } else {
        return [runGitList [list "diff" "--name-only" "$opts(ref)...HEAD"] $opts(cwd)]
    }
}

# Parse maximum RSS from output
proc parseMaxRssKb {output} {
    if {[regexp {([0-9]+)\s+maximum resident set size} $output match kb]} {
        return $kb
    }
    return ""
}

# Format RSS value
proc formatRss {valueKb} {
    if {$valueKb eq ""} {
        return "n/a"
    }
    set mb [expr {$valueKb / 1024.0}]
    return [format "%.1fMB" $mb]
}

# Format milliseconds
proc formatMs {ms} {
    if {$ms < 1000} {
        return [format "%.2fms" $ms]
    } elseif {$ms < 60000} {
        set seconds [expr {$ms / 1000.0}]
        return [format "%.2fs" $seconds]
    } else {
        set minutes [expr {$ms / 60000.0}]
        return [format "%.2fm" $minutes]
    }
}

# Run benchmark command
proc runBenchCommand {params_array} {
    upvar 1 $params_array params
    
    set env_vars [array get env]
    
    if {[info exists params(maxWorkers)] && $params(maxWorkers) ne ""} {
        set env_vars [dict merge $env_vars [dict create OPENCLAW_VITEST_MAX_WORKERS $params(maxWorkers)]]
    }
    
    set startedAt [clock microseconds]
    
    if {$params(rss)} {
        set command [concat "/usr/bin/time" "-l" $params(command)]
    } else {
        set command $params(command)
    }
    
    set executable [lindex $command 0]
    set cmd_args [lrange $command 1 end]
    
    if {[catch {exec {*}[list $executable {*}$cmd_args]} stdout]} {
        set stderr $::errorInfo
        set status 1
    } else {
        set stderr ""
        set status 0
    }
    
    set elapsedMs [expr {([clock microseconds] - $startedAt) / 1000.0}]
    set output "$stdout$stderr"
    
    set maxRssKb ""
    if {$params(rss)} {
        set maxRssKb [parseMaxRssKb $output]
    }
    
    return [list \
        elapsedMs $elapsedMs \
        maxRssKb $maxRssKb \
        status $status \
        output $output]
}

# Print run summary
proc printRunSummary {label result_dict} {
    set elapsedMs [dict get $result_dict elapsedMs]
    set maxRssKb [dict get $result_dict maxRssKb]
    
    set label_padded [format "%-8s" $label]
    set wall_time [format "%9s" [formatMs $elapsedMs]]
    set rss_usage [format "%9s" [formatRss $maxRssKb]]
    
    puts "${label_padded} wall=${wall_time} rss=${rss_usage}"
}

# Main execution
proc main {} {
    global argv
    
    # Parse arguments
    array set opts [parseArgs $argv]
    
    # Get changed paths
    set changedPaths [listChangedPaths opts]
    
    if {[llength $changedPaths] == 0} {
        if {$opts(mode) eq "worktree"} {
            puts "\[bench-test-changed\] no changed paths in worktree"
        } else {
            puts "\[bench-test-changed\] no changed paths for $opts(ref)...HEAD"
        }
        exit 0
    }
    
    # Print mode info
    if {$opts(mode) eq "worktree"} {
        puts "\[bench-test-changed\] mode=worktree"
    } else {
        puts "\[bench-test-changed\] ref=$opts(ref)"
    }
    
    puts "\[bench-test-changed\] changed paths:"
    foreach changedPath $changedPaths {
        puts "- $changedPath"
    }
    
    # Prepare commands
    if {$opts(mode) eq "worktree"} {
        set routedCommand [concat [info nameofexecutable] "scripts/test-projects.mjs" $changedPaths]
    } else {
        set routedCommand [concat [info nameofexecutable] "scripts/test-projects.mjs" "--changed" $opts(ref)]
    }
    
    set rootCommand [concat [info nameofexecutable] "scripts/run-vitest.mjs" "run" "--config" "vitest.config.ts" $changedPaths]
    
    # Print and run routed command
    set routedCmdStr ""
    foreach arg $routedCommand {
        append routedCmdStr " [quoteArg $arg]"
    }
    puts "\[bench-test-changed\] routed:${routedCmdStr}"
    
    array set routedParams [list \
        command $routedCommand \
        cwd $opts(cwd) \
        rss $opts(rss)]
    
    if {$opts(maxWorkers) ne ""} {
        set routedParams(maxWorkers) $opts(maxWorkers)
    }
    
    array set routed [runBenchCommand routedParams]
    
    if {$routed(status) != 0} {
        puts -nonewline stderr $routed(output)
        exit $routed(status)
    }
    
    # Print and run root command
    set rootCmdStr ""
    foreach arg $rootCommand {
        append rootCmdStr " [quoteArg $arg]"
    }
    puts "\[bench-test-changed\] root:  ${rootCmdStr}"
    
    array set rootParams [list \
        command $rootCommand \
        cwd $opts(cwd) \
        rss $opts(rss)]
    
    if {$opts(maxWorkers) ne ""} {
        set rootParams(maxWorkers) $opts(maxWorkers)
    }
    
    array set root [runBenchCommand rootParams]
    
    if {$root(status) != 0} {
        puts -nonewline stderr $root(output)
        exit $root(status)
    }
    
    # Print summaries
    printRunSummary "routed" [array get routed]
    printRunSummary "root" [array get root]
    
    set deltaWall [expr {$root(elapsedMs) - $routed(elapsedMs)}]
    set deltaRss "n/a"
    if {$routed(maxRssKb) ne "" && $root(maxRssKb) ne ""} {
        set deltaRss [formatRss [expr {$root(maxRssKb) - $routed(maxRssKb)}]]
    }
    
    puts "\[bench-test-changed\] delta wall=[formatMs $deltaWall] rss=$deltaRss"
}

# Platform detection helper
proc platform {} {
    switch $::tcl_platform(platform) {
        "unix" {
            if {$::tcl_platform(os) eq "Darwin"} {
                return "darwin"
            }
        }
    }
    return $::tcl_platform(platform)
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main
}
