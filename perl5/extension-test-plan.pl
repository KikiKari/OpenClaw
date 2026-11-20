#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "46dd50cb2c1c800592f8f4b9571df890311f39ab95dc1bfee5a936b30501a9c4", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "perl5"}
# extension-test-plan.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd 'abs_path';
use List::Util qw(reduce);

# Simulating Node.js path module behavior
sub path_resolve {
    my @parts = @_;
    return abs_path(File::Spec->catfile(@parts));
}

sub path_join {
    my @parts = @_;
    return File::Spec->catfile(@parts);
}

sub path_basename {
    my ($path) = @_;
    return (File::Spec->splitpath($path))[2];
}

sub path_relative {
    my ($from, $to) = @_;
    # Simplified relative path calculation
    my @from_parts = split /[\/\\]/, $from;
    my @to_parts = split /[\/\\]/, $to;
    my $common_length = 0;
    for (my $i = 0; $i < @from_parts && $i < @to_parts; $i++) {
        last if $from_parts[$i] ne $to_parts[$i];
        $common_length++;
    }
    my @up_dirs = ('..') x (@from_parts - $common_length);
    my @down_dirs = @to_parts[$common_length..$#to_parts];
    return join('/', @up_dirs, @down_dirs);
}

# Constants (simulated)
my $repo_root = path_resolve(__FILE__, '..', '..');
my $DEFAULT_EXTENSION_TEST_SHARD_COUNT = 6;
my $BUNDLED_PLUGIN_PATH_PREFIX = 'packages/bundled-plugins/';
my $BUNDLED_PLUGIN_ROOT_DIR = 'packages/bundled-plugins';

# Mock imports (these would need to be implemented based on actual content)
my @channel_test_roots = (); # Would need to import from vitest.channel-paths.mjs
my %is_extension_root_checks = (); # Would need to implement each checker

# Helper functions
sub normalize_relative {
    my ($input_path) = @_;
    $input_path =~ s/\\/\//g;
    return $input_path;
}

sub count_test_files {
    my ($root_path) = @_;
    my $total = 0;
    
    find(sub {
        return if $_ eq 'node_modules' || $_ eq 'dist';
        return unless /\.test\.tsx?$/;
        $total++ if -f $_;
    }, $root_path);
    
    return $total;
}

sub resolve_extension_directory {
    my ($target_arg, $cwd) = @_;
    $cwd //= getcwd();
    
    if ($target_arg) {
        my $as_given = path_resolve($cwd, $target_arg);
        if (-f path_join($as_given, 'package.json')) {
            return $as_given;
        }
        
        my $by_name = path_join($repo_root, $BUNDLED_PLUGIN_ROOT_DIR, $target_arg);
        if (-f path_join($by_name, 'package.json')) {
            return $by_name;
        }
        
        die "Unknown extension target \"$target_arg\". Use a plugin name like \"slack\" or a path inside the bundled plugin workspace tree.";
    }
    
    my $current = $cwd;
    while (1) {
        if (normalize_relative(path_relative($repo_root, $current)) =~ /^$BUNDLED_PLUGIN_PATH_PREFIX/ &&
            -f path_join($current, 'package.json')) {
            return $current;
        }
        my $parent = path_join($current, '..');
        last if $parent eq $current;
        $current = $parent;
    }
    
    die "No extension target provided, and current working directory is not inside the bundled plugin workspace tree.";
}

sub resolve_extension_test_plan {
    my (%params) = @_;
    my $cwd = $params{cwd} // getcwd();
    my $target_arg = $params{target_arg};
    my $extension_dir = resolve_extension_directory($target_arg, $cwd);
    my $extension_id = path_basename($extension_dir);
    my $relative_extension_dir = normalize_relative(path_relative($repo_root, $extension_dir));
    
    my @roots = ($relative_extension_dir);
    
    # These checks would need to be properly implemented
    my $uses_channel_config = grep { $_ ~~ @channel_test_roots } @roots;
    my $config = $uses_channel_config 
        ? "test/vitest/vitest.extension-channels.config.ts"
        : "test/vitest/vitest.extensions.config.ts"; # Default fallback
    
    my $test_file_count = reduce { $a + count_test_files(path_join($repo_root, $b)) } 0, @roots;
    
    return {
        config => $config,
        extension_dir => $relative_extension_dir,
        extension_id => $extension_id,
        has_tests => $test_file_count > 0,
        roots => \@roots,
        test_file_count => $test_file_count,
    };
}

sub merge_test_plans {
    my ($plans_ref) = @_;
    my %groups_by_config = ();
    
    for my $plan (@$plans_ref) {
        my $config = $plan->{config};
        if (!exists $groups_by_config{$config}) {
            $groups_by_config{$config} = {
                config => $config,
                extension_ids => [],
                roots => [],
                test_file_count => 0,
            };
        }
        
        my $current = $groups_by_config{$config};
        push @{$current->{extension_ids}}, $plan->{extension_id};
        push @{$current->{roots}}, @{$plan->{roots}};
        $current->{test_file_count} += $plan->{test_file_count};
    }
    
    my @plan_groups = map {
        $_->{extension_ids} = [sort @{$_->{extension_ids}}];
        $_->{roots} = [do { my %seen; grep { !$seen{$_}++ } @{$_->{roots}} }];
        $_;
    } sort { $a->{config} cmp $b->{config} } values %groups_by_config;
    
    return {
        extension_count => scalar @$plans_ref,
        extension_ids => [sort map { $_->{extension_id} } @$plans_ref],
        has_tests => @$plans_ref > 0,
        plan_groups => \@plan_groups,
        test_file_count => reduce { $a + $b->{test_file_count} } 0, @$plans_ref,
    };
}

sub resolve_extension_batch_plan {
    my (%params) = @_;
    my $cwd = $params{cwd} // getcwd();
    my $extension_ids_ref = $params{extension_ids} // []; # Would need list_available_extension_ids()
    my @plans = grep { $_->{has_tests} } map {
        resolve_extension_test_plan(cwd => $cwd, target_arg => $_)
    } @$extension_ids_ref;
    
    return merge_test_plans(\@plans);
}

sub pick_least_loaded_shard {
    my ($shards_ref) = @_;
    my $best_index = -1;
    
    for my $i (0 .. $#{$shards_ref}) {
        my $shard = $shards_ref->[$i];
        if ($best_index == -1) {
            $best_index = $i;
            next;
        }
        my $best = $shards_ref->[$best_index];
        if ($shard->{test_file_count} != $best->{test_file_count}) {
            $best_index = $shard->{test_file_count} < $best->{test_file_count} ? $i : $best_index;
            next;
        }
        if (@{$shard->{plans}} != @{$best->{plans}}) {
            $best_index = @{$shard->{plans}} < @{$best->{plans}} ? $i : $best_index;
            next;
        }
        $best_index = $i < $best_index ? $i : $best_index;
    }
    
    return $best_index;
}

sub create_extension_test_shards {
    my (%params) = @_;
    my $cwd = $params{cwd} // getcwd();
    my $extension_ids_ref = $params{extension_ids} // []; # Would need list_available_extension_ids()
    my $shard_count = int($params{shard_count} // 1) || 1;
    $shard_count = 1 if $shard_count < 1;
    
    my @plans = sort {
        $b->{test_file_count} <=> $a->{test_file_count} ||
        $a->{extension_id} cmp $b->{extension_id}
    } grep { $_->{has_tests} } map {
        resolve_extension_test_plan(cwd => $cwd, target_arg => $_)
    } @$extension_ids_ref;
    
    my $effective_shard_count = $shard_count < 1 ? 1 : $shard_count;
    $effective_shard_count = @plans if @plans < $effective_shard_count;
    $effective_shard_count = 1 if $effective_shard_count < 1;
    
    my @shards = map {
        {
            plans => [],
            test_file_count => 0,
        }
    } 1..$effective_shard_count;
    
    for my $plan (@plans) {
        my $target_index = pick_least_loaded_shard(\@shards);
        push @{$shards[$target_index]->{plans}}, $plan;
        $shards[$target_index]->{test_file_count} += $plan->{test_file_count};
    }
    
    my @result = map {
        my $index = $_;
        my $shard = $shards[$_];
        my $merged = merge_test_plans($shard->{plans});
        +{
            index => $index,
            check_name => "checks-node-extensions-shard-" . ($index + 1),
            %$merged,
        };
    } 0..$#shards;
    
    return [grep { $_->{has_tests} } @result];
}

# Exported constants and functions would go here
# In Perl, we typically don't export in the same way as JavaScript modules
# These would be accessible directly in this file's scope

1; # Module return value
