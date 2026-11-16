#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "af0429e71e080cbe1632b151b148797f691a1770b12066abf431e8c127773e85", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "perl5"}
# bundle-a2ui.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

my $script_dir = dirname(__FILE__);
my $root_dir = dirname($script_dir);
$root_dir = abs_path($root_dir);

my $node_script = File::Spec->catfile($root_dir, 'scripts', 'bundle-a2ui.mjs');

exec("node", $node_script, @ARGV);
