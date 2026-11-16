#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "5017bc9260e439a4b5d244c9990b0fbc447ced2ff7de65d04f1bd6dd8eb871a8", "source_sha256": "00c9566941995c9087b6e678da6c1d9714313ba570c7e02eeada841de0f8ddde", "target_language": "perl5"}
# check-composite-action-input-interpolation.py — portiert nach perl5
# Quelle: python, workspace@local:skills/github-clones/openclaw/scripts/check-composite-action-input-interpolation.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::Spec;
use Cwd 'abs_path';

my $INPUT_INTERPOLATION_RE = qr/\$\{\{\s*inputs\./;
my $RUN_LINE_RE = qr/^(\s*)run:\s*(.*)$/;
my $USING_COMPOSITE_RE = qr/^\s*using:\s*composite\s*$/m;

sub indentation {
    my ($line) = @_;
    chomp $line;
    my $stripped = $line;
    $stripped =~ s/^\s+//;
    return length($line) - length($stripped);
}

sub scan_file {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or die "Cannot open $path: $!";
    my $text = do { local $/; <$fh> };
    close $fh;

    if ($text !~ /$USING_COMPOSITE_RE/) {
        return ();
    }

    my @lines = split /\n/, $text;
    my @violations = ();
    my $line_count = scalar @lines;
    my $index = 0;

    while ($index < $line_count) {
        my $line = $lines[$index];
        if ($line !~ /$RUN_LINE_RE/) {
            $index++;
            next;
        }

        my ($indent_match, $run_value) = ($1, $2);
        my $run_indent = length($indent_match);
        $run_value =~ s/^\s+|\s+$//g;
        my $line_no = $index + 1;

        if ($run_value && substr($run_value, 0, 1) ne '|' && substr($run_value, 0, 1) ne '>') {
            if ($run_value =~ /$INPUT_INTERPOLATION_RE/) {
                push @violations, [$line_no, $line];
            }
            $index++;
            next;
        }

        $index++;
        while ($index < $line_count) {
            my $script_line = $lines[$index];
            chomp $script_line;
            if ($script_line =~ /^\s*$/) {
                $index++;
                next;
            }
            if (indentation($script_line) <= $run_indent) {
                last;
            }
            if ($script_line =~ /$INPUT_INTERPOLATION_RE/) {
                push @violations, [$index + 1, $script_line];
            }
            $index++;
        }
    }

    return @violations;
}

sub main {
    my $root = ".github/actions";
    my @files = ();

    find(sub {
        return unless -f $_ && /^action\.y[a-z]*ml$/i;
        push @files, $File::Find::name;
    }, $root);

    @files = sort @files;
    my @all_violations = ();

    for my $file_path (@files) {
        my @violations = scan_file($file_path);
        for my $violation (@violations) {
            push @all_violations, [$file_path, $violation->[0], $violation->[1]];
        }
    }

    if (@all_violations) {
        print "Disallowed direct inputs interpolation in composite run blocks:\n";
        for my $violation (@all_violations) {
            my ($file_path, $line_no, $line) = @$violation;
            print "- $file_path:$line_no: $line\n";
        }
        print "Use env: and reference shell variables instead.\n";
        return 1;
    }

    print "No direct inputs interpolation found in composite run blocks.\n";
    return 0;
}

exit(main());
