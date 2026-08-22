#!/usr/bin/env tclsh8.6
# pplx-refresh.sh — portiert nach tcl
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Refresh the codespace Perplexity session from a locally-exported cookie.
#
# Usage:
#   ./pplx-refresh.tcl [cookie-file]
#
# cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
# __Secure-next-auth.session-token value (raw), or the whole Cookie header,
# or a JSON cookie export, into that file first.
#
# Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
#        -> trigger reinit -> verify authenticated.

package require Tcl 8.6

# Get script directory
set HERE [file dirname [info script]]
set CFG [expr {[info exists env(PERPLEXITY_CONFIG_DIR)] ? $env(PERPLEXITY_CONFIG_DIR) : "$env(HOME)/.perplexity-mcp"}]
set PROFILE [expr {[info exists env(PERPLEXITY_PROFILE)] ? $env(PERPLEXITY_PROFILE) : "codespace"}]

# Handle command line argument
if {$argc > 0} {
    set COOKIE_FILE [lindex $argv 0]
} else {
    set COOKIE_FILE "$env(HOME)/pplx-cookies.txt"
}

if {![file exists $COOKIE_FILE] || [file size $COOKIE_FILE] == 0} {
    puts "✗ Cookie file empty/missing: $COOKIE_FILE"
    puts "  Export __Secure-next-auth.session-token from your local browser"
    puts "  (DevTools → Application → Cookies → www.perplexity.ai) into that file."
    exit 1
}

# 1. ensure the extension daemon has a usable browser (idempotent)
exec bash "$HERE/pplx-setup.sh"

# 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
set LOCK "$CFG/daemon.lock"
if {![file exists $LOCK]} {
    puts "✗ no daemon.lock at $LOCK — is the extension running?"
    exit 1
}

# Read PID from lock file
set fp [open $LOCK r]
set lock_data [read $fp]
close $fp
dict set lock_dict pid [dict get [json::json2dict $lock_data] pid]
set PID [dict get $lock_dict pid]

# Check if process is running
if {[catch {exec ps -p $PID -o pid=}]} {
    puts "✗ daemon pid $PID not running"
    exit 1
}

# Read passphrase from environment
set PASS ""
if {[info exists env(OS)] && $env(OS) eq "Windows_NT"} {
    # Windows doesn't have /proc filesystem
    puts "✗ reading daemon environment not supported on Windows"
    exit 1
} else {
    # Unix-like systems
    set env_file "/proc/$PID/environ"
    if {[file readable $env_file]} {
        set fp [open $env_file r]
        fconfigure $fp -translation binary
        set env_data [read $fp]
        close $fp
        
        # Split by null bytes and search for our variable
        set env_vars [split $env_data "\x00"]
        foreach var $env_vars {
            if {[string match "PERPLEXITY_VAULT_PASSPHRASE=*" $var]} {
                set PASS [string range $var 29 end]
                break
            }
        }
    }
}

if {$PASS eq ""} {
    puts "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env"
    exit 1
}

# 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
set DIST ""
set npx_dir "$env(HOME)/.npm/_npx"
if {[file exists $npx_dir]} {
    # Find directories matching the pattern
    set cmd "find \"$npx_dir\" -type d -path \"*perplexity-user-mcp/dist\" 2>/dev/null | head -1"
    if {[catch {exec sh -c $cmd} result]} {
        set result ""
    }
    if {$result ne ""} {
        set DIST $result
    }
}

if {$DIST eq ""} {
    # Try to populate npx cache
    catch {exec npx -y perplexity-user-mcp --version}
    
    # Try again
    set cmd "find \"$npx_dir\" -type d -path \"*perplexity-user-mcp/dist\" 2>/dev/null | head -1"
    if {[catch {exec sh -c $cmd} result]} {
        set result ""
    }
    if {$result ne ""} {
        set DIST $result
    }
}

# 4. inject
set env(PERPLEXITY_VAULT_PASSPHRASE) $PASS
set env(PERPLEXITY_CONFIG_DIR) $CFG
set env(PERPLEXITY_PROFILE) $PROFILE
set env(PPLX_DIST) $DIST

# Execute the injection script
if {[catch {exec node "$HERE/pplx-inject.mjs" $COOKIE_FILE} result]} {
    puts stderr $result
    exit 1
}

# 5. trigger daemon reinit
set reinit_file "$CFG/profiles/$PROFILE/.reinit"
set fp [open $reinit_file w]
puts $fp [clock seconds]
close $fp
puts "→ reinit triggered, waiting for daemon..."

# 6. verify
set STAT "$CFG/profiles/$PROFILE/daemon-status.json"
set authenticated false
for {set i 1} {$i <= 20} {incr i} {
    after 1500  ;# Sleep 1.5 seconds
    
    if {[file exists $STAT]} {
        set fp [open $STAT r]
        set stat_data [read $fp]
        close $fp
        
        if {[catch {json::json2dict $stat_data} json_dict]} {
            continue
        }
        
        set AUTH [dict get $json_dict authenticated]
        set TIER [dict get $json_dict tier]
        
        if {$AUTH eq "true"} {
            puts "✅ authenticated — tier: $TIER"
            exit 0
        }
    }
}

puts "⚠️  not authenticated yet. Check: tail -20 $CFG/daemon.log"
exit 1

# Simple JSON parser for basic use cases
namespace eval json {
    proc json2dict {json_str} {
        # Remove outer braces if present
        set json_str [string trim $json_str "{}"]
        
        # Split by commas, but be careful about nested structures
        set result [dict create]
        set current_key ""
        set current_value ""
        set in_string false
        set escape_next false
        set colon_seen false
        
        set parts [list]
        set current_part ""
        
        for {set i 0} {$i < [string length $json_str]} {incr i} {
            set char [string index $json_str $i]
            
            if {$escape_next} {
                append current_part $char
                set escape_next false
                continue
            }
            
            if {$char eq "\\"} {
                append current_part $char
                set escape_next true
                continue
            }
            
            if {$char eq "\"" && !$in_string} {
                set in_string true
                append current_part $char
                continue
            } elseif {$char eq "\"" && $in_string} {
                set in_string false
                append current_part $char
                continue
            }
            
            if {!$in_string && $char eq ","} {
                lappend parts $current_part
                set current_part ""
                set colon_seen false
                continue
            }
            
            append current_part $char
        }
        
        if {$current_part ne ""} {
            lappend parts $current_part
        }
        
        foreach part $parts {
            # Extract key-value pair
            set part [string trim $part]
            if {[regexp {^"([^"]*)"\s*:\s*(.*)$} $part match key value]} {
                # Clean up the value
                set value [string trim $value]
                if {[string index $value 0] eq "\"" && [string index $value end] eq "\""} {
                    # String value
                    set value [string range $value 1 end-1]
                } elseif {$value eq "true"} {
                    set value "true"
                } elseif {$value eq "false"} {
                    set value "false"
                } elseif {$value eq "null"} {
                    set value ""
                }
                dict set result $key $value
            }
        }
        
        return $result
    }
}
