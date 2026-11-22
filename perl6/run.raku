#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "a1efa8009f80d7211c2c39888f7cfab6d998085a4d9ba29b457607d79db8aaf8", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "perl6"}
# run.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use v6;

my $repo-dir = '/repo';
chdir $repo-dir or die "Cannot change to directory $repo-dir: $!";

my $OPENCLAW_STATE_DIR = "/tmp/openclaw-test";
my $OPENCLAW_CONFIG_PATH = "$OPENCLAW_STATE_DIR/openclaw.json";

%*ENV<OPENCLAW_STATE_DIR> = $OPENCLAW_STATE_DIR;
%*ENV<OPENCLAW_CONFIG_PATH> = $OPENCLAW_CONFIG_PATH;

say "==> Build";
if run('pnpm', 'build', :out('/tmp/openclaw-cleanup-build.log'), :err('/tmp/openclaw-cleanup-build.log')) != 0 {
    say slurp('/tmp/openclaw-cleanup-build.log');
    exit 1;
}

say "==> Seed state";
mkdir "$OPENCLAW_STATE_DIR/credentials" unless "$OPENCLAW_STATE_DIR/credentials".IO ~~ :d;
mkdir "$OPENCLAW_STATE_DIR/agents/main/sessions" unless "$OPENCLAW_STATE_DIR/agents/main/sessions".IO ~~ :d;
spurt($OPENCLAW_CONFIG_PATH, '{}');
spurt("$OPENCLAW_STATE_DIR/credentials/marker.txt", "creds\n");
spurt("$OPENCLAW_STATE_DIR/agents/main/sessions/sessions.json", "session\n");

say "==> Reset (config+creds+sessions)";
if run('pnpm', 'openclaw', 'reset', '--scope', 'config+creds+sessions', '--yes', '--non-interactive', :out('/tmp/openclaw-cleanup-reset.log'), :err('/tmp/openclaw-cleanup-reset.log')) != 0 {
    say slurp('/tmp/openclaw-cleanup-reset.log');
    exit 1;
}

die "Config file still exists" if $OPENCLAW_CONFIG_PATH.IO ~~ :f;
die "Credentials directory still exists" if "$OPENCLAW_STATE_DIR/credentials".IO ~~ :d;
die "Sessions directory still exists" if "$OPENCLAW_STATE_DIR/agents/main/sessions".IO ~~ :d;

say "==> Recreate minimal config";
mkdir "$OPENCLAW_STATE_DIR/credentials" unless "$OPENCLAW_STATE_DIR/credentials".IO ~~ :d;
spurt($OPENCLAW_CONFIG_PATH, '{}');

say "==> Uninstall (state only)";
if run('pnpm', 'openclaw', 'uninstall', '--state', '--yes', '--non-interactive', :out('/tmp/openclaw-cleanup-uninstall.log'), :err('/tmp/openclaw-cleanup-uninstall.log')) != 0 {
    say slurp('/tmp/openclaw-cleanup-uninstall.log');
    exit 1;
}

die "State directory still exists" if $OPENCLAW_STATE_DIR.IO ~~ :d;

say "OK";
