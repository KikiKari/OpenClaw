#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "59314a3abf2c3762c06349ff90d0f1554b481070baa8321a1a5cf0fc6d9358ad", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "perl5"}
# run.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use autodie;
use File::Path qw(make_path remove_tree);
use File::Spec;

chdir '/repo';

$ENV{OPENCLAW_STATE_DIR} = "/tmp/openclaw-test";
$ENV{OPENCLAW_CONFIG_PATH} = "$ENV{OPENCLAW_STATE_DIR}/openclaw.json";

print "==> Build\n";
system("pnpm build > /tmp/openclaw-cleanup-build.log 2>&1") == 0 or do {
    system("cat /tmp/openclaw-cleanup-build.log");
    exit 1;
};

print "==> Seed state\n";
make_path("$ENV{OPENCLAW_STATE_DIR}/credentials");
make_path("$ENV{OPENCLAW_STATE_DIR}/agents/main/sessions");
open my $fh, '>', $ENV{OPENCLAW_CONFIG_PATH};
print $fh "{}\n";
close $fh;
open $fh, '>', "$ENV{OPENCLAW_STATE_DIR}/credentials/marker.txt";
print $fh "creds\n";
close $fh;
open $fh, '>', "$ENV{OPENCLAW_STATE_DIR}/agents/main/sessions/sessions.json";
print $fh "session\n";
close $fh;

print "==> Reset (config+creds+sessions)\n";
system("pnpm openclaw reset --scope config+creds+sessions --yes --non-interactive > /tmp/openclaw-cleanup-reset.log 2>&1") == 0 or do {
    system("cat /tmp/openclaw-cleanup-reset.log");
    exit 1;
};

die "Config file still exists" if -f $ENV{OPENCLAW_CONFIG_PATH};
die "Credentials dir still exists" if -d "$ENV{OPENCLAW_STATE_DIR}/credentials";
die "Sessions dir still exists" if -d "$ENV{OPENCLAW_STATE_DIR}/agents/main/sessions";

print "==> Recreate minimal config\n";
make_path("$ENV{OPENCLAW_STATE_DIR}/credentials");
open $fh, '>', $ENV{OPENCLAW_CONFIG_PATH};
print $fh "{}\n";
close $fh;

print "==> Uninstall (state only)\n";
system("pnpm openclaw uninstall --state --yes --non-interactive > /tmp/openclaw-cleanup-uninstall.log 2>&1") == 0 or do {
    system("cat /tmp/openclaw-cleanup-uninstall.log");
    exit 1;
};

die "State dir still exists" if -d $ENV{OPENCLAW_STATE_DIR};

print "OK\n";
