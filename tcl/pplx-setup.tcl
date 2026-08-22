#!/usr/bin/env tclsh8.6
# pplx-setup.sh — portiert nach tcl
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.

package require fileutil

# Find the latest patchright directory
set extpr ""
set home [env HOME]
set pattern [file join $home .vscode-remote extensions nskha.perplexity-vscode-* dist node_modules patchright]

# Get all matching directories
set dirs {}
if {[catch {glob -nocomplain -directory [file dirname [file dirname $pattern]] nskha.perplexity-vscode-*} dir_list]} {
    set dir_list {}
}

foreach dir $dir_list {
    set patchright_dir [file join $dir dist node_modules patchright]
    if {[file isdirectory $patchright_dir]} {
        lappend dirs $patchright_dir
    }
}

# Sort directories by version and get the latest
if {[llength $dirs] > 0} {
    # Simple version sorting - assuming directory names can be compared
    set sorted_dirs [lsort -dictionary $dirs]
    set extpr [lindex $sorted_dirs end]
}

if {$extpr eq ""} {
    puts "\[setup\] extension patchright not found — is the Perplexity extension installed?"
    exit 0
}

# Try to get the executable path
set exp ""
if {[catch {
    set script "const {chromium}=require('[string map {\\ /} $extpr]');console.log(chromium.executablePath())"
    set result [exec node -e $script 2>@1]
    if {$result ne ""} {
        set exp $result
    }
} error]} {
    # Error occurred, exp remains empty
}

# Check if executable exists and is executable
set executable_exists false
if {$exp ne ""} {
    if {[file exists $exp] && [file executable $exp]} {
        set executable_exists true
    }
}

if {$executable_exists} {
    puts "\[setup\] daemon browser already present: $exp"
    exit 0
}

puts "\[setup\] installing matching chromium for the extension daemon (expected: [expr {$exp eq "" ? "unknown" : $exp}])..."
if {[catch {exec node [file join $extpr cli.js] install chromium] result]} {
    puts stderr "Error during installation: $result"
    exit 1
}
puts "\[setup\] done."
