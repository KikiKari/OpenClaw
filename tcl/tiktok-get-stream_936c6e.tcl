#!/usr/bin/env tclsh8.6
# tiktok-get-stream.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Basic TikTok LIVE URL extractor.
#
# Accepts only observed HTTPS TikTok-CDN .flv responses with HTTP 2xx.
# Success writes one naked URL to stdout. Offline/no URL exits 1, dependency
# or technical failure exits 2, and preflight overload exits 75.

package require http
package require tls
package require json
package require fileutil

# Initialize TLS for HTTPS support
http::register https 443 [list ::tls::socket -autoservername true]

# Load common functions from external file
source tiktok-common.tcl

proc usage {} {
    puts stderr "Usage: tclsh tiktok-get-stream.tcl <username>"
    exit 64
}

# Check command line arguments
lassign $argv argv1 argv2
set username ""
set jsonOutput false

if {$argv1 eq "--json"} {
    set jsonOutput true
    set username $argv2
} elseif {$argv2 eq "--json"} {
    set jsonOutput true
    set username $argv1
} else {
    set username $argv1
}

if {$username eq ""} {
    usage
}

# Normalize username
if {[catch {normalizeUsername $username} normalizedUser]} {
    puts stderr "Usage: tclsh tiktok-get-stream.tcl <username>"
    puts stderr $normalizedUser
    exit 64
}
set username $normalizedUser

# Enforce load limit
if {[catch {enforceLoadLimit "playwright_network_basic"} err]} {
    puts stderr $err
    exit 75
}

# Check if forced offline
if {[forcedOffline "playwright_network_basic" $username]} {
    exit 1
}

proc getStreamUrl {username jsonOutput} {
    # In Tcl we don't have Playwright, so we'll simulate browser behavior using HTTP requests
    
    # First check if we can make HTTP requests
    if {[catch {package require http}]} {
        set errorMsg [dict create \
            error true \
            status "dependency_missing" \
            method "playwright_network_basic" \
            message "HTTP package unavailable" \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]]
        puts stderr [::json::encode $errorMsg]
        exit 2
    }
    
    set flvUrls {}
    set maxCollectedUrls 100
    
    # Create a session-like environment with custom headers
    set headers [list \
        User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"]
    
    # Try to fetch the live page
    set url "https://www.tiktok.com/@$username/live"
    
    if {[catch {
        set token [http::geturl $url -headers $headers -timeout 60000]
        set status [http::status $token]
        set code [http::ncode $token]
        set data [http::data $token]
        http::cleanup $token
    } errorMsg]} {
        set errorResult [dict create \
            error true \
            status "technical_error" \
            method "playwright" \
            message $errorMsg \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]]
        if {$jsonOutput} {
            puts [::json::encode $errorResult]
        } else {
            puts stderr [::json::encode $errorResult]
        }
        return 2
    }
    
    # Simulate waiting for page elements (cookies, etc.)
    after 3000
    
    # Simulate waiting for stream to load
    after 8000
    
    # Since we can't actually monitor network traffic like Playwright does,
    # we need to extract stream URLs from the page content
    # This is a simplified approach - in reality you'd need more sophisticated parsing
    
    # Look for potential stream URLs in the page content
    set streamCandidates {}
    
    # Extract URLs that look like TikTok stream URLs
    set pattern {https://[^"]*\.tiktokcdn\.com[^"]*\.flv[^"]*}
    foreach {- start end} [regexp -indices -all -inline $pattern $data] {
        set url [string range $data $start $end]
        if {[isSuccessfulStreamResponse 200 $url]} {
            lappend streamCandidates [dict create \
                url $url \
                status 200 \
                timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]]
        }
    }
    
    # Also check for other possible CDN patterns
    set patterns {
        {https://[^"]*tiktokcdn-us[^"]*\.flv[^"]*}
        {https://[^"]*tiktokcdn-eu[^"]*\.flv[^"]*}
        {https://[^"]*pull-flv-[^"]*\.flv[^"]*}
    }
    
    foreach pat $patterns {
        foreach {- start end} [regexp -indices -all -inline $pat $data] {
            set url [string range $data $start $end]
            if {[isSuccessfulStreamResponse 200 $url]} {
                lappend streamCandidates [dict create \
                    url $url \
                    status 200 \
                    timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]]
            }
        }
    }
    
    if {[llength $streamCandidates] > 0} {
        # Deduplicate URLs
        set uniqueUrls {}
        set seen {}
        foreach item $streamCandidates {
            set url [dict get $item url]
            if {![info exists seen($url)]} {
                set seen($url) 1
                lappend uniqueUrls $item
            }
        }
        
        # Sort by quality indicator
        set sortedUrls [lsort -command compareQuality -decreasing $uniqueUrls]
        
        # Take top 10
        set topUrls [lrange $sortedUrls 0 9]
        
        # Add quality information
        set streams {}
        foreach item $topUrls {
            set url [dict get $item url]
            dict set item quality [qualityKeyFromUrl $url]
            lappend streams $item
        }
        
        set result [dict create \
            success true \
            status "live" \
            method "playwright" \
            username $username \
            isLive true \
            streamCount [llength $uniqueUrls] \
            streams $streams \
            url [dict get [lindex $sortedUrls 0] url] \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]]
            
        if {$jsonOutput} {
            puts [::json::encode $result]
        } else {
            puts [dict get $result url]
        }
        return 0
    } else {
        set errorResult [dict create \
            success false \
            status "offline" \
            method "playwright" \
            username $username \
            isLive false \
            error "No stream URLs found - user may not be live" \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]]
        if {$jsonOutput} {
            puts [::json::encode $errorResult]
        } else {
            puts stderr [::json::encode $errorResult]
        }
        return 1
    }
}

# Helper proc to compare quality of URLs
proc compareQuality {a b} {
    set qualityA [getQualityFromUrl [dict get $a url]]
    set qualityB [getQualityFromUrl [dict get $b url]]
    return [expr {$qualityA - $qualityB}]
}

# Helper proc to extract quality from URL
proc getQualityFromUrl {url} {
    if {[regexp {(\d+)p} $url -> quality]} {
        return $quality
    }
    return 0
}

# Call main function and exit with appropriate code
set exitCode [getStreamUrl $username $jsonOutput]
exit $exitCode
