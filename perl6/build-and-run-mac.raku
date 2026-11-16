#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "4c705a9e5410edb881e5f5ec5254d3705ec8875caf331c547457a4b7e3bf3af3", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "perl6"}
# build-and-run-mac.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use v6;

my $dir = $*PROGRAM.parent.child('../apps/macos').Str;
chdir $dir;

my $BUILD_PATH = ".build-local";
my $PRODUCT = "OpenClaw";
my $BIN = "$BUILD_PATH/debug/$PRODUCT";

say "\n▶️  Building $PRODUCT (debug, build path: $BUILD_PATH)";
run 'swift', 'build', '-c', 'debug', '--product', $PRODUCT, '--build-path', $BUILD_PATH;

say "\n⏹  Stopping existing $PRODUCT...";
try {
    run 'killall', '-q', $PRODUCT;
}

say "\n🚀 Launching $BIN ...";
my $proc = Proc::Async.new($BIN);
$proc.stdout.tap: -> $v { };
$proc.stderr.tap: -> $v { };
$proc.start;

# Sleep kurz damit Prozess starten kann
sleep 1;
my $PID = $proc.pid // 'unknown';

say "Started $PRODUCT (PID $PID). Logs: /tmp/openclaw.log";
