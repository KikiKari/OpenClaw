#!/usr/bin/env tclsh
# wait-for-text.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/wait-for-text.sh
# auch in: OpenClaw@gateway2:skills/tmux/scripts/wait-for-text.sh
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr {Usage: wait-for-text.sh -t target -p pattern \[options\]

Poll a tmux pane for text and exit when found.

Options:
  -t, --target    tmux target \(session:window.pane\), required
  -p, --pattern   regex pattern to look for, required
  -F, --fixed     treat pattern as a fixed string \(grep -F\)
  -T, --timeout   seconds to wait \(integer, default: 15\)
  -i, --interval  poll interval in seconds \(default: 0.5\)
  -l, --lines     number of history lines to inspect \(integer, default: 1000\)
  -h, --help      show this help}
}

proc main {argv} {
    set target ""
    set pattern ""
    set grep_flag "-regexp"
    set timeout 15
    set interval 500
    set lines 1000

    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        switch -exact -- $arg {
            -t - --target {
                incr i
                if {$i >= [llength $argv]} {
                    puts stderr "Option $arg requires an argument"
                    usage
                    exit 1
                }
                set target [lindex $argv $i]
                incr i
            }
            -p - --pattern {
                incr i
                if {$i >= [llength $argv]} {
                    puts stderr "Option $p requires an argument"
                    usage
                    exit 1
                }
                set pattern [lindex $argv $i]
                incr i
            }
            -F - --fixed {
                set grep_flag "-literal"
                incr i
            }
            -T - --timeout {
                incr i
                if {$i >= [llength $argv]} {
                    puts stderr "Option $arg requires an argument"
                    usage
                    exit 1
                }
                set timeout [lindex $argv $i]
                incr i
            }
            -i - --interval {
                incr i
                if {$i >= [llength $argv]} {
                    puts stderr "Option $arg requires an argument"
                    usage
                    exit 1
                }
                set interval [expr {int([lindex $argv $i] * 1000)}]
                incr i
            }
            -l - --lines {
                incr i
                if {$i >= [llength $argv]} {
                    puts stderr "Option $arg requires an argument"
                    usage
                    exit 1
                }
                set lines [lindex $argv $i]
                incr i
            }
            -h - --help {
                usage
                exit 0
            }
            default {
                puts stderr "Unknown option: $arg"
                usage
                exit 1
            }
        }
    }

    if {$target eq "" || $pattern eq ""} {
        puts stderr "target and pattern are required"
        usage
        exit 1
    }

    if {![string is integer -strict $timeout] || $timeout < 0} {
        puts stderr "timeout must be an integer number of seconds"
        exit 1
    }

    if {![string is integer -strict $lines] || $lines < 0} {
        puts stderr "lines must be an integer"
        exit 1
    }

    # Check if tmux exists
    if {[catch {exec which tmux}]} {
        puts stderr "tmux not found in PATH"
        exit 1
    }

    set start_epoch [clock seconds]
    set deadline [expr {$start_epoch + $timeout}]

    while {true} {
        if {[catch {
            set pane_text [exec tmux capture-pane -p -J -t $target -S -$lines]
        } result]} {
            set pane_text ""
        }

        if {[string match "*\n*" $pane_text]} {
            set lines_list [split $pane_text "\n"]
        } else {
            set lines_list [list $pane_text]
        }

        set found 0
        foreach line $lines_list {
            if {$grep_flag eq "-literal"} {
                if {[string first $pattern $line] != -1} {
                    set found 1
                    break
                }
            } else {
                if {[regexp -- $pattern $line]} {
                    set found 1
                    break
                }
            }
        }

        if {$found} {
            exit 0
        }

        set now [clock seconds]
        if {$now >= $deadline} {
            puts stderr "Timed out after ${timeout}s waiting for pattern: $pattern"
            puts stderr "Last ${lines} lines from $target:"
            puts stderr $pane_text
            exit 1
        }

        after $interval
    }
}

main $argv
