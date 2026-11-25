#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "2a2ae1fff974dcd7ea11eefc6cd003f69288df0b6cc9e75ac727ee0db1e92a4c", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "perl6"}
# pplx-status.sh — portiert nach perl6
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Quick status of the codespace Perplexity daemon session.
use v6;

my $CFG = %*ENV<PERPLEXITY_CONFIG_DIR> // "$*HOME/.perplexity-mcp";
my $PROFILE = %*ENV<PERPLEXITY_PROFILE> // "codespace";
my $STAT = "$CFG/profiles/$PROFILE/daemon-status.json";

if $STAT.IO.f {
    run <python3 -m json.tool>, $STAT;
} else {
    say "no daemon-status.json at $STAT";
}

say "--- recent auth lines ---";
my $log-file = "$CFG/daemon.log";
if $log-file.IO.f {
    my @lines = qqx[ grep -iE 'Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in' $log-file 2>/dev/null ].lines.tail(6);
    .say for @lines;
}
