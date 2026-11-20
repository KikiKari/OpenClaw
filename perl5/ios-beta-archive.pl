#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "096f26e7d6346d1eaa8f0ef6472ff5b9f0201a7fd012c30e2e3e8b29c556f022", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "perl5"}
# ios-beta-archive.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use FindBin qw($RealBin);

sub usage {
    print <<'EOF';
Usage:
  scripts/ios-beta-archive.sh [--build-number 7]

Archives and exports a beta-release IPA locally without uploading.
EOF
}

my $BUILD_NUMBER = $ENV{IOS_BETA_BUILD_NUMBER} // '';
my $ROOT_DIR = dirname(dirname($RealBin));

my $help = 0;
GetOptions(
    'build-number=s' => \$BUILD_NUMBER,
    'help|h'         => \$help,
) or do {
    usage();
    exit 1;
};

if ($help) {
    usage();
    exit 0;
}

chdir "$ROOT_DIR/apps/ios" or die "Cannot change directory to $ROOT_DIR/apps/ios: $!";

$ENV{IOS_BETA_BUILD_NUMBER} = $BUILD_NUMBER;

exec 'fastlane', 'ios', 'beta_archive';
