#!/usr/bin/perl
# test_sync.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/test_sync.py
# auch in: OpenClaw@gateway2:scripts/test_sync.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use lib '/home/openclaw/.openclaw/workspace/scripts';
use sync_clawhub_git qw(sync_to_git log);

# Test: db-maintainer ClawHub → Git (DRY-RUN)
print "=== TEST: db-maintainer sync (DRY-RUN) ===\n";
my $skill = "db-maintainer";
my $result = sync_to_git($skill, 1); # dry_run => true
print "Result: " . ($result ? 'SUCCESS' : 'FAILED') . "\n";
print "\n=== LOG-Inhalt ===\n";
open my $fh, '<', '/home/openclaw/.openclaw/workspace/logs/sync.log' or die "Kann Logdatei nicht öffnen: $!";
print <$fh>;
close $fh;
