#!/usr/bin/env tclsh8.6
# extract-tiktok-yt-dlp.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require json

# Bounded fallback used by the enhanced extractor. Temporary files are cleaned
# on every exit and output is normalized again by tiktok-get-stream.js.
# Standalone overload exits 75 before yt-dlp starts.

set username [lindex $argv 0]
set format [expr {[llength $argv] >= 2 ? [lindex $argv 1] : "best"}]
set json_flag [expr {[llength $argv] >= 3 ? [lindex $argv 2] : ""}]

# Remove @ prefix if present
regsub {^@} $username {} username

# Generate timestamp
set timestamp [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]

# Create temporary directory
set tmp_dir [exec mktemp -d /tmp/tiktok-yt-dlp.XXXXXX]
set stdout_file "$tmp_dir/stdout.json"
set stderr_file "$tmp_dir/stderr.log"

# Cleanup function
proc cleanup {dir} {
    file delete -force $dir
}

# Register cleanup on exit
proc exit_handler {dir} {
    cleanup $dir
}
trace add execution exit enter [list exit_handler $tmp_dir]

proc emit_json {args} {
    set keys [list success method username url format error timestamp status]
    array set payload {}
    
    foreach key $keys value $args {
        if {$value ne ""} {
            set payload($key) $value
        }
    }
    
    if {[info exists payload(success)]} {
        set payload(success) [string equal [string tolower $payload(success)] "true"]
    }
    
    puts [::json::encode $payload]
}

# Validate username
if {![regexp {^[A-Za-z0-9._]{1,24}$} $username]} {
    puts stderr "Invalid TikTok username"
    exit 64
}

# Validate format
set valid_formats {
    {hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld}
    {hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld}
    {hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld}
    {hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld}
    {hls-sd/hls-ld/flv-sd/flv-ld}
    {hls-ld/flv-ld}
    {hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld}
}

set format_valid 0
foreach valid_format $valid_formats {
    if {$format eq $valid_format} {
        set format_valid 1
        break
    }
}

if {!$format_valid} {
    puts stderr "Invalid yt-dlp format"
    exit 64
}

# Check system load
set load_per_cpu [exec python3 -c {import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))}]
set max_load [expr {[info exists env(TIKTOK_MAX_LOAD_PER_CPU)] ? $env(TIKTOK_MAX_LOAD_PER_CPU) : 1.5}]

if {[exec python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)" $load_per_cpu $max_load] == 0} {
    emit_json false yt-dlp $username "" $format "host overloaded" $timestamp overloaded
    exit 75
}

# Check if yt-dlp is installed
if {[catch {exec which yt-dlp}]} {
    emit_json false yt-dlp $username "" $format "yt-dlp not installed" $timestamp dependency_missing
    exit 2
}

# Run yt-dlp
set live_url "https://www.tiktok.com/@${username}/live"

if {[catch {exec yt-dlp --no-warnings --dump-single-json --skip-download --format $format $live_url > $stdout_file 2> $stderr_file} result options]} {
    set exit_code [dict get $options -level]
} else {
    set exit_code 0
}

if {$exit_code != 0} {
    set stderr_content [exec head -c 1000 $stderr_file]
    
    if {[regexp -nocase {not currently live|No live cdn found|not available|private video} $stderr_content]} {
        set status offline
        set code 1
    } else {
        set status technical_error
        set code 2
    }
    
    emit_json false yt-dlp $username "" $format $stderr_content $timestamp $status
    exit $code
}

# Extract URL from JSON
set url ""
if {[file exists $stdout_file] && [file size $stdout_file] > 0} {
    if {![catch {open $stdout_file r} fp]} {
        if {![catch {read $fp} json_data]} {
            close $fp
            
            if {![catch {::json::json2dict $json_data} data]} {
                set candidates {}
                
                # Add direct URL if it exists
                if {[dict exists $data url] && [dict get $data url] ne ""} {
                    lappend candidates [dict get $data url]
                }
                
                # Add URLs from formats array
                if {[dict exists $data formats]} {
                    foreach item [dict get $data formats] {
                        if {[dict exists $item url] && [dict get $item url] ne ""} {
                            lappend candidates [dict get $item url]
                        }
                    }
                }
                
                # Find valid URL
                foreach value $candidates {
                    set low [string tolower $value]
                    if {[string match https://* $value] && ([string match *.m3u8* $low] || [string match *.flv* $low]) && ![string match *only_audio=1* $low]} {
                        set url $value
                        break
                    }
                }
            }
        } else {
            close $fp
        }
    }
}

if {$url eq ""} {
    emit_json false yt-dlp $username "" $format "could not extract HTTPS video URL" $timestamp offline
    exit 1
}

if {$json_flag eq "--json"} {
    emit_json true yt-dlp $username $url $format "" $timestamp live
} else {
    puts $url
}
