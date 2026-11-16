#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "eed3f4875b6aa4f4919f252d51c52ee3a935e42206cf655bad3824556861912c", "source_sha256": "c76d61da97f14736857987d3dd8234160c73b0a1b52ade5aac72de04cc61e7e6", "target_language": "perl5"}
# check-no-conflict-markers.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-conflict-markers.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use Encode qw(decode);
use File::Spec;
use Cwd qw(getcwd abs_path);

sub is_binary_buffer {
    my ($buffer) = @_;
    return index($buffer, "\0") != -1;
}

sub find_conflict_marker_lines {
    my ($content) = @_;
    my @lines = split /\r?\n/, $content;
    my @matches;
    for my $i (0 .. $#lines) {
        my $line = $lines[$i];
        if ($line =~ /^<<<<<<<\s/ ||
            $line =~ /^|||||||\s/ ||
            $line eq "=======" ||
            $line =~ /^>>>>>>>\s/) {
            push @matches, $i + 1;
        }
    }
    return @matches;
}

sub list_tracked_files {
    my ($cwd) = @_;
    $cwd //= getcwd();
    
    open(my $fh, '-|', 'git', 'ls-files', '-z') or die "Cannot run git ls-files: $!";
    local $/;
    my $output = <$fh>;
    close($fh);
    
    my @files = split /\0/, $output;
    @files = grep { $_ ne '' } @files;
    
    return map { File::Spec->catfile($cwd, $_) } @files;
}

sub find_conflict_markers_in_files {
    my ($file_paths, $read_file) = @_;
    $read_file //= sub {
        my ($file) = @_;
        open my $fh, '<:raw', $file or die "Cannot open $file: $!";
        local $/;
        my $content = <$fh>;
        close $fh;
        return $content;
    };
    
    my @violations;
    for my $file_path (@$file_paths) {
        my $content;
        eval {
            $content = $read_file->($file_path);
        };
        if ($@) {
            next;
        }
        
        unless (ref($content) eq 'SCALAR' && defined $$content) {
            $content = \(defined $content ? $content : '');
        }
        
        if (is_binary_buffer($$content)) {
            next;
        }
        
        my $decoded_content = decode('UTF-8', $$content, Encode::FB_CROAK);
        my @lines = find_conflict_marker_lines($decoded_content);
        if (@lines > 0) {
            push @violations, {
                filePath => $file_path,
                lines => \@lines,
            };
        }
    }
    return @violations;
}

sub main {
    my $cwd = getcwd();
    my @file_paths = list_tracked_files($cwd);
    my @violations = find_conflict_markers_in_files(\@file_paths);
    
    if (@violations == 0) {
        return;
    }
    
    print STDERR "Found unresolved merge conflict markers:\n";
    for my $violation (@violations) {
        my $relative_path = File::Spec->abs2rel($violation->{filePath}, $cwd) || $violation->{filePath};
        print STDERR "- $relative_path:" . join(',', @{$violation->{lines}}) . "\n";
    }
    exit 1;
}

if (!caller) {
    eval {
        main();
    };
    if ($@) {
        print STDERR $@;
        exit 1;
    }
}

1;
