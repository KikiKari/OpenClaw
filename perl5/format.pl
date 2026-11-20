#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "797f2810095297b60b43b71ab28240c514139e48ab92119d2c223d876753d5b5", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "perl5"}
# format.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

my $script_dir = dirname(abs_path($0));
my $root = abs_path("$script_dir/..");
my $config = "$root/.swiftformat";
my $sources = "$root/Sources";

system("swiftformat", "--config", $config, $sources) == 0
    or die "swiftformat failed: $?";
