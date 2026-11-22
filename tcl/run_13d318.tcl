#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "067373499bdfe2ebbd8c8a651928d2a39cadb93532e99559c49e9c10fe32ca6f", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "tcl"}
# run.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Set working directory
cd /repo

# Set environment variables
set env(OPENCLAW_STATE_DIR) "/tmp/openclaw-test"
set env(OPENCLAW_CONFIG_PATH) "$env(OPENCLAW_STATE_DIR)/openclaw.json"

puts "==> Build"
if {[catch {exec pnpm build} result]} {
    set fp [open "/tmp/openclaw-cleanup-build.log" r]
    puts [read $fp]
    close $fp
    exit 1
}

puts "==> Seed state"
file mkdir "$env(OPENCLAW_STATE_DIR)/credentials"
file mkdir "$env(OPENCLAW_STATE_DIR)/agents/main/sessions"
set fp [open "$env(OPENCLAW_CONFIG_PATH)" w]
puts $fp "{}"
close $fp
set fp [open "$env(OPENCLAW_STATE_DIR)/credentials/marker.txt" w]
puts $fp "creds"
close $fp
set fp [open "$env(OPENCLAW_STATE_DIR)/agents/main/sessions/sessions.json" w]
puts $fp "session"
close $fp

puts "==> Reset (config+creds+sessions)"
if {[catch {exec pnpm openclaw reset --scope config+creds+sessions --yes --non-interactive} result]} {
    set fp [open "/tmp/openclaw-cleanup-reset.log" r]
    puts [read $fp]
    close $fp
    exit 1
}

if {[file exists $env(OPENCLAW_CONFIG_PATH)]} {
    exit 1
}
if {[file exists "$env(OPENCLAW_STATE_DIR)/credentials"]} {
    exit 1
}
if {[file exists "$env(OPENCLAW_STATE_DIR)/agents/main/sessions"]} {
    exit 1
}

puts "==> Recreate minimal config"
file mkdir "$env(OPENCLAW_STATE_DIR)/credentials"
set fp [open "$env(OPENCLAW_CONFIG_PATH)" w]
puts $fp "{}"
close $fp

puts "==> Uninstall (state only)"
if {[catch {exec pnpm openclaw uninstall --state --yes --non-interactive} result]} {
    set fp [open "/tmp/openclaw-cleanup-uninstall.log" r]
    puts [read $fp]
    close $fp
    exit 1
}

if {[file exists $env(OPENCLAW_STATE_DIR)]} {
    exit 1
}

puts "OK"
