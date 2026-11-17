#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "079ddd2dd607294e434514031062ff805056aacb8f5d39531ccd7dd8ed6157f0", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "tcl"}
# extract-tiktok-streamlink.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Bounded fallback used by the enhanced extractor. Output is normalized again
# by tiktok-get-stream.js; standalone success must remain URL-only unless
# --json is requested. Exit 75 means preflight overload.

package require json
package require platform

proc emit_json {args} {
    set keys [list success method username url quality author title error timestamp status]
    set payload [dict create]
    
    foreach key $keys value $args {
        if {$value ne ""} {
            if {$key eq "success"} {
                dict set payload $key [string tolower $value] 
            } else {
                dict set payload $key $value
            }
        }
    }
    
    puts [::json::write object {*}[dict get $payload]]
}

proc get_load_avg {} {
    # Linux-style load average from /proc/loadavg
    if {[file exists "/proc/loadavg"]} {
        set fp [open "/proc/loadavg" r]
        set line [gets $fp]
        close $fp
        set loads [split $line " "]
        return [lindex $loads 0]
    } elseif {[catch {exec uptime} result]} {
        # Fallback: assume 0.0 load if we can't determine it
        return 0.0
    } else {
        # Parse various uptime formats
        if {[regexp {load averages?: ([0-9.]+)} $result -> load]} {
            return $load
        } elseif {[regexp {([0-9.]+)(?:,|$)} $result -> load]} {
            return $load
        } else {
            return 0.0
        }
    }
}

proc get_cpu_count {} {
    set count [::platform::generic]
    if {[regexp {.*-([0-9]+)$} $count -> cores]} {
        return $cores
    } else {
        # Fallback to 1 CPU if we can't determine
        return 1
    }
}

proc validate_username {username} {
    if {[regexp {^[A-Za-z0-9._]{1,24}$} $username]} {
        return 1
    } else {
        return 0
    }
}

proc validate_quality {quality} {
    set valid_qualities [list best worst original 1080p60 720p60 720p 540p 360p auto]
    if {[lsearch -exact $valid_qualities $quality] != -1} {
        return 1
    } else {
        return 0
    }
}

proc which {prog} {
    if {[catch {exec which $prog} result]} {
        return ""
    } else {
        return $result
    }
}

proc format_timestamp {} {
    return [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]
}

# Main script starts here

if {$argc < 1} {
    puts stderr "Usage: $argv0 <username> \[quality\] \[--json\]"
    exit 64
}

set USERNAME [string trimleft [lindex $argv 0] "@"]
set QUALITY [expr {$argc >= 2 ? [lindex $argv 1] : "best"}]
set JSON_FLAG [expr {$argc >= 3 ? [lindex $argv 2] : ""}]
set TIMESTAMP [format_timestamp]

if {![validate_username $USERNAME]} {
    puts stderr "Invalid TikTok username"
    exit 64
}

if {![validate_quality $QUALITY]} {
    puts stderr "Invalid stream quality"
    exit 64
}

# Check system load
set LOAD_PER_CPU 0.0
if {[catch {
    set load_avg [get_load_avg]
    set cpu_count [get_cpu_count]
    if {$cpu_count <= 0} {set cpu_count 1}
    set LOAD_PER_CPU [expr {$load_avg / $cpu_count}]
}]} {
    set LOAD_PER_CPU 0.0
}

set MAX_LOAD [expr {[info exists env(TIKTOK_MAX_LOAD_PER_CPU)] ? $env(TIKTOK_MAX_LOAD_PER_CPU) : 1.5}]

if {[expr {$LOAD_PER_CPU > $MAX_LOAD}]} {
    emit_json false streamlink $USERNAME "" $QUALITY "" "" "host overloaded" $TIMESTAMP overloaded
    exit 75
}

# Check if streamlink is installed
if {[which streamlink] eq ""} {
    emit_json false streamlink $USERNAME "" $QUALITY "" "" "streamlink not installed" $TIMESTAMP dependency_missing
    exit 2
}

set LIVE_URL "https://www.tiktok.com/@${USERNAME}/live"

# Set selector based on quality
switch -- $QUALITY {
    original {
        set SELECTOR "origin,uhd_60,hd_60,hd,sd,ld,best,worst"
    }
    auto {
        set SELECTOR "best,origin,uhd_60,hd_60,hd,sd,ld,worst"
    }
    1080p60 {
        set SELECTOR "uhd_60,hd_60,hd,sd,ld,worst"
    }
    720p60 {
        set SELECTOR "hd_60,hd,sd,ld,worst"
    }
    720p {
        set SELECTOR "hd,sd,ld,worst"
    }
    540p {
        set SELECTOR "sd,ld,worst"
    }
    360p {
        set SELECTOR "ld,worst"
    }
    default {
        set SELECTOR $QUALITY
    }
}

# Try to get JSON output first
if {[catch {exec streamlink --json $LIVE_URL $SELECTOR} OUTPUT]} {
    set EXIT_CODE 1
} else {
    set EXIT_CODE 0
}

if {$EXIT_CODE != 0 || $OUTPUT eq ""} {
    # Try getting just the stream URL
    if {[catch {exec streamlink --stream-url $LIVE_URL $SELECTOR} URL]} {
        set URL ""
    }
    
    if {$URL eq ""} {
        emit_json false streamlink $USERNAME "" $QUALITY "" "" "streamlink failed or no stream found" $TIMESTAMP offline
        exit 1
    }
    
    if {$JSON_FLAG eq "--json"} {
        emit_json true streamlink $USERNAME $URL $QUALITY "" "" "" $TIMESTAMP live
    } else {
        puts $URL
    }
    exit 0
}

# Parse the JSON output
if {[catch {
    set data [::json::json2dict $OUTPUT]
    set url [dict get $data url]
    set streams [dict get $data streams]
    
    if {$url eq "" && [dict size $streams] > 0} {
        foreach key [concat best worst [dict keys $streams]] {
            if {[dict exists $streams $key]} {
                set stream_info [dict get $streams $key]
                if {[dict exists $stream_info url]} {
                    set url [dict get $stream_info url]
                    break
                }
            }
        }
    }
    
    set metadata [dict get $data metadata]
    set author [dict get $metadata author]
    set title [dict get $metadata title]
    
    set PARSED [dict create url $url author $author title $title]
} parsed_result]} {
    emit_json false streamlink $USERNAME "" $QUALITY "" "" "invalid streamlink JSON" $TIMESTAMP technical_error
    exit 2
}

set URL [dict get $PARSED url]
set AUTHOR [dict get $PARSED author]
set TITLE [dict get $PARSED title]

if {$URL eq ""} {
    emit_json false streamlink $USERNAME "" $QUALITY $AUTHOR $TITLE "could not extract stream URL" $TIMESTAMP offline
    exit 1
}

if {$JSON_FLAG eq "--json"} {
    emit_json true streamlink $USERNAME $URL $QUALITY $AUTHOR $TITLE "" $TIMESTAMP live
} else {
    puts $URL
}
