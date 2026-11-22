#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "6c4bba1e656b35bd37ef569f89b055b4f6e498730e4ecf40e063ee93b317ebcc", "source_sha256": "a06acfb1e69451fcfc8e5635f9059bac455efbbaca76e0edae285b866e7f8409", "target_language": "perl5"}
# run-node.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-node.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::Spec;
use Cwd 'abs_path';
use POSIX qw(strftime);
use JSON::PP;

# Konstanten
my $BUILD_SCRIPT = "scripts/tsdown-build.mjs";
my @COMPILER_ARGS = ($BUILD_SCRIPT, "--no-clean");

my @RUN_NODE_SOURCE_ROOTS = ("src", "bundled-plugins"); # BUNDLED_PLUGIN_ROOT_DIR
my @RUN_NODE_CONFIG_FILES = ("tsconfig.json", "package.json", "tsdown.config.ts");
my @RUN_NODE_WATCHED_PATHS = (@RUN_NODE_SOURCE_ROOTS, @RUN_NODE_CONFIG_FILES);
my $EXTENSION_SOURCE_FILE_PATTERN = qr/\.(?:[cm]?[jt]sx?)$/;
my %EXTENSION_RESTART_METADATA_FILES = map { $_ => 1 } ("openclaw.plugin.json", "package.json");

# Hilfsfunktionen
sub normalize_path {
    my ($file_path) = @_;
    $file_path //= "";
    $file_path =~ s|\\|/|g;
    return $file_path;
}

sub is_ignored_source_path {
    my ($relative_path) = @_;
    my $normalized_path = normalize_path($relative_path);
    return $normalized_path =~ /\.(test\.ts|test\.tsx|test-helpers\.ts)$/;
}

sub is_build_relevant_source_path {
    my ($relative_path) = @_;
    my $normalized_path = normalize_path($relative_path);
    return $normalized_path =~ /$EXTENSION_SOURCE_FILE_PATTERN/ && !is_ignored_source_path($normalized_path);
}

sub is_build_relevant_run_node_path {
    my ($repo_path) = @_;
    my $normalized_path = normalize_path($repo_path);
    $normalized_path =~ s|^\./*||;

    if (grep { $_ eq $normalized_path } @RUN_NODE_CONFIG_FILES) {
        return 1;
    }
    if ($normalized_path =~ /^src\//) {
        my $rel = substr($normalized_path, length("src/"));
        return !is_ignored_source_path($rel);
    }
    # BUNDLED_PLUGIN_PATH_PREFIX handling
    if ($normalized_path =~ /^bundled-plugins\//) {
        my $rel = substr($normalized_path, length("bundled-plugins/"));
        return is_build_relevant_source_path($rel);
    }
    return 0;
}

sub is_restart_relevant_extension_path {
    my ($relative_path) = @_;
    my $normalized_path = normalize_path($relative_path);
    my ($basename) = ($normalized_path =~ /([^\/]+)$/);
    if (exists $EXTENSION_RESTART_METADATA_FILES{$basename}) {
        return 1;
    }
    return is_build_relevant_source_path($normalized_path);
}

sub is_restart_relevant_run_node_path {
    my ($repo_path) = @_;
    my $normalized_path = normalize_path($repo_path);
    $normalized_path =~ s|^\./*||;

    if (grep { $_ eq $normalized_path } @RUN_NODE_CONFIG_FILES) {
        return 1;
    }
    if ($normalized_path =~ /^src\//) {
        my $rel = substr($normalized_path, length("src/"));
        return !is_ignored_source_path($rel);
    }
    if ($normalized_path =~ /^bundled-plugins\//) {
        my $rel = substr($normalized_path, length("bundled-plugins/"));
        return is_restart_relevant_extension_path($rel);
    }
    return 0;
}

sub stat_mtime {
    my ($file_path, $fs_impl) = @_;
    $fs_impl //= \&CORE::stat;
    my @stat_result = $fs_impl->($file_path);
    return @stat_result ? $stat_result[9] * 1000 + int($stat_result[9] * 1000) % 1000 : undef;
}

sub is_excluded_source {
    my ($file_path, $source_root, $source_root_name) = @_;
    my $relative_path = normalize_path(File::Spec->abs2rel($file_path, $source_root));
    if ($relative_path =~ /^\.\./) {
        return 0;
    }
    my $full_path = "src/$relative_path"; # Simplified assumption for src/
    if ($source_root_name ne "src") {
        $full_path = "$source_root_name/$relative_path";
    }
    return !is_build_relevant_run_node_path($full_path);
}

sub find_latest_mtime {
    my ($dir_path, $should_skip_subref, $deps_ref) = @_;
    my $latest = undef;
    my @queue = ($dir_path);
    while (@queue) {
        my $current = pop @queue;
        next unless defined $current;
        opendir(my $dh, $current) or next;
        my @entries = readdir($dh);
        closedir $dh;
        for my $entry (@entries) {
            next if $entry eq '.' || $entry eq '..';
            my $full_path = File::Spec->catfile($current, $entry);
            if (-d $full_path) {
                push @queue, $full_path;
                next;
            }
            next unless -f $full_path;
            if ($should_skip_subref && $should_skip_subref->($full_path)) {
                next;
            }
            my $mtime = stat_mtime($full_path, $deps_ref->{fs});
            next unless defined $mtime;
            if (!defined $latest || $mtime > $latest) {
                $latest = $mtime;
            }
        }
    }
    return $latest;
}

sub read_git_status {
    my ($deps_ref) = @_;
    eval {
        open(my $fh, "-|", "git", "status", "--porcelain", "--untracked-files=normal", "--", @RUN_NODE_WATCHED_PATHS) or die "Cannot run git status";
        my $output = do { local $/; <$fh> };
        close $fh;
        return $output // "";
    };
    return "" if $@;
    return "";
}

sub parse_git_status_paths {
    my ($output) = @_;
    my @lines = split /\n/, $output;
    my @paths = ();
    for my $line (@lines) {
        my @parts = split / -> /, substr($line, 3);
        for my $part (@parts) {
            my $trimmed = normalize_path(trim($part));
            push @paths, $trimmed if $trimmed;
        }
    }
    return @paths;
}

sub trim {
    my ($str) = @_;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub has_dirty_source_tree {
    my ($deps_ref) = @_;
    my $output = read_git_status($deps_ref);
    return undef if !defined $output || $output eq "";
    my @paths = parse_git_status_paths($output);
    for my $repo_path (@paths) {
        return 1 if is_build_relevant_run_node_path($repo_path);
    }
    return 0;
}

sub read_build_stamp {
    my ($deps_ref) = @_;
    my $mtime = stat_mtime($deps_ref->{buildStampPath}, $deps_ref->{fs});
    if (!defined $mtime) {
        return { mtime => undef, head => undef };
    }
    eval {
        open(my $fh, "<", $deps_ref->{buildStampPath}) or die "Cannot open build stamp";
        my $raw = do { local $/; <$fh> };
        close $fh;
        chomp $raw;
        if (!$raw || $raw !~ /^\{/) {
            return { mtime => $mtime, head => undef };
        }
        my $json = JSON::PP->new;
        my $parsed = $json->decode($raw);
        my $head = ref($parsed) eq 'HASH' && exists($parsed->{head}) && $parsed->{head} ? trim($parsed->{head}) : undef;
        return { mtime => $mtime, head => $head };
    };
    return { mtime => $mtime, head => undef } if $@;
    return { mtime => $mtime, head => undef };
}

sub has_source_mtime_changed {
    my ($stamp_mtime, $deps_ref) = @_;
    my $latest_source_mtime = undef;
    for my $source_root (@{$deps_ref->{sourceRoots}}) {
        my $source_mtime = find_latest_mtime(
            $source_root->{path},
            sub { is_excluded_source($_[0], $source_root->{path}, $source_root->{name}) },
            $deps_ref
        );
        if (defined $source_mtime && (!defined $latest_source_mtime || $source_mtime > $latest_source_mtime)) {
            $latest_source_mtime = $source_mtime;
        }
    }
    return defined $latest_source_mtime && $latest_source_mtime > $stamp_mtime;
}

sub resolve_build_requirement {
    my ($deps_ref) = @_;
    if (exists $deps_ref->{env}->{OPENCLAW_FORCE_BUILD} && $deps_ref->{env}->{OPENCLAW_FORCE_BUILD} eq "1") {
        return { shouldBuild => 1, reason => "force_build" };
    }
    my $stamp = read_build_stamp($deps_ref);
    if (!defined $stamp->{mtime}) {
        return { shouldBuild => 1, reason => "missing_build_stamp" };
    }
    if (!defined stat_mtime($deps_ref->{distEntry}, $deps_ref->{fs})) {
        return { shouldBuild => 1, reason => "missing_dist_entry" };
    }

    for my $file_path (@{$deps_ref->{configFiles}}) {
        my $mtime = stat_mtime($file_path, $deps_ref->{fs});
        if (defined $mtime && $mtime > $stamp->{mtime}) {
            return { shouldBuild => 1, reason => "config_newer" };
        }
    }

    # Dummy implementation for resolveGitHead - replace with actual logic
    my $current_head = ""; # resolveGitHead($deps_ref);
    if ($current_head && !$stamp->{head}) {
        return { shouldBuild => 1, reason => "build_stamp_missing_head" };
    }
    if ($current_head && $stamp->{head} && $current_head ne $stamp->{head}) {
        return { shouldBuild => 1, reason => "git_head_changed" };
    }
    if ($current_head) {
        my $dirty = has_dirty_source_tree($deps_ref);
        if ($dirty == 1) {
            return { shouldBuild => 1, reason => "dirty_watched_tree" };
        }
        if ($dirty == 0) {
            return { shouldBuild => 0, reason => "clean" };
        }
    }

    if (has_source_mtime_changed($stamp->{mtime}, $deps_ref)) {
        return { shouldBuild => 1, reason => "source_mtime_newer" };
    }
    return { shouldBuild => 0, reason => "clean" };
}

my %BUILD_REASON_LABELS = (
    force_build => "forced by OPENCLAW_FORCE_BUILD",
    missing_build_stamp => "build stamp missing",
    missing_dist_entry => "dist entry missing",
    config_newer => "config newer than build stamp",
    build_stamp_missing_head => "build stamp missing git head",
    git_head_changed => "git head changed",
    dirty_watched_tree => "dirty watched source tree",
    source_mtime_newer => "source mtime newer than build stamp",
    clean => "clean",
);

sub format_build_reason {
    my ($reason) = @_;
    return exists($BUILD_REASON_LABELS{$reason}) ? $BUILD_REASON_LABELS{$reason} : $reason;
}

my %SIGNAL_EXIT_CODES = (
    SIGINT => 130,
    SIGTERM => 143,
);

sub is_signal_key {
    my ($signal) = @_;
    return exists $SIGNAL_EXIT_CODES{$signal};
}

sub get_signal_exit_code {
    my ($signal) = @_;
    return is_signal_key($signal) ? $SIGNAL_EXIT_CODES{$signal} : 1;
}

sub log_runner {
    my ($message, $deps_ref) = @_;
    if (exists($deps_ref->{env}->{OPENCLAW_RUNNER_LOG}) && $deps_ref->{env}->{OPENCLAW_RUNNER_LOG} eq "0") {
        return;
    }
    print {$deps_ref->{stderr}} "[openclaw] $message\n";
}

# Dummy waitForSpawnedProcess - needs real implementation using fork/exec/waitpid
sub wait_for_spawned_process {
    my ($child_process, $deps_ref) = @_;
    # This is a simplified placeholder. Real implementation would require more complex signal handling.
    waitpid($child_process, 0);
    my $exit_code = $? >> 8;
    my $exit_signal = $? & 127;
    return { exitCode => $exit_code, exitSignal => $exit_signal, forwardedSignal => undef };
}

# Dummy runOpenClaw - needs real implementation
sub run_open_claw {
    my ($deps_ref) = @_;
    # Placeholder for spawning node process
    system("node", "openclaw.mjs", @{$deps_ref->{args}});
    return $? >> 8;
}

# Dummy syncRuntimeArtifacts - needs real implementation
sub sync_runtime_artifacts {
    my ($deps_ref) = @_;
    eval {
        # runRuntimePostBuild({ cwd => $deps_ref->{cwd} });
        1;
    } or do {
        log_runner("Failed to write runtime build artifacts: $@", $deps_ref);
        return 0;
    };
    return 1;
}

# Dummy writeBuildStamp - needs real implementation
sub write_build_stamp {
    my ($deps_ref) = @_;
    eval {
        # writeDistBuildStamp({
        #     cwd => $deps_ref->{cwd},
        #     fs => $deps_ref->{fs},
        #     spawnSync => $deps_ref->{spawnSync},
        # });
        1;
    } or do {
        log_runner("Failed to write build stamp: $@", $deps_ref);
    };
}

sub should_skip_clean_watch_runtime_sync {
    my ($deps_ref) = @_;
    return exists($deps_ref->{env}->{OPENCLAW_WATCH_MODE}) && $deps_ref->{env}->{OPENCLAW_WATCH_MODE} eq "1";
}

sub run_node_main {
    my (%params) = @_;
    my %deps = (
        spawn => $params{spawn} // sub { exec @_ }, # Simplified
        spawnSync => $params{spawnSync} // sub { system @_ }, # Simplified
        fs => $params{fs} // \&CORE::stat,
        stderr => $params{stderr} // *STDERR,
        process => $params{process} // {}, # Dummy
        execPath => $params{execPath} // $^X,
        cwd => $params{cwd} // abs_path("."),
        args => $params{args} // [@ARGV],
        env => $params{env} ? { %{$params{env}} } : { %ENV },
        runRuntimePostBuild => $params{runRuntimePostBuild} // sub {},
    );

    $deps{distRoot} = File::Spec->catdir($deps{cwd}, "dist");
    $deps{distEntry} = File::Spec->catfile($deps{distRoot}, "entry.js");
    $deps{buildStampPath} = File::Spec->catfile($deps{distRoot}, ".buildstamp");
    $deps{sourceRoots} = [
        map { { name => $_, path => File::Spec->catdir($deps{cwd}, $_) } } @RUN_NODE_SOURCE_ROOTS
    ];
    $deps{configFiles} = [
        map { File::Spec->catfile($deps{cwd}, $_) } @RUN_NODE_CONFIG_FILES
    ];

    my $build_requirement = resolve_build_requirement(\%deps);
    if (!$build_requirement->{shouldBuild}) {
        if (!should_skip_clean_watch_runtime_sync(\%deps) && !sync_runtime_artifacts(\%deps)) {
            return 1;
        }
        return run_open_claw(\%deps);
    }

    log_runner("Building TypeScript (dist is stale: $build_requirement->{reason} - " . format_build_reason($build_requirement->{reason}) . ").", \%deps);
    my $build_cmd = $deps{execPath};
    my @build_args = @COMPILER_ARGS;
    my $build_pid = fork();
    if ($build_pid == 0) {
        exec($build_cmd, @build_args) or die "Cannot exec: $!";
    }
    my $build_res = wait_for_spawned_process($build_pid, \%deps);
    if ($build_res->{exitSignal}) {
        return get_signal_exit_code($build_res->{exitSignal});
    }
    if ($build_res->{forwardedSignal}) {
        return get_signal_exit_code($build_res->{forwardedSignal});
    }
    if (defined $build_res->{exitCode} && $build_res->{exitCode} != 0 && $build_res->{exitCode} != 0) {
        return $build_res->{exitCode};
    }
    if (!sync_runtime_artifacts(\%deps)) {
        return 1;
    }
    write_build_stamp(\%deps);
    return run_open_claw(\%deps);
}

# Main execution block
if (!caller) {
    my $exit_code = run_node_main();
    exit($exit_code // 0);
}
1;
