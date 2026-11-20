#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "c2fa5a11777408264396b0fce1abcde8ffe47d08818d70d142c76ae2e2568112", "source_sha256": "4c4552ce0adb2754080969f00b761c1c118766771e0595b8c9b416ee0842fbae", "target_language": "tcl"}
# find-sessions.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr {Usage: find-sessions.sh \[-L socket-name|-S socket-path|-A\] \[-q pattern\]

List tmux sessions on a socket \(default tmux socket if none provided\).

Options:
  -L, --socket       tmux socket name \(passed to tmux -L\)
  -S, --socket-path  tmux socket path \(passed to tmux -S\)
  -A, --all          scan all sockets under OPENCLAW_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help}
}

proc list_sessions {label args} {
    set tmux_cmd [list tmux {*}$args]
    lappend tmux_cmd list-sessions -F {#{session_name}\t#{session_attached}\t#{session_created_string}}
    
    if {[catch {exec {*}$tmux_cmd 2>@1} sessions]} {
        puts stderr "No tmux server found on $label"
        return 1
    }
    
    global query
    if {$query ne ""} {
        # Filter sessions case-insensitively
        set filtered_sessions {}
        foreach line [split $sessions \n] {
            if {$line eq ""} continue
            if {[string match -nocase *$query* [lindex [split $line \t] 0]]} {
                lappend filtered_sessions $line
            }
        }
        set sessions [join $filtered_sessions \n]
    }
    
    if {$sessions eq ""} {
        puts "No sessions found on $label"
        return 0
    }
    
    puts "Sessions on $label:"
    foreach line [split $sessions \n] {
        if {$line eq ""} continue
        set parts [split $line \t]
        set name [lindex $parts 0]
        set attached [lindex $parts 1]
        set created [lindex $parts 2]
        set attached_label [expr {$attached == 1 ? "attached" : "detached"}]
        puts "  - $name ($attached_label, started $created)"
    }
    return 0
}

# Parse environment variables
set socket_dir_default "/tmp/openclaw-tmux-sockets"
if {[info exists ::env(TMPDIR)]} {
    set socket_dir_default "$::env(TMPDIR)/openclaw-tmux-sockets"
}
set socket_dir [expr {[info exists ::env(OPENCLAW_TMUX_SOCKET_DIR)] ? $::env(OPENCLAW_TMUX_SOCKET_DIR) : $socket_dir_default}]

# Initialize variables
set socket_name ""
set socket_path ""
set query ""
set scan_all false

# Parse command line arguments
set argv_copy $argv
while {[llength $argv_copy] > 0} {
    set arg [lindex $argv_copy 0]
    switch -exact -- $arg {
        {-L} - {--socket} {
            if {[llength $argv_copy] < 2} {
                puts stderr "Option $arg requires an argument"
                usage
                exit 1
            }
            set socket_name [lindex $argv_copy 1]
            set argv_copy [lrange $argv_copy 2 end]
        }
        {-S} - {--socket-path} {
            if {[llength $argv_copy] < 2} {
                puts stderr "Option $arg requires an argument"
                usage
                exit 1
            }
            set socket_path [lindex $argv_copy 1]
            set argv_copy [lrange $argv_copy 2 end]
        }
        {-A} - {--all} {
            set scan_all true
            set argv_copy [lrange $argv_copy 1 end]
        }
        {-q} - {--query} {
            if {[llength $argv_copy] < 2} {
                puts stderr "Option $arg requires an argument"
                usage
                exit 1
            }
            set query [lindex $argv_copy 1]
            set argv_copy [lrange $argv_copy 2 end]
        }
        {-h} - {--help} {
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

if {$scan_all && ($socket_name ne "" || $socket_path ne "")} {
    puts stderr "Cannot combine --all with -L or -S"
    exit 1
}

if {$socket_name ne "" && $socket_path ne ""} {
    puts stderr "Use either -L or -S, not both"
    exit 1
}

# Check if tmux is available
if {[catch {exec which tmux}]} {
    puts stderr "tmux not found in PATH"
    exit 1
}

if {$scan_all} {
    if {![file isdirectory $socket_dir]} {
        puts stderr "Socket directory not found: $socket_dir"
        exit 1
    }
    
    set sockets [glob -nocomplain -dir $socket_dir *]
    if {[llength $sockets] == 0} {
        puts stderr "No sockets found under $socket_dir"
        exit 1
    }
    
    set exit_code 0
    foreach sock $sockets {
        if {![file exists $sock] || ![file writable $sock]} continue
        if {[catch {list_sessions "socket path '$sock'" -S $sock} result]} {
            set exit_code 1
        }
    }
    exit $exit_code
}

set tmux_cmd [list tmux]
set socket_label "default socket"

if {$socket_name ne ""} {
    lappend tmux_cmd -L $socket_name
    set socket_label "socket name '$socket_name'"
} elseif {$socket_path ne ""} {
    lappend tmux_cmd -S $socket_path
    set socket_label "socket path '$socket_path'"
}

eval list_sessions [list $socket_label] [lrange $tmux_cmd 1 end]
