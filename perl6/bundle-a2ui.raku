#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "03a6181a2a70bb395e48adcf1ee4d7356b4901efb50577fbf8ba1ab0e54ecbf3", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "perl6"}
# bundle-a2ui.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use v6;

my $root-dir = $?FILE.IO.dirname.IO.parent.abspath;
my $script = $root-dir.add('scripts').add('bundle-a2ui.mjs').Str;

run('node', $script, @*ARGS);
