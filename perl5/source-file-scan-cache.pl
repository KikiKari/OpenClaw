#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "6f0957627ac701011382e573ceea1ddc201c781a2a8f1ecc47a90d717a168b97", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "perl5"}
# source-file-scan-cache.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd 'abs_path';
use JSON::PP;

my %scanCache = ();

sub normalizeRepoPath {
    my ($repoRoot, $filePath) = @_;
    my $relative = File::Spec->abs2rel($filePath, $repoRoot);
    $relative =~ s/\\/\//g;
    return $relative;
}

sub walkFiles {
    my ($params, $rootDir) = @_;
    my @out = ();
    my @entries = ();

    if (!-d $rootDir) {
        return \@out;
    }

    opendir(my $dh, $rootDir) or die "Cannot opendir $rootDir: $!";
    while (readdir $dh) {
        push @entries, $_ if $_ ne '.' && $_ ne '..';
    }
    closedir $dh;

    @entries = sort @entries;

    for my $entry (@entries) {
        my $entryPath = File::Spec->catfile($rootDir, $entry);
        if (-d $entryPath) {
            if (!$params->{ignoredDirNames}{$entry}) {
                my $subFiles = walkFiles($params, $entryPath);
                push @out, @$subFiles;
            }
            next;
        }
        if (-f $entryPath) {
            my ($ext) = $entry =~ /(\.[^.]+)$/;
            if (exists $params->{scanExtensions}{$ext}) {
                push @out, $entryPath;
            }
        }
    }
    return \@out;
}

sub collectSourceFileContents {
    my ($params) = @_;

    my $json = JSON::PP->new;
    my $cacheKey = $json->encode({
        repoRoot => $params->{repoRoot},
        scanRoots => [sort @{$params->{scanRoots}}],
        scanExtensions => [sort keys %{$params->{scanExtensions}}],
        ignoredDirNames => [sort keys %{$params->{ignoredDirNames}}],
    });

    if (exists $scanCache{$cacheKey}) {
        return $scanCache{$cacheKey};
    }

    my @allFiles = ();
    for my $root (@{$params->{scanRoots}}) {
        my $fullPath = File::Spec->catdir($params->{repoRoot}, $root);
        my $files = walkFiles($params, $fullPath);
        push @allFiles, @$files;
    }

    my @sortedFiles = sort {
        normalizeRepoPath($params->{repoRoot}, $a) cmp normalizeRepoPath($params->{repoRoot}, $b)
    } @allFiles;

    my @result = ();
    for my $filePath (@sortedFiles) {
        open my $fh, '<:encoding(UTF-8)', $filePath or die "Cannot open $filePath: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        push @result, {
            filePath => $filePath,
            relativeFile => normalizeRepoPath($params->{repoRoot}, $filePath),
            content => $content,
        };
    }

    $scanCache{$cacheKey} = \@result;
    return \@result;
}

1;
