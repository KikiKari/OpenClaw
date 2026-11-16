#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "c9e33bd17c532e24936176b5c614fcc7e22f7b831f01a60146cf058d7474dffc", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "perl5"}
# build-and-run-mac.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

# Change to the correct directory
my $script_dir = dirname(abs_path($0));
my $target_dir = File::Spec->catdir($script_dir, '..', 'apps', 'macos');
chdir($target_dir) or die "Cannot change directory to $target_dir: $!";

my $BUILD_PATH = ".build-local";
my $PRODUCT = "OpenClaw";
my $BIN = File::Spec->catfile($BUILD_PATH, "debug", $PRODUCT);

printf "\n▶️  Building $PRODUCT (debug, build path: $BUILD_PATH)\n";
system("swift", "build", "-c", "debug", "--product", $PRODUCT, "--build-path", $BUILD_PATH) == 0
    or die "Build failed: $?";

printf "\n⏹  Stopping existing $PRODUCT...\n";
system("killall", "-q", $PRODUCT);

printf "\n🚀 Launching $BIN ...\n";
defined(my $pid = fork) or die "Cannot fork: $!";
if ($pid == 0) {
    # Child process
    open(STDOUT, '>', '/tmp/openclaw.log') or die "Cannot redirect stdout: $!";
    open(STDERR, '>&STDOUT') or die "Cannot redirect stderr: $!";
    close(STDIN);
    exec($BIN) or die "Cannot exec $BIN: $!";
}
# Parent process
printf "Started $PRODUCT (PID $pid). Logs: /tmp/openclaw.log\n";
