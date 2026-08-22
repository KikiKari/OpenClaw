#!/usr/bin/env perl
# pplx-setup.sh — portiert nach perl5
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use Cwd 'abs_path';

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.

my $home = $ENV{'HOME'} // die "HOME environment variable not set\n";

# Find the latest patchright directory
my $extpr = find_latest_patchright($home);

if (!$extpr) {
    print "[setup] extension patchright not found — is the Perplexity extension installed?\n";
    exit 0;
}

# Get the expected chromium path
my $exp = get_chromium_executable_path($extpr);

if ($exp && -x $exp) {
    print "[setup] daemon browser already present: $exp\n";
    exit 0;
}

print "[setup] installing matching chromium for the extension daemon (expected: " . ($exp || 'unknown') . ")...\n";
system("node", "$extpr/cli.js", "install", "chromium") == 0
    or die "Failed to install chromium\n";
print "[setup] done.\n";

sub find_latest_patchright {
    my ($home) = @_;
    my $extensions_dir = File::Spec->catdir($home, '.vscode-remote', 'extensions');
    return unless -d $extensions_dir;

    my @patchright_dirs;
    opendir(my $dh, $extensions_dir) or die "Cannot open directory $extensions_dir: $!\n";
    while (my $entry = readdir($dh)) {
        next unless $entry =~ /^nskha\.perplexity-vscode-/;
        my $path = File::Spec->catdir($extensions_dir, $entry, 'dist', 'node_modules', 'patchright');
        push @patchright_dirs, $path if -d $path;
    }
    closedir($dh);

    return unless @patchright_dirs;

    # Sort version-like strings numerically
    @patchright_dirs = sort { version_compare($a, $b) } @patchright_dirs;
    return $patchright_dirs[-1];
}

sub version_compare {
    my ($a, $b) = @_;
    my ($base_a) = $a =~ /nskha\.perplexity-vscode-(.*)/;
    my ($base_b) = $b =~ /nskha\.perplexity-vscode-(.*)/;
    
    # Simple version comparison by splitting on dots and comparing each part numerically
    my @parts_a = split /\./, $base_a // '';
    my @parts_b = split /\./, $base_b // '';
    
    for my $i (0 .. $#parts_a) {
        last if $i > $#parts_b;
        my $cmp = ($parts_a[$i] // 0) <=> ($parts_b[$i] // 0);
        return $cmp if $cmp != 0;
    }
    return @parts_a <=> @parts_b;
}

sub get_chromium_executable_path {
    my ($extpr) = @_;
    my $script = "const {chromium}=require('$extpr');console.log(chromium.executablePath())";
    
    open(my $node_fh, '-|', 'node', '-e', $script) or return undef;
    my $output = <$node_fh>;
    close($node_fh);
    
    chomp($output) if defined $output;
    return $output // undef;
}
