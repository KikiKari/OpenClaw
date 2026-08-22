#!/usr/bin/env tclsh
# pplx-inject.mjs — portiert nach tcl
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Inject a perplexity.ai web session (the __Secure-next-auth.session-token
# cookie exported from a local browser) into the codespace vault, so the
# extension daemon authenticates as Pro without a browser/Cloudflare login.
#
# Usage: PERPLEXITY_VAULT_PASSPHRASE=... PPLX_DIST=<dist> tclsh pplx-inject.tcl <cookies-file>
# (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)
#
# Input file may be: a bare JWT token, a raw "Cookie:" header string, or a
# JSON array (Cookie-Editor / Playwright export).

package require json
package require fileutil

# Helper to execute shell commands and capture output
proc exec_cmd {cmd} {
    if {[catch {exec {*}$cmd} result]} {
        return ""
    }
    return [string trim $result]
}

# Normalize SameSite values
proc normSameSite {s} {
    set v [string tolower [expr {$s eq "" ? "" : $s}]]
    if {$v eq "no_restriction" || $v eq "none"} {
        return "None"
    }
    if {$v eq "strict"} {
        return "Strict"
    }
    return "Lax"
}

# Locate the perplexity-user-mcp dist directory
proc find_dist {} {
    global env
    set dist ""
    if {[info exists env(PPLX_DIST)]} {
        set dist $env(PPLX_DIST)
        if {[file isdirectory $dist]} {
            return $dist
        }
    }
    
    # Try to find via npm cache
    set cmd [list find $::env(HOME)/.npm/_npx -type d -path *perplexity-user-mcp/dist 2>/dev/null | head -1]
    if {[catch {exec bash -c [join $cmd]} result]} {
        return ""
    }
    set result [string trim $result]
    if {$result ne "" && [file isdirectory $result]} {
        return $result
    }
    return ""
}

# Read file content
proc read_file {filename} {
    set fh [open $filename r]
    set data [read $fh]
    close $fh
    return $data
}

# Write file content
proc write_file {filename data} {
    set fh [open $filename w]
    puts -nonewline $fh $data
    close $fh
}

# Create directory recursively
proc create_dir {dir} {
    if {![file exists $dir]} {
        file mkdir $dir
    }
}

# Main script starts here
set PROFILE [expr {[info exists ::env(PERPLEXITY_PROFILE)] ? $::env(PERPLEXITY_PROFILE) : "codespace"}]
set EMAIL [expr {[info exists ::env(PPLX_EMAIL)] ? $::env(PPLX_EMAIL) : "KarimKiki@gmx.de"}]

# Check command line argument
if {$argc < 1} {
    puts stderr "usage: tclsh pplx-inject.tcl <cookies-file>"
    exit 1
}
set file [lindex $argv 0]

# Locate distribution directory
set DIST [find_dist]
if {$DIST eq "" || ![file isdirectory $DIST]} {
    puts stderr "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)"
    exit 1
}

# In Tcl we can't dynamically import modules like JS, so we'll simulate the functionality
# For this port, we assume the necessary functions are available or implemented inline

# Parse the cookie input (token / header / JSON)
set text [string trim [read_file $file]]
set raw {}

if {[string index $text 0] eq "\[" || [string index $text 0] eq "\{"} {
    # Assume valid JSON - in real implementation would need proper JSON parsing
    if {[catch {::json::json2dict $text} json_data]} {
        puts stderr "Invalid JSON format"
        exit 1
    }
    
    # Handle different JSON structures
    if {[dict exists $json_data cookies]} {
        set raw [dict get $json_data cookies]
    } elseif {[llength $json_data] > 0} {
        set raw $json_data
    } else {
        puts stderr "expected a JSON array of cookies"
        exit 1
    }
} elseif {[string match "eyJ*" $text] && ![string match "*=*" $text] && ![string match "*;*" $text]} {
    set raw [list [dict create name "__Secure-next-auth.session-token" value $text]]
} else {
    # Parse Cookie header format
    set raw {}
    foreach kv [split $text "; "] {
        set parts [split $kv "="]
        if {[llength $parts] >= 2} {
            set name [string trim [lindex $parts 0]]
            set value [string trim [join [lrange $parts 1 end] "="]]
            lappend raw [dict create name $name value $value]
        }
    }
}

# Process cookies
set cookies {}
set names {}

foreach c $raw {
    if {![dict exists $c name] || ![dict exists $c value]} {
        continue
    }
    
    set cname [dict get $c name]
    set cvalue [dict get $c value]
    
    # Filter for perplexity.ai domains
    set domain ""
    if {[dict exists $c domain]} {
        set domain [dict get $c domain]
    }
    
    if {$domain ne "" && ![string match "*perplexity.ai*" $domain]} {
        continue
    }
    
    if {$domain eq ""} {
        set domain ".perplexity.ai"
    }
    
    # Handle expiration
    set expires -1
    if {[dict exists $c expires]} {
        set expires [dict get $c expires]
    } elseif {[dict exists $c expirationDate]} {
        set expires [dict get $c expirationDate]
    }
    
    if {![string is integer -strict $expires]} {
        set expires -1
    }
    
    # Handle other attributes
    set path "/"
    if {[dict exists $c path]} {
        set path [dict get $c path]
    }
    
    set httpOnly false
    if {[dict exists $c httpOnly]} {
        set httpOnly [dict get $c httpOnly]
    }
    
    set secure true
    if {[dict exists $c secure]} {
        set secure [dict get $c secure]
    }
    
    set sameSite ""
    if {[dict exists $c sameSite]} {
        set sameSite [dict get $c sameSite]
    }
    
    set processed_cookie [dict create \
        name $cname \
        value $cvalue \
        domain $domain \
        path $path \
        expires $expires \
        httpOnly $httpOnly \
        secure $secure \
        sameSite [normSameSite $sameSite] \
    ]
    
    lappend cookies $processed_cookie
    lappend names $cname
}

puts "Parsed [llength $cookies] perplexity.ai cookies: [join $names ", "]"

# Check for required session token
set has_session_token false
foreach name $names {
    if {[string match "__Secure-next-auth.session-token*" $name]} {
        set has_session_token true
        break
    }
}

if {!$has_session_token} {
    puts stderr "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate."
}

# Simulate getProfilePaths functionality
proc getProfilePaths {profile} {
    set base_dir [file join $::env(HOME) ".perplexity"]
    set dir [file join $base_dir "profiles" $profile]
    set modelsCache [file join $dir "models.json"]
    set reinit [file join $dir "reinit"]
    return [dict create dir $dir modelsCache $modelsCache reinit $reinit]
}

# Get profile paths
set paths [getProfilePaths $PROFILE]

# Ensure directory exists
create_dir [dict get $paths dir]

# Simulate Vault functionality with simple file-based storage
proc vault_set {profile key value} {
    set vault_file [file join $::env(HOME) ".perplexity" "profiles" $profile "vault.json"]
    set vault_data [dict create]
    
    # Load existing data if it exists
    if {[file exists $vault_file]} {
        if {![catch {::json::json2dict [read_file $vault_file]} data]} {
            set vault_data $data
        }
    }
    
    # Update the specific key
    dict set vault_data $key $value
    
    # Save back to file
    set json_data [::json::dict2json $vault_data]
    write_file $vault_file $json_data
}

# Store cookies and email in vault
vault_set $PROFILE "cookies" [::json::dict2json $cookies]
vault_set $PROFILE "email" $EMAIL

# Create models cache if it doesn't exist
if {![file exists [dict get $paths modelsCache]]} {
    write_file [dict get $paths modelsCache] [::json::dict2json [dict create models [dict create]]]
}

# Simulate recordLoginSuccess
proc recordLoginSuccess {profile data} {
    set success_file [file join $::env(HOME) ".perplexity" "profiles" $profile "login_success.json"]
    set login_data [dict create \
        tier [dict get $data tier] \
        loginMode [dict get $data loginMode] \
        lastLogin [dict get $data lastLogin] \
    ]
    write_file $success_file [::json::dict2json $login_data]
}

# Record login success
recordLoginSuccess $PROFILE [dict create tier "pro" loginMode "manual" lastLogin [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"]]

# Write reinit timestamp
write_file [dict get $paths reinit] [clock seconds]

puts "OK: injected [llength $cookies] cookie(s) into vault profile '$PROFILE'."
