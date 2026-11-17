#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "107152d5629f91133084dac2b702f70298cb730683a92a3b7287b68861cdc984", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "tcl"}
# openclaw-maintenance.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Set OPENCLAW_BIN with fallback to default path
if {[info exists ::env(OPENCLAW_BIN)]} {
    set openclaw_bin $::env(OPENCLAW_BIN)
} else {
    set openclaw_bin $::env(HOME)/.local/bin/openclaw
}

# Check if OpenClaw binary exists and is executable
if {![file executable $openclaw_bin]} {
    puts stderr "ERROR: OpenClaw binary not found: $openclaw_bin"
    exit 1
}

# Helper function to execute command and handle errors
proc run_cmd {args} {
    if {[catch {exec {*}$args} result]} {
        puts stderr "Command failed: $args"
        puts stderr "Error: $result"
        exit 1
    }
    return $result
}

# Helper function to execute command and print output
proc run_cmd_echo {args} {
    set result [run_cmd {*}$args]
    puts $result
    return $result
}

puts "Using OpenClaw: [run_cmd_echo $openclaw_bin --version]"

# === 1. Service-/Config-Drift ===
puts "\n=== 1. Service-/Config-Drift ==="
run_cmd_echo $openclaw_bin doctor

# === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
puts "\n=== 2. Plugin-Stage ==="
run_cmd_echo $openclaw_bin plugins registry --refresh

if {[info exists ::env(RUN_PLUGIN_UPDATE)] && $::env(RUN_PLUGIN_UPDATE) eq "1"} {
    run_cmd_echo $openclaw_bin plugins update --all
} else {
    puts "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable."
}

# === 3. Tasks ===
puts "\n=== 3. Tasks ==="
run_cmd_echo $openclaw_bin tasks maintenance --apply

# === 4. Sessions – alle Agents auf einmal ===
puts "\n=== 4. Sessions ==="
run_cmd_echo $openclaw_bin sessions cleanup --enforce --all-agents

# === 5. Memory – status/index decken alle Agents ab ===
puts "\n=== 5. Memory status/index ==="
run_cmd_echo $openclaw_bin memory status --deep --fix
run_cmd_echo $openclaw_bin memory index --force

# === 6. Memory promote – MUSS pro Agent ===
puts "\n=== 6. Memory promote ==="
foreach agent {main knecht docs ops-hub cron} {
    run_cmd_echo $openclaw_bin memory promote --apply --agent $agent
}

# === 7. Secrets ===
puts "\n=== 7. Secrets ==="
run_cmd_echo $openclaw_bin secrets reload
