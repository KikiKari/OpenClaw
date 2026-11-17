#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "6d4ee6f5a27433640657c0fa80bfa37a303941986917d190582ff929d3e62cf9", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "perl6"}
# openclaw-maintenance.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use v6;

my $OPENCLAW_BIN = %*ENV<OPENCLAW_BIN> // "$*HOME/.local/bin/openclaw";

if !($OPENCLAW_BIN.IO.e && $OPENCLAW_BIN.IO.x) {
    note "ERROR: OpenClaw binary not found: $OPENCLAW_BIN";
    exit 1;
}

say "Using OpenClaw: " ~ run($OPENCLAW_BIN, '--version', :out).out.slurp-rest.chomp;

# === 1. Service-/Config-Drift ===
run($OPENCLAW_BIN, 'doctor');

# === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
run($OPENCLAW_BIN, 'plugins', 'registry', '--refresh');
if (%*ENV<RUN_PLUGIN_UPDATE> // '0') eq '1' {
    run($OPENCLAW_BIN, 'plugins', 'update', '--all');
} else {
    say "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.";
}

# === 3. Tasks ===
run($OPENCLAW_BIN, 'tasks', 'maintenance', '--apply');

# === 4. Sessions – alle Agents auf einmal ===
run($OPENCLAW_BIN, 'sessions', 'cleanup', '--enforce', '--all-agents');

# === 5. Memory – status/index decken alle Agents ab ===
run($OPENCLAW_BIN, 'memory', 'status', '--deep', '--fix');
run($OPENCLAW_BIN, 'memory', 'index', '--force');

# === 6. Memory promote – MUSS pro Agent ===
for <main knecht docs ops-hub cron> -> $AGENT {
    run($OPENCLAW_BIN, 'memory', 'promote', '--apply', '--agent', $AGENT);
}

# === 7. Secrets ===
run($OPENCLAW_BIN, 'secrets', 'reload');
