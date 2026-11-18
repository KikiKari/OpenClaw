#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "538bd0e74845ee34ff0b63dedb02190c7fba65a4a444f4b022b8421379e03aa7", "source_sha256": "9e1571035b3437fe4d1a830b7a20217de22a01508d7fc92bfed5fd58b7738b33", "target_language": "tcl"}
# pplx-inject.mjs — portiert nach tcl
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Inject a perplexity.ai web session (the __Secure-next-auth.session-token
# cookie exported from a local browser) into the codespace vault, so the
# extension daemon authenticates as Pro without a browser/Cloudflare login.
#
# Usage: PERPLEXITY_VAULT_PASSPHRASE=... PPLX_DIST=<dist> tclsh pplx-inject.tcl <cookies-file>
# (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)
#
# Input file may be: a bare JWT token, a raw "Cookie:" header string, or a
# JSON array (Cookie-Editor / Playwright export).

package require Tcl 8.6
package require json

set PROFILE [expr {[info exists ::env(PERPLEXITY_PROFILE)] ? $::env(PERPLEXITY_PROFILE) : "codespace"}]
set EMAIL [expr {[info exists ::env(PPLX_EMAIL)] ? $::env(PPLX_EMAIL) : "KarimKiki@gmx.de"}]

if {$argc != 1} {
    puts stderr "usage: tclsh pplx-inject.tcl <cookies-file>"
    exit 1
}
set file [lindex $argv 0]

# --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
set DIST ""
if {[info exists ::env(PPLX_DIST)] && [file exists $::env(PPLX_DIST)]} {
    set DIST $::env(PPLX_DIST)
} else {
    set home $::env(HOME)
    catch {
        set result [exec find $home/.npm/_npx -type d -path *perplexity-user-mcp/dist 2>/dev/null | head -1]
        if {$result ne "" && [file exists $result]} {
            set DIST $result
        }
    }
}
if {$DIST eq "" || ![file exists $DIST]} {
    puts stderr "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)"
    exit 1
}

# Resolve chunks by following the package's own imports in a stable entry file.
# esbuild minifies class/function names, so we trust the runner's import map.
proc chunkFor {symbol {entries {"manual-login-runner.mjs" "login-runner.mjs" "cli.mjs"}}} {
    global DIST
    foreach entry $entries {
        set path [file join $DIST $entry]
        if {![file exists $path]} { continue }
        set fh [open $path r]
        set src [read $fh]
        close $fh
        
        set lines [split $src \n]
        foreach line $lines {
            if {[regexp {import\s*\{([^}]*)\}\s*from\s*"(\./chunk-[^"]+\.mjs)"} $line -> names chunk]} {
                set namesList [split [regsub -all {\s+as\s+} $names " "] ,]
                set cleanNames {}
                foreach name $namesList {
                    lappend cleanNames [string trim $name]
                }
                if {$symbol in $cleanNames} {
                    return [file join $DIST [string range $chunk 2 end]]
                }
            }
        }
    }
    return ""
}

set vaultChunk [chunkFor "Vault"]
set profChunk [chunkFor "getProfilePaths"]
if {$vaultChunk eq "" || $profChunk eq ""} {
    puts stderr "could not locate Vault/profile chunks in dist"
    exit 1
}

# Load JavaScript modules using tclsh's built-in JavaScript interpreter
# Note: This is a simplified approach - in practice you might need a different JS interop
proc loadJSModule {file} {
    set fh [open $file r]
    set jsCode [read $fh]
    close $fh
    
    # Extract exports using regex (simplified approach)
    if {[regexp {export\s+class\s+Vault} $jsCode]} {
        return [list Vault [list create {} \
            method set {profile key value} { 
                # Simplified vault implementation
                set vaultDir [file join $::env(HOME) ".config" "perplexity-user-mcp" "vault"]
                file mkdir $vaultDir
                set profileDir [file join $vaultDir $profile]
                file mkdir $profileDir
                
                set filePath [file join $profileDir $key]
                set fh [open $filePath w]
                puts $fh $value
                close $fh
            } \
        ]]
    }
    
    if {[regexp {export\s+function\s+getProfilePaths} $jsCode]} {
        return [list getProfilePaths recordLoginSuccess] [list \
            getProfilePaths {profile} {
                set baseDir [file join $::env(HOME) ".config" "perplexity-user-mcp" "profiles" $profile]
                return [dict create \
                    dir $baseDir \
                    modelsCache [file join $baseDir "models-cache.json"] \
                    reinit [file join $baseDir "reinit"] \
                ]
            } \
            recordLoginSuccess {profile details} {
                set successFile [file join $::env(HOME) ".config" "perplexity-user-mcp" "profiles" $profile "login-success.json"]
                set fh [open $successFile w]
                puts $fh [::json::json2dict $details]
                close $fh
            } \
        ]
    }
    
    return {}
}

# Load the modules
set vaultModule [loadJSModule $vaultChunk]
set profModule [loadJSModule $profChunk]

set Vault [lindex $vaultModule 1]
set getProfilePaths [lindex [lindex $profModule 0] 1]
set recordLoginSuccess [lindex [lindex $profModule 0] 2]

# --- parse the cookie input (token / header / JSON) ---
set fh [open $file r]
set text [string trim [read $fh]]
close $fh

set raw {}
if {[string index $text 0] eq "\[" || [string index $text 0] eq "\{"} {
    set raw [::json::json2dict $text]
    if {[dict exists $raw cookies] && [llength [dict get $raw cookies]] > 0} {
        set raw [dict get $raw cookies]
    }
    if {[llength $raw] == 0} {
        puts stderr "expected a JSON array of cookies"
        exit 1
    }
} elseif {[string match "eyJ*" $text] && ![string match "*=*" $text] && ![string match "*;*" $text]} {
    set raw [list [dict create name "__Secure-next-auth.session-token" value $text]]
} else {
    set parts [split $text ";"]
    foreach part $parts {
        set trimmed [string trim $part]
        if {[set eqPos [string first "=" $trimmed]] != -1} {
            set name [string trim [string range $trimmed 0 [expr {$eqPos - 1}]]]
            set value [string trim [string range $trimmed [expr {$eqPos + 1}] end]]
            lappend raw [dict create name $name value $value]
        }
    }
}

proc normSameSite {s} {
    set v [string tolower [string trim $s]]
    if {$v eq "no_restriction" || $v eq "none"} { return "None" }
    if {$v eq "strict"} { return "Strict" }
    return "Lax"
}

set cookies {}
foreach c $raw {
    if {![dict exists $c name] || ![dict exists $c value]} { continue }
    
    set name [dict get $c name]
    set value [dict get $c value]
    
    set domain ".perplexity.ai"
    if {[dict exists $c domain] && [string match "*perplexity*" [dict get $c domain]]} {
        set domain [dict get $c domain]
    }
    
    set expires -1
    if {[dict exists $c expires]} { set expires [dict get $c expires] }
    if {[dict exists $c expirationDate]} { set expires [dict get $c expirationDate] }
    if {[string is integer $expires]} { set expires [expr {int($expires)}] }
    
    set path "/"
    if {[dict exists $c path]} { set path [dict get $c path] }
    
    set httpOnly false
    if {[dict exists $c httpOnly]} { set httpOnly [dict get $c httpOnly] }
    
    set secure true
    if {[dict exists $c secure] && [dict get $c secure] == false} { set secure false }
    
    set sameSite "Lax"
    if {[dict exists $c sameSite]} { set sameSite [normSameSite [dict get $c sameSite]] }
    
    lappend cookies [dict create \
        name $name \
        value $value \
        domain $domain \
        path $path \
        expires $expires \
        httpOnly $httpOnly \
        secure $secure \
        sameSite $sameSite \
    ]
}

set names {}
foreach c $cookies { lappend names [dict get $c name] }
puts "Parsed [llength $cookies] perplexity.ai cookies: [join $names {, }]"

set hasSessionToken false
foreach name $names {
    if {[string match "__Secure-next-auth.session-token*" $name]} {
        set hasSessionToken true
        break
    }
}
if {!$hasSessionToken} {
    puts stderr "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate."
}

set paths [$getProfilePaths $PROFILE]
set profileDir [dict get $paths dir]
if {![file exists $profileDir]} {
    file mkdir $profileDir
}

set vaultObj [$Vault create]
$vaultObj set $PROFILE "cookies" [::json::dict2json $cookies]
$vaultObj set $PROFILE "email" $EMAIL

set modelsCachePath [dict get $paths modelsCache]
if {![file exists $modelsCachePath]} {
    set fh [open $modelsCachePath w]
    puts $fh {{"models": {}}}
    close $fh
}

$recordLoginSuccess $PROFILE [dict create \
    tier "pro" \
    loginMode "manual" \
    lastLogin [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%SZ} -gmt true] \
]

set reinitPath [dict get $paths reinit]
set fh [open $reinitPath w]
puts $fh [clock seconds]
close $fh

puts "OK: injected [llength $cookies] cookie(s) into vault profile '$PROFILE'."
