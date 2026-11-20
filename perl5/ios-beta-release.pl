#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "2ee7a0ea5f911b1bddab38d0e38a5b0f7e82fc9c7e8c3b44314ae275881420b8", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "perl5"}
# ios-beta-release.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Cwd qw(abs_path);
use File::Basename;
use File::Spec;

my $usage = sub {
    print <<'EOF';
Usage:
  scripts/ios-beta-release.sh [--build-number 7]

Archives and uploads a beta-release IPA to TestFlight locally.
EOF
    exit shift // 0;
};

my $build_number = $ENV{IOS_BETA_BUILD_NUMBER} || '';
my $root_dir = dirname(dirname(abs_path($0)));

GetOptions(
    'build-number=s' => \$build_number,
    'help|h'         => sub { $usage->(0) },
) or $usage->(1);

# Handle extra arguments
if (@ARGV) {
    if ($ARGV[0] eq '--') {
        shift @ARGV;
    }
    if (@ARGV) {
        warn "Unknown argument: $ARGV[0]\n";
        $usage->(1);
    }
}

my $ios_dir = File::Spec->catdir($root_dir, 'apps', 'ios');
chdir $ios_dir or die "Cannot change directory to $ios_dir: $!";

$ENV{IOS_BETA_BUILD_NUMBER} = $build_number;

exec 'fastlane', 'ios', 'beta';
