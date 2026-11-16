#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "ef772c77adbcdb8f9635183d45e7751a8f767a86aa3b34cefe9d5a809e93716f", "source_sha256": "b77d7ac77e305afea60b0aa9579426471649732bc9d7cb3bce3f14575d0d0bb6", "target_language": "perl5"}
# check-no-raw-window-open.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-window-open.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd qw(realpath);
use File::Basename;

# Helper functions
sub resolve_repo_root {
    my $script_path = shift;
    my $real_path = realpath($script_path);
    my $dir = dirname($real_path);
    while ($dir ne '/') {
        my $git_dir = File::Spec->catdir($dir, '.git');
        if (-d $git_dir) {
            return $dir;
        }
        $dir = dirname($dir);
    }
    die "Could not find repository root";
}

sub collect_typescript_files {
    my ($root_dir, $options) = @_;
    my @files;
    my %ignore_set = map { $_ => 1 } @{$options->{ignore} // []};
    my @suffixes = ('.ts', '.tsx', @{$options->{extra_test_suffixes} // []});

    find(sub {
        my $file = $File::Find::name;
        return unless -f $file;
        my $rel_file = File::Spec->abs2rel($file, $root_dir);
        return if exists $ignore_set{$rel_file};

        for my $suffix (@suffixes) {
            if (substr($file, -length($suffix)) eq $suffix) {
                push @files, $file;
                last;
            }
        }
    }, $root_dir);

    return @files;
}

sub to_line {
    my ($content_ref, $pos) = @_;
    my $line = 1;
    for my $i (0 .. $pos) {
        $line++ if substr($$content_ref, $i, 1) eq "\n";
    }
    return $line;
}

sub unwrap_expression {
    my $expr = shift;
    # Simplified unwrapping logic for Perl context
    return $expr;
}

# Main logic
my $repo_root = resolve_repo_root(__FILE__);
my $ui_source_dir = File::Spec->catdir($repo_root, 'ui', 'src', 'ui');
my $allowed_callsite = File::Spec->catfile($ui_source_dir, 'open-external-url.ts');

sub is_raw_window_open_call {
    my $expression = shift;
    # This is a simplified check; actual TypeScript AST parsing would be needed for full accuracy
    return $expression =~ /\b(window|globalThis)\.open\b/;
}

sub find_raw_window_open_lines {
    my ($content, $file_name) = @_;
    my @lines;
    my $pos = 0;
    while (($pos = index($content, 'open', $pos)) != -1) {
        my $before = substr($content, 0, $pos);
        if ($before =~ /(?:window|globalThis)\.\z/) {
            push @lines, to_line(\$content, $pos);
        }
        $pos++;
    }
    return @lines;
}

sub main {
    my @files = collect_typescript_files($ui_source_dir, {
        extra_test_suffixes => ['.browser.test.ts', '.node.test.ts'],
        ignore => [],
    });

    my @violations;
    for my $file_path (@files) {
        next if $file_path eq $allowed_callsite;

        open my $fh, '<', $file_path or die "Cannot read $file_path: $!";
        my $content = do { local $/; <$fh> };
        close $fh;

        my @lines = find_raw_window_open_lines($content, $file_path);
        for my $line (@lines) {
            my $rel_path = File::Spec->abs2rel($file_path, $repo_root);
            push @violations, "$rel_path:$line";
        }
    }

    if (@violations == 0) {
        return;
    }

    print STDERR "Found raw window.open usage outside safe helper:\n";
    for my $violation (@violations) {
        print STDERR "- $violation\n";
    }
    print STDERR "Use openExternalUrlSafe(...) from ui/src/ui/open-external-url.ts instead.\n";
    exit 1;
}

main() if !caller;
