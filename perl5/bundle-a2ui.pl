#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "994c772be93e8b84993b00f61dfdccbf596fdbe387941872657ba08ddb778e5d", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "perl5"}
# bundle-a2ui.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::Spec;
use File::Path qw(make_path);
use Digest::SHA qw(sha256_hex);
use Cwd qw(abs_path getcwd);
use Config;

# Globale Variablen
my $script_dir = dirname(abs_path($0));
my $root_dir = abs_path("$script_dir/..");
my $hash_file = "$root_dir/src/canvas-host/a2ui/.bundle.hash";
my $output_file = "$root_dir/src/canvas-host/a2ui/a2ui.bundle.js";
my $a2ui_renderer_dir = "$root_dir/vendor/a2ui/renderers/lit";
my $a2ui_app_dir = "$root_dir/apps/shared/OpenClawKit/Tools/CanvasA2UI";
my @input_paths = (
    "$root_dir/package.json",
    "$root_dir/pnpm-lock.yaml",
    $a2ui_renderer_dir,
    $a2ui_app_dir,
);
my @ignored_bundle_hash_input_prefixes = ("vendor/a2ui/renderers/lit/dist");

sub dirname {
    my ($path) = @_;
    $path =~ s/[\/\\][^\/\\]*$//;
    return $path;
}

sub fail {
    my ($message) = @_;
    print STDERR "$message\n";
    print STDERR "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle\n";
    print STDERR "If this persists, verify pnpm deps and try again.\n";
    exit 1;
}

sub path_exists {
    my ($target_path) = @_;
    return -e $target_path;
}

sub normalize_path {
    my ($file_path) = @_;
    $file_path =~ s/\\/\//g;
    return $file_path;
}

sub is_bundle_hash_input_path {
    my ($file_path, $repo_root) = @_;
    $repo_root //= $root_dir;
    my $relative_path = normalize_path(File::Spec->abs2rel($file_path, $repo_root));
    for my $ignored_path (@ignored_bundle_hash_input_prefixes) {
        if ($relative_path eq $ignored_path || $relative_path =~ /^$ignored_path\//) {
            return 0;
        }
    }
    return 1;
}

sub get_local_rolldown_cli_candidates {
    my ($repo_root) = @_;
    $repo_root //= $root_dir;
    return (
        "$repo_root/node_modules/rolldown/bin/cli.mjs",
        "$repo_root/node_modules/.pnpm/node_modules/rolldown/bin/cli.mjs",
        "$repo_root/node_modules/.pnpm/rolldown\@1.0.0-rc.12/node_modules/rolldown/bin/cli.mjs"
    );
}

sub walk_files {
    my ($entry_path, $files_ref) = @_;
    if (!is_bundle_hash_input_path($entry_path)) {
        return;
    }
    if (-d $entry_path) {
        opendir(my $dh, $entry_path) or return;
        while (my $entry = readdir($dh)) {
            next if $entry eq '.' || $entry eq '..';
            walk_files(File::Spec->catdir($entry_path, $entry), $files_ref);
        }
        closedir($dh);
    } else {
        push @$files_ref, $entry_path;
    }
}

sub list_tracked_input_files {
    my @cmd = ('git', 'ls-files', '--', map { normalize_path(File::Spec->abs2rel($_, $root_dir)) } @input_paths);
    open(my $fh, '-|', @cmd) or return undef;
    my @files;
    while (my $line = <$fh>) {
        chomp $line;
        next unless $line;
        my $full_path = File::Spec->catfile($root_dir, $line);
        if (is_bundle_hash_input_path($full_path)) {
            push @files, $full_path;
        }
    }
    close($fh);
    return \@files;
}

sub compute_hash {
    my $files_ref = list_tracked_input_files();
    if (!$files_ref) {
        my @files;
        for my $input_path (@input_paths) {
            walk_files($input_path, \@files);
        }
        $files_ref = \@files;
    }
    
    # Sortieren
    @$files_ref = sort { normalize_path($a) cmp normalize_path($b) } @$files_ref;
    
    my $hash_data = '';
    for my $file_path (@$files_ref) {
        $hash_data .= normalize_path(File::Spec->abs2rel($file_path, $root_dir)) . "\0";
        if (open(my $fh, '<', $file_path)) {
            local $/;
            $hash_data .= <$fh> . "\0";
            close($fh);
        }
    }
    
    return sha256_hex($hash_data);
}

sub run_step {
    my ($command, $args_ref, $options_ref) = @_;
    $options_ref //= {};
    
    my @cmd = ($command, @$args_ref);
    system(@cmd) == 0 or die "Command failed: $command";
}

sub run_pnpm {
    my ($pnpm_args_ref) = @_;
    my @cmd = ($^X, '-S', 'pnpm', @$pnpm_args_ref);
    system(@cmd) == 0 or die "Pnpm command failed";
}

sub main {
    my $has_renderer_dir = path_exists($a2ui_renderer_dir);
    my $has_app_dir = path_exists($a2ui_app_dir);
    my $has_output_file = path_exists($output_file);
    
    if (!$has_renderer_dir || !$has_app_dir) {
        if ($has_output_file) {
            print "A2UI sources missing; keeping prebuilt bundle.\n";
            return;
        }
        if ($ENV{OPENCLAW_SPARSE_PROFILE} || $ENV{OPENCLAW_A2UI_SKIP_MISSING} eq "1") {
            print STDERR "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set.\n";
            return;
        }
        fail("A2UI sources missing and no prebuilt bundle found at: $output_file");
    }
    
    my $current_hash = compute_hash();
    if (path_exists($hash_file)) {
        open(my $fh, '<', $hash_file) or die "Cannot read $hash_file: $!";
        my $previous_hash = <$fh>;
        chomp $previous_hash;
        close($fh);
        if ($previous_hash eq $current_hash && $has_output_file) {
            print "A2UI bundle up to date; skipping.\n";
            return;
        }
    }
    
    run_pnpm(['-s', 'exec', 'tsc', '-p', "$a2ui_renderer_dir/tsconfig.json"]);
    
    my @local_rolldown_cli_candidates = get_local_rolldown_cli_candidates($root_dir);
    my $local_rolldown_cli;
    for my $candidate (@local_rolldown_cli_candidates) {
        if (path_exists($candidate)) {
            $local_rolldown_cli = $candidate;
            last;
        }
    }
    
    if ($local_rolldown_cli) {
        run_step($^X, [$local_rolldown_cli, '-c', "$a2ui_app_dir/rolldown.config.mjs"]);
    } else {
        run_pnpm(['-s', 'exec', 'rolldown', '-c', "$a2ui_app_dir/rolldown.config.mjs"]);
    }
    
    open(my $fh, '>', $hash_file) or die "Cannot write $hash_file: $!";
    print $fh "$current_hash\n";
    close($fh);
}

eval {
    main();
};
if ($@) {
    fail($@);
}
