#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "65263c4257ac1da08f3f2001a7d59c41c4b4f79de10432b75d17ca7840fd972d", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "perl5"}
# pplx-status.sh — portiert nach perl5
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON::PP;
use File::Spec;

# Quick status of the codespace Perplexity daemon session.
my $CFG = $ENV{'PERPLEXITY_CONFIG_DIR'} // "$ENV{'HOME'}/.perplexity-mcp";
my $PROFILE = $ENV{'PERPLEXITY_PROFILE'} // 'codespace';
my $STAT = File::Spec->catfile($CFG, 'profiles', $PROFILE, 'daemon-status.json');

if (-f $STAT) {
    open my $fh, '<', $STAT or die "Cannot open $STAT: $!";
    my $json_text = do { local $/; <$fh> };
    close $fh;
    
    my $json = JSON::PP->new->pretty->decode($json_text);
    print JSON::PP->new->pretty->encode($json);
} else {
    print "no daemon-status.json at $STAT\n";
}

print "--- recent auth lines ---\n";
my $log_file = File::Spec->catfile($CFG, 'daemon.log');
if (-f $log_file) {
    open my $fh, '<', $log_file or die "Cannot open $log_file: $!";
    my @lines = <$fh>;
    close $fh;
    
    # Filter lines matching the patterns (case insensitive)
    my @filtered = grep { /Authenticated as user/i || /Account tier/i || /Injected .* cookies/i || /Reinit requested/i || /not-logged-in/i } @lines;
    
    # Get last 6 lines
    my $count = scalar @filtered;
    my $start = $count > 6 ? $count - 6 : 0;
    print @filtered[$start..$#filtered];
}
