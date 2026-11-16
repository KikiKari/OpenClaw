#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "fdbed993d3a8d1fef82dc26b8d44f2eb772f467fda9e25e19a931966c275cefa", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "perl5"}
# callsite-guard.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::Spec;
use Cwd 'abs_path';

# Lade benötigte Module
require "./ts-guard-utils.pl";

sub run_callsite_guard {
    my ($params) = @_;

    my $repo_root = resolve_repo_root($params->{import_meta_url});
    my $source_roots = resolve_source_roots($repo_root, $params->{source_roots});
    my $files = collect_typescript_files_from_roots($source_roots, {
        extra_test_suffixes => $params->{extra_test_suffixes},
    });

    my @violations = ();

    for my $file_path (@$files) {
        my $rel_path = File::Spec->abs2rel($file_path, $repo_root);
        $rel_path =~ s!\\!/!g; # Ersetze Backslashes durch Slashes

        if ($params->{skip_relative_path} && $params->{skip_relative_path}->($rel_path)) {
            next;
        }

        open(my $fh, '<:encoding(UTF-8)', $file_path)
            or die "Could not open file '$file_path': $!";
        my $content = do { local $/; <$fh> };
        close($fh);

        my $lines = $params->{find_call_lines}($content, $file_path);
        for my $line (@$lines) {
            my $callsite = "$rel_path:$line";
            if ($params->{allow_callsite} && $params->{allow_callsite}->($callsite)) {
                next;
            }
            push @violations, $callsite;
        }
    }

    if (@violations == 0) {
        return;
    }

    warn $params->{header} . "\n";
    my @output = defined $params->{sort_violations} && !$params->{sort_violations}
        ? @violations
        : sort @violations;

    for my $violation (@output) {
        warn "- $violation\n";
    }

    if ($params->{footer}) {
        warn $params->{footer} . "\n";
    }

    exit 1;
}

1; # Modul lädt erfolgreich
