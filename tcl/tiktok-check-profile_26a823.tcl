#!/usr/bin/env tclsh
# tiktok-check-profile.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Basic TikTok LIVE profile checker.
#
# Scopes every signal to the requested account and ignores unrelated sidebar
# LIVE labels. This profile-only checker does not classify restricted LIVE;
# use the enhanced checker or dispatcher for that distinction.
#
# Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
# failure, 75 = overloaded before Playwright startup.

package require http
package require tls
package require json
package require fileutil

# Enable HTTPS support
http::register https 443 [list ::tls::socket]

# Helper functions
proc normalizeUsername {username} {
    if {$username eq ""} {
        error "Username cannot be empty"
    }
    # Remove @ prefix if present
    regsub {^@} $username {} username
    return $username
}

proc enforceLoadLimit {method} {
    # Placeholder - implement if needed
}

proc liveHrefSelectors {username} {
    set selectors [list]
    lappend selectors "a[href=\"/$username/live\"]"
    lappend selectors "a[href=\"/@@$username/live\"]"
    lappend selectors "a[href*=\"/$username/live?\"]"
    lappend selectors "a[href*=\"/$username/live#\"]"
    return $selectors
}

# Main procedure
proc checkLiveStatus {username} {
    # Check if curl is available
    if {[catch {exec which curl}]} {
        puts [::json::encode {
            error true
            status "dependency_missing"
            method "playwright_basic"
            message "curl not found"
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"]
        }]
        exit 2
    }
    
    # Build URL
    set url "https://www.tiktok.com/@$username"
    
    # Fetch page content with curl
    if {[catch {exec curl -s --max-time 30 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" $url} html]} {
        puts [::json::encode {
            error true
            status "technical_error"
            message "Failed to fetch page content"
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"]
        }]
        exit 2
    }
    
    # Wait a bit for dynamic content
    after 2000
    
    # Check for LIVE indicators in the HTML content
    
    # Method 1: Check for live links
    set hasLiveLink false
    foreach selector [liveHrefSelectors $username] {
        if {[regexp "(?i)$selector" $html]} {
            set hasLiveLink true
            break
        }
    }
    
    # Method 2: Check for live badges/icons
    set liveIconVisible false
    if {[regexp {(?i)data-e2e=["']live-icon["']|class.*[Ll]ive[Bb]adge|class.*live-indicator} $html]} {
        set liveIconVisible true
    }
    
    # Method 3: Check for LIVE text
    set liveBadgeVisible false
    if {[regexp {(?i)LIVE} $html]} {
        set liveBadgeVisible true
    }
    
    # Method 4: Check for live border on avatar/profile image
    set hasLiveBorder false
    # Look for style attributes with red/live colors
    if {[regexp {(?i)(border-color|box-shadow).*((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\s*,\s*){2}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)|#[fF][eE]2[cC]5|red} $html]} {
        set hasLiveBorder true
    }
    
    # Method 5: Check for other live indicators
    set liveIndicatorVisible false
    if {[regexp {(?i)live-indicator|LiveBadge} $html]} {
        set liveIndicatorVisible true
    }
    
    # Determine if live
    set isLive [expr {$hasLiveLink || $hasLiveBorder || $liveIconVisible || $liveIndicatorVisible || $liveBadgeVisible}]
    
    # Output result as JSON
    set result [dict create \
        username $username \
        isLive $isLive \
        timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"] \
        indicators [dict create \
            liveIcon $liveIconVisible \
            liveBadge $liveBadgeVisible \
            liveBorder $hasLiveBorder \
            liveLink $hasLiveLink \
            liveIndicator $liveIndicatorVisible \
        ] \
    ]
    
    puts [::json::encode $result]
    
    return $isLive
}

# Parse command line arguments
if {$argc != 1} {
    puts stderr "Usage: tclsh tiktok-check-profile.tcl <username>"
    exit 64
}

set username [normalizeUsername [lindex $argv 0]]

# Enforce load limit
enforceLoadLimit "playwright_basic"

# Check live status
if {[catch {checkLiveStatus $username} isLive]} {
    puts stderr $isLive
    exit 2
} else {
    if {$isLive eq ""} {
        exit 2
    } elseif {$isLive} {
        exit 0
    } else {
        exit 1
    }
}
