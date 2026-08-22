#!/usr/bin/env perl
# pplx-status.sh — portiert nach perl5
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use File::Spec;
use File::HomeDir;

# Quick status of the codespace Perplexity daemon session.

my $cfg = $ENV{'PERPLEXITY_CONFIG_DIR'} // File::Spec->catdir(File::HomeDir->my_home, '.perplexity-mcp');
my $profile = $ENV{'PERPLEXITY_PROFILE'} // 'codespace';
my $stat = File::Spec->catfile($cfg, 'profiles', $profile, 'daemon-status.json');

if (-f $stat) {
    open my $fh, '<', $stat or die "Cannot open $stat: $!";
    my $json_text = do { local $/; <$fh> };
    close $fh;
    
    my $json = decode_json($json_text);
    print to_json($json, { pretty => 1 }) . "\n";
} else {
    print "no daemon-status.json at $stat\n";
}

print "--- recent auth lines ---\n";

my $log_file = File::Spec->catfile($cfg, 'daemon.log');
if (-f $log_file) {
    open my $fh, '<', $log_file or die "Cannot open $log_file: $!";
    my @lines = <$fh>;
    close $fh;
    
    chomp @lines;
    my @filtered_lines = grep { /Authenticated as user/i || /Account tier/i || /Injected .* cookies/i || /Reinit requested/i || /not-logged-in/i } @lines;
    
    my $count = @filtered_lines;
    if ($count > 0) {
        my $start = $count > 6 ? $count - 6 : 0;
        foreach my $i ($start .. $count - 1) {
            print $filtered_lines[$i] . "\n";
        }
    }
}
