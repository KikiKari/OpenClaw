#!/usr/bin/env tclsh
# openclaw-maintenance.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Set OPENCLAW_BIN with fallback to default path
if {[info exists env(OPENCLAW_BIN)]} {
    set openclaw_bin $env(OPENCLAW_BIN)
} else {
    set openclaw_bin $env(HOME)/.local/bin/openclaw
}

# Check if the binary exists and is executable
if {![file executable $openclaw_bin]} {
    puts stderr "ERROR: OpenClaw binary not found: $openclaw_bin"
    exit 1
}

# Function to execute a command and handle errors
proc run_command {cmd} {
    if {[catch {exec {*}$cmd} result]} {
        puts stderr "Command failed: $cmd"
        puts stderr $result
        exit 1
    }
    puts $result
}

# Show version
puts "Using OpenClaw: [exec $openclaw_bin --version]"

# === 1. Service-/Config-Drift ===
run_command [list $openclaw_bin doctor]

# === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
run_command [list $openclaw_bin plugins registry --refresh]
if {[info exists env(RUN_PLUGIN_UPDATE)] && $env(RUN_PLUGIN_UPDATE) eq "1"} {
    run_command [list $openclaw_bin plugins update --all]
} else {
    puts "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable."
}

# === 3. Tasks ===
run_command [list $openclaw_bin tasks maintenance --apply]

# === 4. Sessions – alle Agents auf einmal ===
run_command [list $openclaw_bin sessions cleanup --enforce --all-agents]

# === 5. Memory – status/index decken alle Agents ab ===
run_command [list $openclaw_bin memory status --deep --fix]
run_command [list $openclaw_bin memory index --force]

# === 6. Memory promote – MUSS pro Agent ===
foreach agent {main knecht docs ops-hub cron} {
    run_command [list $openclaw_bin memory promote --apply --agent $agent]
}

# === 7. Secrets ===
run_command [list $openclaw_bin secrets reload]
