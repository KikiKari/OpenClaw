#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "910f314a305aed4be2b9b397f11dbf2a042f7be3ef25a0c33cc56dd30e33f53b", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "perl5"}
# translation-worker-node.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use File::Spec;

# Run on the selected node after transferring its native worker. JSON stdin is
# forwarded unchanged to the worker in run mode.

if (@ARGV != 2) {
    print STDERR "Usage: translation-worker-node.sh node2|node3|node4|node6 prepare|health|run\n";
    exit 2;
}

my ($node, $action) = @ARGV;

my ($worker, $expected);
if ($node eq 'node2') {
    $worker = '/home/node/.openclaw/workers/translation-worker';
    $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286';
} elsif ($node eq 'node3') {
    $worker = '/home/openclaw/.openclaw/workers/translation-worker';
    $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de';
} elsif ($node eq 'node4') {
    $worker = '/root/.openclaw/workers/translation-worker';
    $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286';
} elsif ($node eq 'node6') {
    $worker = '/home/node/.openclaw/workers/translation-worker';
    $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de';
} else {
    print STDERR "Unknown or non-POSIX node\n";
    exit 2;
}

unless ($action =~ /^(prepare|health|run)$/) {
    print STDERR "Unknown action\n";
    exit 2;
}

unless (-f $worker && !-l $worker) {
    print STDERR "Missing worker or symlink rejected: $worker\n";
    exit 1;
}

open(my $fh, '<', $worker) or die "Cannot open $worker: $!";
my $actual = sha256_hex(do { local $/; <$fh> });
close($fh);

if ($actual ne $expected) {
    print STDERR "Worker checksum mismatch: $worker\n";
    exit 1;
}

chmod 0755, $worker;

if ($action eq 'prepare') {
    print "Worker verified and executable: $worker\n";
} elsif ($action eq 'health') {
    exec($worker, '--health');
} elsif ($action eq 'run') {
    exec($worker);
}
