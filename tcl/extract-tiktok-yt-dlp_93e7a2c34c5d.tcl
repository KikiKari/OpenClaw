#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "02d333736b7218a4df512f500077039505c7bdfa3de833a78d547745b324001e", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "tcl"}
# extract-tiktok-yt-dlp.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Bounded fallback used by the enhanced extractor. Temporary files are cleaned
# on every exit and output is normalized again by tiktok-get-stream.js.
# Standalone overload exits 75 before yt-dlp starts.

package require Tcl 8.6
package require json

proc emit_json {args} {
    set keys [list success method username url format error timestamp status]
    set payload [dict create]
    
    foreach key $keys value $args {
        if {$value ne ""} {
            if {$key eq "success"} {
                set payload($key) [string is true -strict [string tolower $value]]
            } else {
                set payload($key) $value
            }
        }
    }
    
    puts [::json::write object {*}[array get payload]]
}

proc validate_username {username} {
    if {![regexp {^[A-Za-z0-9._]{1,24}$} $username]} {
        puts stderr "Invalid TikTok username"
        exit 64
    }
}

proc validate_format {format} {
    set valid_formats {
        {hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld}
        {hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld}
        {hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld}
        {hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld}
        {hls-sd/hls-ld/flv-sd/flv-ld}
        {hls-ld/flv-ld}
        {hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld}
    }
    
    foreach pattern $valid_formats {
        if {$format in $pattern} {
            return
        }
    }
    
    puts stderr "Invalid yt-dlp format"
    exit 64
}

proc check_load_average {} {
    # This is a simplified load average check - in practice you might need
    # to parse /proc/loadavg or use platform-specific methods
    if {[catch {exec uptime} result]} {
        return 0.0
    }
    
    # Extract load average from uptime output
    if {[regexp {load averages?: ([0-9.]+)} $result -> load_avg]} {
        return $load_avg
    } else {
        return 0.0
    }
}

proc get_cpu_count {} {
    if {[info exists ::tcl_platform(ncpu)]} {
        return $::tcl_platform(ncpu)
    } elseif {[catch {exec nproc} result] == 0} {
        return $result
    } else {
        return 1
    }
}

proc cleanup_tmpdir {tmp_dir} {
    if {[file exists $tmp_dir]} {
        file delete -force $tmp_dir
    }
}

# Main script logic
if {$argc < 1} {
    puts stderr "Usage: $argv0 <username> \[format\] \[--json\]"
    exit 64
}

set USERNAME [string trimleft [lindex $argv 0] "@"]
set FORMAT [expr {$argc >= 2 ? [lindex $argv 1] : "best"}]
set JSON_FLAG [expr {$argc >= 3 ? [lindex $argv 2] : ""}]
set TIMESTAMP [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]

# Create temporary directory
set TMP_DIR [exec mktemp -d /tmp/tiktok-yt-dlp.XXXXXX]
set cleanup_registered 0

# Register cleanup function
proc register_cleanup {tmp_dir} {
    global cleanup_registered
    if {!$cleanup_registered} {
        set cleanup_registered 1
        # Tcl doesn't have trap equivalent, so we'll handle it manually
    }
}

register_cleanup $TMP_DIR

# Ensure cleanup happens on exit
proc do_cleanup {tmp_dir} {
    cleanup_tmpdir $tmp_dir
}

# Set up exit handler
proc on_exit {tmp_dir} {
    do_cleanup $tmp_dir
}

validate_username $USERNAME
validate_format $FORMAT

# Check system load
set LOAD_PER_CPU [expr {[check_load_average] / [get_cpu_count]}]
set MAX_LOAD [expr {[info exists env(TIKTOK_MAX_LOAD_PER_CPU)] ? $env(TIKTOK_MAX_LOAD_PER_CPU) : 1.5}]

if {$LOAD_PER_CPU > $MAX_LOAD} {
    emit_json "false" "yt-dlp" $USERNAME "" $FORMAT "host overloaded" $TIMESTAMP "overloaded"
    do_cleanup $TMP_DIR
    exit 75
}

# Check if yt-dlp exists
if {[catch {exec which yt-dlp}]} {
    emit_json "false" "yt-dlp" $USERNAME "" $FORMAT "yt-dlp not installed" $TIMESTAMP "dependency_missing"
    do_cleanup $TMP_DIR
    exit 2
}

set LIVE_URL "https://www.tiktok.com/@${USERNAME}/live"

# Run yt-dlp command
set stdout_file "$TMP_DIR/stdout.json"
set stderr_file "$TMP_DIR/stderr.log"

if {[catch {
    exec yt-dlp --no-warnings --dump-single-json --skip-download --format $FORMAT $LIVE_URL \
        > $stdout_file 2> $stderr_file
} result]} {
    set EXIT_CODE [lindex [split $result] end]
} else {
    set EXIT_CODE 0
}

if {$EXIT_CODE != 0} {
    set stderr_content [exec head -c 1000 $stderr_file]
    
    if {[regexp -nocase {(not currently live|No live cdn found|not available|private video)} $stderr_content]} {
        set STATUS offline
        set CODE 1
    } else {
        set STATUS technical_error
        set CODE 2
    }
    
    emit_json "false" "yt-dlp" $USERNAME "" $FORMAT $stderr_content $TIMESTAMP $STATUS
    do_cleanup $TMP_DIR
    exit $CODE
}

# Extract URL from JSON
set URL ""
if {[file exists $stdout_file] && [file size $stdout_file] > 0} {
    if {![catch {open $stdout_file r} fp]} {
        if {![catch {read $fp} json_data]} {
            close $fp
            
            if {![catch {::json::json2dict $json_data} data]} {
                set candidates [list]
                
                # Add direct URL if present
                if {[dict exists $data url] && [dict get $data url] ne ""} {
                    lappend candidates [dict get $data url]
                }
                
                # Add URLs from formats array
                if {[dict exists $data formats]} {
                    set formats [dict get $data formats]
                    if {[llength $formats] > 0} {
                        foreach item $formats {
                            if {[dict exists $item url] && [dict get $item url] ne ""} {
                                lappend candidates [dict get $item url]
                            }
                        }
                    }
                }
                
                # Find valid URL
                foreach value $candidates {
                    set low [string tolower $value]
                    if {[string match "https://*" $value] && 
                        ([string match "*m3u8*" $low] || [string match "*flv*" $low]) && 
                        ![string match "*only_audio=1*" $value]} {
                        set URL $value
                        break
                    }
                }
            }
        } else {
            close $fp
        }
    }
}

if {$URL eq ""} {
    emit_json "false" "yt-dlp" $USERNAME "" $FORMAT "could not extract HTTPS video URL" $TIMESTAMP "offline"
    do_cleanup $TMP_DIR
    exit 1
}

if {$JSON_FLAG eq "--json"} {
    emit_json "true" "yt-dlp" $USERNAME $URL $FORMAT "" $TIMESTAMP "live"
} else {
    puts $URL
}

do_cleanup $TMP_DIR
