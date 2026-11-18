#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "179e311fb0aaabca72fd4ebdbdcaaede050270ad4c598e94d93edd1756878741", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "perl5"}
# pplx-setup.sh — portiert nach perl5
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Glob ':glob';
use Cwd 'abs_path';

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.

my $home = $ENV{HOME};
my @ext_paths = bsd_glob("$home/.vscode-remote/extensions/nskha.perplexity-vscode-*/dist/node_modules/patchright");

# Sort by version and get the latest
my @sorted_paths = sort { 
    my ($a_ver) = $a =~ /perplexity-vscode-(.*?)\//;
    my ($b_ver) = $b =~ /perplexity-vscode-(.*?)\//;
    version_compare($a_ver // '', $b_ver // '');
} @ext_paths;

my $extpr = @sorted_paths ? $sorted_paths[-1] : '';

if (!$extpr) {
    print "[setup] extension patchright not found — is the Perplexity extension installed?\n";
    exit 0;
}

# Try to get the expected path from node
my $exp = '';
eval {
    open(my $fh, '-|', "node -e \"const {chromium}=require('$extpr');console.log(chromium.executablePath())\" 2>/dev/null") or die $!;
    chomp($exp = <$fh>);
    close($fh);
};

if ($exp && -x $exp) {
    print "[setup] daemon browser already present: $exp\n";
    exit 0;
}

print "[setup] installing matching chromium for the extension daemon (expected: " . ($exp || 'unknown') . ")...\n";
system("node", "$extpr/cli.js", "install", "chromium") == 0 or die "Failed to install chromium";
print "[setup] done.\n";

sub version_compare {
    my ($a, $b) = @_;
    # Simple version comparison - split by dots and compare numerically
    my @a_parts = split /\./, $a;
    my @b_parts = split /\./, $b;
    
    for my $i (0 .. $#a_parts) {
        return -1 if $i > $#b_parts;
        my $cmp = ($a_parts[$i] // 0) <=> ($b_parts[$i] // 0);
        return $cmp if $cmp != 0;
    }
    
    return @b_parts <=> @a_parts;
}
