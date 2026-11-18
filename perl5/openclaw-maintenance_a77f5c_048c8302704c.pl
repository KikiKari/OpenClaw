#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "39bda50c54e1a467eb0831bccef8b57dd0c21c129874d9fd1c1fba20ab3edbad", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "perl5"}
# openclaw-maintenance.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

my $OPENCLAW_BIN = $ENV{OPENCLAW_BIN} // "$ENV{HOME}/.local/bin/openclaw";

unless (-x $OPENCLAW_BIN) {
    print STDERR "ERROR: OpenClaw binary not found: $OPENCLAW_BIN\n";
    exit 1;
}

my $version = `$OPENCLAW_BIN --version`;
chomp($version);
print "Using OpenClaw: $version\n";

# === 1. Service-/Config-Drift ===
system($OPENCLAW_BIN, 'doctor') == 0 or die "doctor failed: $?";

# === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
system($OPENCLAW_BIN, 'plugins', 'registry', '--refresh') == 0 or die "plugins registry failed: $?";
if ($ENV{RUN_PLUGIN_UPDATE} && $ENV{RUN_PLUGIN_UPDATE} eq '1') {
    system($OPENCLAW_BIN, 'plugins', 'update', '--all') == 0 or die "plugins update failed: $?";
} else {
    print "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.\n";
}

# === 3. Tasks ===
system($OPENCLAW_BIN, 'tasks', 'maintenance', '--apply') == 0 or die "tasks maintenance failed: $?";

# === 4. Sessions – alle Agents auf einmal ===
system($OPENCLAW_BIN, 'sessions', 'cleanup', '--enforce', '--all-agents') == 0 or die "sessions cleanup failed: $?";

# === 5. Memory – status/index decken alle Agents ab ===
system($OPENCLAW_BIN, 'memory', 'status', '--deep', '--fix') == 0 or die "memory status failed: $?";
system($OPENCLAW_BIN, 'memory', 'index', '--force') == 0 or die "memory index failed: $?";

# === 6. Memory promote – MUSS pro Agent ===
for my $agent (qw(main knecht docs ops-hub cron)) {
    system($OPENCLAW_BIN, 'memory', 'promote', '--apply', '--agent', $agent) == 0 or die "memory promote for $agent failed: $?";
}

# === 7. Secrets ===
system($OPENCLAW_BIN, 'secrets', 'reload') == 0 or die "secrets reload failed: $?";
