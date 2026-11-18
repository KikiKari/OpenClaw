#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "48749fed8dd56cf3ebf09bac74703af3c1cd335b79c5ae2a6801f12337555f62", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "tcl"}
# pplx-setup.sh — portiert nach tcl
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.

# Find the latest patchright directory
set extpr ""
set home [exec printenv HOME]
set pattern [file join $home .vscode-remote extensions "nskha.perplexity-vscode-*" dist node_modules patchright]

if {[catch {glob -nocomplain -directory [file dirname [file dirname $pattern]] [file tail $pattern]} dirs]} {
    set extpr ""
} else {
    # Sort versions and get the latest
    set sorted_dirs [lsort -dictionary $dirs]
    if {[llength $sorted_dirs] > 0} {
        set extpr [lindex $sorted_dirs end]
    }
}

if {$extpr eq ""} {
    puts "\[setup\] extension patchright not found — is the Perplexity extension installed?"
    exit 0
}

# Try to get the executable path
set exp ""
if {[catch {
    set exp [exec node -e "const {chromium}=require('$extpr');console.log(chromium.executablePath())"]
}]} {
    set exp ""
}

# Check if executable exists and is executable
if {$exp ne "" && [file executable $exp]} {
    puts "\[setup\] daemon browser already present: $exp"
    exit 0
}

puts "\[setup\] installing matching chromium for the extension daemon (expected: [expr {$exp eq "" ? "unknown" : $exp}])..."
exec node [file join $extpr cli.js] install chromium
puts "\[setup\] done."
