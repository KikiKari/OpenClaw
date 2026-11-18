#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "fdb3a4203dc16acb0c52742f82a726ce0c3f584b853a1bf673469a3ec7671e89", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "tcl"}
# pplx-refresh.sh — portiert nach tcl
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

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

set HERE [file dirname [file normalize [info script]]]
set CFG [expr {[info exists env(PERPLEXITY_CONFIG_DIR)] ? $env(PERPLEXITY_CONFIG_DIR) : [file join $env(HOME) .perplexity-mcp]}]
set PROFILE [expr {[info exists env(PERPLEXITY_PROFILE)] ? $env(PERPLEXITY_PROFILE) : "codespace"}]
set COOKIE_FILE [expr {[llength $argv] > 0 ? [lindex $argv 0] : [file join $env(HOME) pplx-cookies.txt]}]

if {![file exists $COOKIE_FILE] || [file size $COOKIE_FILE] == 0} {
    puts stderr "✗ Cookie file empty/missing: $COOKIE_FILE"
    puts stderr "  Export __Secure-next-auth.session-token from your local browser"
    puts stderr "  (DevTools → Application → Cookies → www.perplexity.ai) into that file."
    exit 1
}

# 1. ensure the extension daemon has a usable browser (idempotent)
exec bash [file join $HERE pplx-setup.sh]

# 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
set LOCK [file join $CFG daemon.lock]
if {![file exists $LOCK]} {
    puts stderr "✗ no daemon.lock at $LOCK — is the extension running?"
    exit 1
}

set lock_data [exec python3 -c "import json;print(json.load(open('$LOCK'))['pid'])"]
set PID [string trim $lock_data]

if {[catch {exec ps -p $PID -o pid=} result]} {
    puts stderr "✗ daemon pid $PID not running"
    exit 1
}

set env_file "/proc/$PID/environ"
if {![file exists $env_file]} {
    puts stderr "✗ cannot read environment for pid $PID"
    exit 1
}

set env_content [read [open $env_file r]]
set lines [split $env_content "\0"]
set PASS ""
foreach line $lines {
    if {[string match "PERPLEXITY_VAULT_PASSPHRASE=*" $line]} {
        set PASS [string range $line 28 end]
        break
    }
}

if {$PASS eq ""} {
    puts stderr "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env"
    exit 1
}

# 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
set DIST ""
catch {
    set find_result [exec find $env(HOME)/.npm/_npx -type d -path *perplexity-user-mcp/dist 2>/dev/null | head -1]
    set DIST [string trim $find_result]
}

if {$DIST eq ""} {
    catch {exec npx -y perplexity-user-mcp --version >/dev/null 2>&1}
    catch {
        set find_result [exec find $env(HOME)/.npm/_npx -type d -path *perplexity-user-mcp/dist 2>/dev/null | head -1]
        set DIST [string trim $find_result]
    }
}

# 4. inject
set env(PERPLEXITY_VAULT_PASSPHRASE) $PASS
set env(PERPLEXITY_CONFIG_DIR) $CFG
set env(PERPLEXITY_PROFILE) $PROFILE
set env(PPLX_DIST) $DIST
exec node [file join $HERE pplx-inject.mjs] $COOKIE_FILE

# 5. trigger daemon reinit
set reinit_file [file join $CFG profiles $PROFILE .reinit]
set fh [open $reinit_file w]
puts $fh [clock seconds]
close $fh
puts "→ reinit triggered, waiting for daemon..."

# 6. verify
set STAT [file join $CFG profiles $PROFILE daemon-status.json]
for {set i 1} {$i <= 20} {incr i} {
    after 1500
    if {[file exists $STAT]} {
        set auth_result [catch {exec python3 -c "import json;print(json.load(open('$STAT')).get('authenticated'))"} auth_output]
        set tier_result [catch {exec python3 -c "import json;print(json.load(open('$STAT')).get('tier'))"} tier_output]
        
        if {$auth_result == 0 && [string trim $auth_output] eq "True"} {
            set tier [string trim $tier_output]
            puts "✅ authenticated — tier: $tier"
            exit 0
        }
    }
}
puts "⚠️  not authenticated yet. Check: tail -20 [file join $CFG daemon.log]"
exit 1
