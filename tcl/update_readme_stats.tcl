#!/usr/bin/env tclsh8.6
# update_readme_stats.py — portiert nach tcl
# Quelle: python, OpenClaw@main:scripts/update_readme_stats.py
# Erzeugt: 2026-08-24 durch ABSTRACTIONS_MANAGER.py

# Fetch ClawHub stats and update README.md download counts and security status.

package require http
package require json
package require regexp

set API_BASE "https://clawhub.ai/api/v1"
set TOKEN [expr {[info exists ::env(CLAWHUB_TOKEN)] ? $::env(CLAWHUB_TOKEN) : ""}]

array set SKILLS {
    "Cluster Gateway" "cluster-gateway"
    "MCP Tool Utils" "mcp-tool-utils"
    "Reports Creator" "reports-creator"
    "Relay Node" "relay-node"
    "JSON Utils" "json-utils"
    "Log Collector" "log-collector"
    "TikTok Live Monitor" "tiktok-live-monitor"
    "Doc Scraper" "doc-scraper"
    "Workspace Database Manager" "workspace-database-manager"
    "Scripting Utils" "scripting-utils"
}

proc fetch_skill {slug} {
    global API_BASE TOKEN
    set url "${API_BASE}/skills/${slug}"
    set headers [list Accept "application/json"]
    if {$TOKEN ne ""} {
        lappend headers Authorization "Bearer ${TOKEN}"
    }
    
    set token [::http::geturl $url -headers $headers -timeout 10000]
    set status [::http::status $token]
    if {$status ne "ok"} {
        set code [::http::code $token]
        ::http::cleanup $token
        error "HTTP Error: $code"
    }
    set data [::http::data $token]
    ::http::cleanup $token]
    
    return [::json::json2dict $data]
}

proc parse_skill {data} {
    # Extract nested values
    set skill_dict [dict get $data skill]
    set stats_dict [dict get $skill_dict stats]
    set latest_version_dict [dict get $data latestVersion]
    
    set downloads [expr {[dict exists $stats_dict downloads] ? [dict get $stats_dict downloads] : 0}]
    set version [expr {[dict exists $latest_version_dict version] ? [dict get $latest_version_dict version] : "1.0.0"}]
    
    set mod_val ""
    if {[dict exists $data moderation]} {
        set mod_val [dict get $data moderation]
    }
    
    set security "✅ Pass"
    if {$mod_val ne ""} {
        if {[dict get $mod_val isMalwareBlocked]} {
            set security "🚫 Blocked"
        } else {
            set security "🔍 Review"
        }
    }
    
    if {![string match v* $version]} {
        set version "v${version}"
    }
    
    return [dict create downloads $downloads version $version security $security]
}

proc escape_regexp {str} {
    # Escape special regex characters
    regsub -all {([][{}()+*?.\\^$|])} $str {\\\1} escaped
    return $escaped
}

proc main {} {
    global SKILLS
    
    array set stats {}
    set errors 0
    
    foreach {name slug} [array get SKILLS] {
        if {[catch {
            set data [fetch_skill $slug]
            set s [parse_skill $data]
            set stats($slug) $s
            puts "  OK  $slug: [dict get $s downloads] downloads, [dict get $s version], [dict get $s security]"
        } exc]} {
            puts stderr "  ERR $slug: $exc"
            incr errors
        }
    }
    
    if {[array size stats] == 0} {
        puts stderr "No data fetched — aborting."
        exit 1
    }
    
    set fh [open "README.md" r]
    set content [read $fh]
    close $fh
    
    foreach {name slug} [array get SKILLS] {
        if {![info exists stats($slug)]} {
            continue
        }
        set dl [dict get $stats($slug) downloads]
        
        # Escape the name for use in regex
        set escaped_name [escape_regexp $name]
        set pattern "(\\|\\s*\\[?${escaped_name}\\]?[^|]*\\|[^|]*\\|)\\s*\\d+\\s*(\\|)"
        set replacement "\\1 ${dl} \\2"
        
        # Tcl's regex doesn't support case-insensitive flag directly in substitution
        # We'll do a case-sensitive replacement here
        regsub -all -- $pattern $content $replacement content result
        if {$result > 0} {
            puts "  Updated: $name -> $dl"
        }
    }
    
    set fh [open "README.md" w]
    puts $fh $content
    close $fh
    
    puts "Done: [array size stats] skills, $errors errors."
}

if {$::argv0 eq [info script]} {
    main
}
