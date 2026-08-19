#!/usr/bin/env tclsh8.6
# extract-tiktok-streamlink.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Bounded fallback used by the enhanced extractor. Output is normalized again
# by tiktok-get-stream.js; standalone success must remain URL-only unless
# --json is requested. Exit 75 means preflight overload.
if {$argc < 1} {
    puts stderr "Invalid TikTok username"
    exit 64
}

set USERNAME [string trimleft [lindex $argv 0] "@"]
set QUALITY [expr {$argc >= 2 ? [lindex $argv 1] : "best"}]
set JSON_FLAG [expr {$argc >= 3 ? [lindex $argv 2] : ""}]
set TIMESTAMP [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]

proc emit_json {args} {
    set keys [list success method username url quality author title error timestamp status]
    array set payload {}
    foreach key $keys value $args {
        if {$value ne ""} {
            set payload($key) $value
        }
    }
    if {[info exists payload(success)]} {
        set payload(success) [string equal [string tolower $payload(success)] "true"]
    }
    puts stderr [::json::write object {*}[array get payload]]
}

# Validate username
if {![regexp {^[A-Za-z0-9._]{1,24}$} $USERNAME]} {
    puts stderr "Invalid TikTok username"
    exit 64
}

# Validate quality
set valid_qualities [list best worst original 1080p60 720p60 720p 540p 360p auto]
if {$QUALITY ni $valid_qualities} {
    puts stderr "Invalid stream quality"
    exit 64
}

# Check system load
if {[catch {exec uname}]} {
    # Not Unix-like, skip load check
} else {
    if {[catch {exec cat /proc/loadavg} loadavg_data]} {
        # Cannot read loadavg, assume overloaded
        set LOAD_PER_CPU 999
    } else {
        set load_line [lindex [split $loadavg_data "\n"] 0]
        set load_1min [lindex [split $load_line] 0]
        set cpu_count [exec nproc]
        set LOAD_PER_CPU [expr {$load_1min / max(1, $cpu_count)}]
    }
    
    set MAX_LOAD [expr {[info exists env(TIKTOK_MAX_LOAD_PER_CPU)] ? $env(TIKTOK_MAX_LOAD_PER_CPU) : 1.5}]
    if {$LOAD_PER_CPU > $MAX_LOAD} {
        emit_json false streamlink $USERNAME "" $QUALITY "" "" "host overloaded" $TIMESTAMP "overloaded"
        exit 75
    }
}

# Check if streamlink exists
if {[catch {exec which streamlink}]} {
    emit_json false streamlink $USERNAME "" $QUALITY "" "" "streamlink not installed" $TIMESTAMP "dependency_missing"
    exit 2
}

set LIVE_URL "https://www.tiktok.com/@${USERNAME}/live"

# Set selector based on quality
switch -- $QUALITY {
    original { set SELECTOR "origin,uhd_60,hd_60,hd,sd,ld,best,worst" }
    auto { set SELECTOR "best,origin,uhd_60,hd_60,hd,sd,ld,worst" }
    1080p60 { set SELECTOR "uhd_60,hd_60,hd,sd,ld,worst" }
    720p60 { set SELECTOR "hd_60,hd,sd,ld,worst" }
    720p { set SELECTOR "hd,sd,ld,worst" }
    540p { set SELECTOR "sd,ld,worst" }
    360p { set SELECTOR "ld,worst" }
    default { set SELECTOR $QUALITY }
}

# Try to get JSON output first
if {[catch {exec streamlink --json $LIVE_URL $SELECTOR} OUTPUT]} {
    set EXIT_CODE 1
} else {
    set EXIT_CODE 0
}

if {$EXIT_CODE != 0 || $OUTPUT eq ""} {
    if {[catch {exec streamlink --stream-url $LIVE_URL $SELECTOR} URL]} {
        emit_json false streamlink $USERNAME "" $QUALITY "" "" "streamlink failed or no stream found" $TIMESTAMP "offline"
        exit 1
    }
    if {$URL eq ""} {
        emit_json false streamlink $USERNAME "" $QUALITY "" "" "streamlink failed or no stream found" $TIMESTAMP "offline"
        exit 1
    }
    if {$JSON_FLAG eq "--json"} {
        emit_json true streamlink $USERNAME $URL $QUALITY "" "" "" $TIMESTAMP "live"
    } else {
        puts $URL
    }
    exit 0
}

# Parse JSON output
if {[catch {::json::json2dict $OUTPUT} data]} {
    emit_json false streamlink $USERNAME "" $QUALITY "" "" "invalid streamlink JSON" $TIMESTAMP "technical_error"
    exit 2
}

set url ""
array set streams {}
if {[dict exists $data streams]} {
    set streams_dict [dict get $data streams]
    if {[dict exists $streams_dict best]} {
        set best_stream [dict get $streams_dict best]
        if {[dict exists $best_stream url]} {
            set url [dict get $best_stream url]
        }
    }
    if {$url eq ""} {
        dict for {key value} $streams_dict {
            if {[dict exists $value url]} {
                set url [dict get $value url]
                break
            }
        }
    }
}
if {$url eq "" && [dict exists $data url]} {
    set url [dict get $data url]
}

set author ""
set title ""
if {[dict exists $data metadata]} {
    set metadata [dict get $data metadata]
    if {[dict exists $metadata author]} {
        set author [dict get $metadata author]
    }
    if {[dict exists $metadata title]} {
        set title [dict get $metadata title]
    }
}

if {$url eq ""} {
    emit_json false streamlink $USERNAME "" $QUALITY $author $title "could not extract stream URL" $TIMESTAMP "offline"
    exit 1
}

if {$JSON_FLAG eq "--json"} {
    emit_json true streamlink $USERNAME $url $QUALITY $author $title "" $TIMESTAMP "live"
} else {
    puts $url
}
