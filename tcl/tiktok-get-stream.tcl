#!/usr/bin/env tclsh8.6
# tiktok-get-stream.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# TikTok Stream URL Extractor
# Führt zuerst den profilgebundenen Status-Checker aus.
# Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
# Offline wird keine Stream-URL ausgegeben.

package require Tcl 8.6
package require json

# Helper functions
proc get_cpu_count {} {
    if {[catch {exec nproc} result]} {
        return 1
    }
    return $result
}

proc get_load_avg {} {
    if {[catch {exec cat /proc/loadavg} load_info]} {
        return 0.0
    }
    set load1 [lindex [split $load_info] 0]
    if {[string is double $load1]} {
        return $load1
    }
    return 0.0
}

proc reject_busy_node {} {
    set limit $::env(TIKTOK_MAX_LOAD_PER_CPU)
    if {![string is double -strict $limit] || $limit <= 0} {
        return
    }
    
    set cpu_count [get_cpu_count]
    if {$cpu_count < 1} {set cpu_count 1}
    
    set load_avg [get_load_avg]
    set normalized_load [expr {$load_avg / $cpu_count}]
    
    if {$normalized_load > $limit} {
        puts stderr "NODE_BUSY normalizedLoad=[format "%.2f" $normalized_load] limit=$limit"
        exit 75
    }
}

proc verify_live_status {username} {
    set script_dir [file dirname [info script]]
    set checker_path [file join $script_dir "tiktok-check-profile.js"]
    
    if {![file exists $checker_path]} {
        return false
    }
    
    if {[catch {exec node $checker_path $username} result]} {
        # Try parsing from stderr/stdout if available
        if {[info exists ::errorCode]} {
            set output ""
            if {[dict exists $::errorCode -errorinfo]} {
                set output [dict get $::errorCode -errorinfo]
            }
            if {[string length $output] > 0} {
                if {[catch {::json::json2dict $output} parsed]} {
                    return false
                }
                if {[dict exists $parsed isLive]} {
                    return [dict get $parsed isLive]
                }
            }
        }
        return false
    }
    
    if {[catch {::json::json2dict $result} parsed]} {
        return false
    }
    
    if {[dict exists $parsed isLive]} {
        return [dict get $parsed isLive]
    }
    return false
}

proc get_stream_url {username} {
    # Check if user is live first
    if {![verify_live_status $username]} {
        set response [dict create \
            username $username \
            isLive false \
            error "User is not currently live." \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
        puts stderr [::json::dict2json $response]
        return false
    }
    
    # For now we'll simulate the browser behavior with a simple HTTP request approach
    # In a full implementation you would need something like cdp-tcl or similar
    
    # This is a simplified version that tries to fetch the webpage and extract URLs
    set url "https://www.tiktok.com/@${username}/live"
    
    # We'll use curl to fetch the page content
    if {[catch {exec curl -s -L --max-time 60 $url} page_content]} {
        set error_response [dict create \
            error true \
            message "Failed to fetch page: $page_content" \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
        puts stderr [::json::dict2json $error_response]
        return false
    }
    
    # Extract potential FLV URLs using regex
    set flv_urls {}
    
    # Look for common FLV patterns
    foreach {match} [regexp -all -inline {https?://[^"]*\.flv[^"\s]*} $page_content] {
        lappend flv_urls [dict create \
            url $match \
            type "media" \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
    }
    
    foreach {match} [regexp -all -inline {https?://[^"]*pull-flv[^"\s]*} $page_content] {
        lappend flv_urls [dict create \
            url $match \
            type "media" \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
    }
    
    # Remove duplicates
    set unique_urls {}
    set seen {}
    foreach item $flv_urls {
        set url [dict get $item url]
        if {$url ni $seen} {
            lappend seen $url
            lappend unique_urls $item
        }
    }
    
    if {[llength $unique_urls] > 0} {
        # Sort by quality (simple implementation)
        proc get_quality {url_dict} {
            set url [dict get $url_dict url]
            set suffix_ranks [list \
                [list "_origin." 600] \
                [list "_uhd_60." 550] \
                [list "_uhd." 540] \
                [list "_hd_60." 500] \
                [list "_hd." 450] \
                [list "_sd." 350] \
                [list "_ld." 250]]
                
            foreach rank_pair $suffix_ranks {
                lassign $rank_pair suffix rank
                if {[string first $suffix $url] != -1} {
                    return $rank
                }
            }
            
            # Try to extract numeric quality
            if {[regexp {(\d+)p} $url match quality]} {
                return $quality
            }
            return 0
        }
        
        set sorted_urls [lsort -decreasing -command {get_quality} $unique_urls]
        
        set response [dict create \
            username $username \
            isLive true \
            streamCount [llength $sorted_urls] \
            streams $sorted_urls \
            vlcCommand "vlc \"[dict get [lindex $sorted_urls 0] url]\"" \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
            
        puts [::json::dict2json $response]
        return true
    } else {
        set response [dict create \
            username $username \
            isLive false \
            error "No stream URLs found - user may not be live" \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
        puts stderr [::json::dict2json $response]
        return false
    }
}

# Main execution
if {$argc < 1} {
    puts stderr "Usage: tclsh tiktok-get-stream.tcl <username>"
    exit 1
}

set raw_username [lindex $argv 0]
set username [regsub {^@+} $raw_username ""]
if {$username eq ""} {
    puts stderr "Username must not be empty"
    exit 1
}

reject_busy_node

# Run main function and handle exit code
if {[catch {get_stream_url $username} success]} {
    set error_response [dict create \
        error true \
        message $success \
        timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
    puts stderr [::json::dict2json $error_response]
    exit 1
} else {
    if {$success} {
        exit 0
    } else {
        exit 1
    }
}
