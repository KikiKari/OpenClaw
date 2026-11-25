#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "9f6222c663f525a9b4af5ff1279e156fc04645d966846f9f58523709128992ad", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "perl5"}
# translation-worker-node5.ps1 — portiert nach perl5
# Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use File::Spec;
use Cwd 'abs_path';

# Parameter validation
my $action = $ARGV[0];
unless (defined $action && ($action eq 'prepare' || $action eq 'run')) {
    die "Usage: $0 {prepare|run}\n";
}

# Set error handling behavior equivalent to PowerShell's $ErrorActionPreference = 'Stop'
# Perl will automatically stop on errors with strict and warnings enabled

# Define paths
my $userprofile = $ENV{USERPROFILE} || $ENV{HOME} || die "Cannot determine user profile directory\n";
my $worker = File::Spec->catfile($userprofile, '.openclaw', 'workers', 'translation_worker.py');
my $expected = '9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b';

# Check if worker exists and is a regular file (not a symlink/reparse point)
unless (-f $worker) {
    die "Worker missing: $worker\n";
}

# Check for reparse point (symlink) - on Windows, we check the file attributes
# On Unix-like systems, we can use lstat to detect symlinks
if ($^O eq 'MSWin32') {
    # Use Win32::File to check for reparse points if available
    eval {
        require Win32::File;
        my $attrs;
        Win32::File::GetAttributes($worker, $attrs);
        # FILE_ATTRIBUTE_REPARSE_POINT = 0x400
        if ($attrs & 0x400) {
            die "Worker link rejected\n";
        }
    };
    # If Win32::File is not available, skip this check
} else {
    # On Unix-like systems, check if it's a symlink
    if (-l $worker) {
        die "Worker link rejected\n";
    }
}

# Calculate SHA256 hash of the worker file
open(my $fh, '<', $worker) or die "Cannot open $worker: $!\n";
binmode($fh);
my $digest = sha256_hex($fh);
close($fh);

unless ($digest eq $expected) {
    die "Worker checksum mismatch\n";
}

# Find python executable
my $python = `where python.exe 2>nul`;
chomp($python);
unless ($python && -x $python) {
    # Try alternatives
    for my $py_cmd (qw(python3 python)) {
        $python = `where $py_cmd 2>nul`;
        chomp($python);
        if ($python && -x $python) {
            last;
        }
    }
    unless ($python && -x $python) {
        die "Python executable not found\n";
    }
}

# Prepare action
if ($action eq 'prepare') {
    print "Worker verified: $worker\n";
    exit 0;
}

# Run action
system($python, $worker);
my $exit_code = $? >> 8;
exit $exit_code;
