#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "fd9acec548e3605b392348bb9e430220f30ea2dcf3c89a0f1b1bd9f030090489", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "perl5"}
# bundled-plugin-build-entries.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd 'abs_path';
use JSON::PP;

# Konstanten
my $BUNDLED_PLUGIN_ROOT_DIR = "bundled-plugins";
my @TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS = qw(.ts .js .mts .cts .mjs .cjs);
my %NON_PACKAGED_BUNDLED_PLUGIN_DIRS = map { $_ => 1 } qw(qa-channel qa-lab);

# Hilfsfunktionen
sub to_posix_path {
    my ($value) = @_;
    $value =~ s/\\/\//g;
    return $value;
}

sub bundled_plugin_file {
    my ($id, $entry) = @_;
    return "$id/$entry";
}

sub bundled_dist_plugin_file {
    my ($id, $file) = @_;
    return "$id/dist/$file";
}

sub should_build_bundled_cluster {
    # Dummy-Implementierung - muss entsprechend der Logik aus optional-bundled-clusters.mjs angepasst werden
    return 1;
}

# Hauptfunktionen
sub read_bundled_plugin_package_json {
    my ($package_json_path) = @_;
    
    return undef unless -f $package_json_path;
    
    eval {
        open my $fh, '<', $package_json_path or die "Cannot open $package_json_path: $!";
        local $/;
        my $content = <$fh>;
        close $fh;
        return decode_json($content);
    };
    
    return undef if $@;
}

sub is_manifestless_bundled_runtime_support_package {
    my ($params) = @_;
    my $package_name = ref($params->{package_json}->{name}) eq 'SCALAR' ? ${$params->{package_json}->{name}} : '';
    return 0 unless $package_name eq "\@openclaw/$params->{dir_name}";
    return @{$params->{top_level_public_surface_entries}} > 0;
}

sub collect_plugin_source_entries {
    my ($package_json) = @_;
    
    my @package_entries = ();
    if (ref($package_json->{openclaw}->{extensions}) eq 'ARRAY') {
        @package_entries = grep { defined($_) && length($_) > 0 } @{$package_json->{openclaw}->{extensions}};
    }
    
    my $setup_entry = '';
    if (defined($package_json->{openclaw}->{setupEntry}) && 
        ref($package_json->{openclaw}->{setupEntry}) eq 'SCALAR' && 
        length(${$package_json->{openclaw}->{setupEntry}}) > 0) {
        $setup_entry = ${$package_json->{openclaw}->{setupEntry}};
    }
    
    if ($setup_entry) {
        my %seen;
        @package_entries = grep { !$seen{$_}++ } (@package_entries, $setup_entry);
    }
    
    return @package_entries ? @package_entries : ('./index.ts');
}

sub should_stage_bundled_plugin_runtime_dependencies {
    my ($package_json) = @_;
    return $package_json->{openclaw}->{bundle}->{stageRuntimeDependencies} // 0;
}

sub collect_top_level_public_surface_entries {
    my ($plugin_dir) = @_;
    
    return () unless -d $plugin_dir;
    
    opendir(my $dh, $plugin_dir) or return ();
    my @files = readdir($dh);
    closedir $dh;
    
    my @entries = ();
    for my $file (@files) {
        next if $file =~ /^\.\.?$/; # Überspringe . und ..
        
        my $full_path = File::Spec->catfile($plugin_dir, $file);
        next unless -f $full_path;
        
        my ($volume, $directories, $filename) = File::Spec->splitpath($full_path);
        my ($name, $ext) = $filename =~ /^(.+)(\.[^.]+)$/;
        next unless defined $ext && grep { $_ eq $ext } @TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS;
        
        my $normalizedName = lc($filename);
        next if $normalizedName =~ /\.d\.ts$/ || 
                $normalizedName =~ /^config-api\.(?:[cm]?[jt]s)$/ ||
                $normalizedName =~ /\.test\./ ||
                $normalizedName =~ /\.spec\./ ||
                $normalizedName =~ /\.fixture\./ ||
                $normalizedName =~ /\.snap/;
                
        push @entries, "./$filename";
    }
    
    @entries = sort @entries;
    return @entries;
}

sub collect_bundled_plugin_build_entries {
    my ($params) = @_;
    $params //= {};
    
    my $cwd = $params->{cwd} // getcwd();
    my $env = $params->{env} // \%ENV;
    
    my $extensions_root = File::Spec->catdir($cwd, $BUNDLED_PLUGIN_ROOT_DIR);
    my @entries = ();
    
    opendir(my $dh, $extensions_root) or die "Cannot open directory $extensions_root: $!";
    my @dirs = readdir($dh);
    closedir $dh;
    
    for my $dir (@dirs) {
        next if $dir =~ /^\.\.?$/; # Überspringe . und ..
        
        my $plugin_dir = File::Spec->catdir($extensions_root, $dir);
        next unless -d $plugin_dir;
        
        my $manifest_path = File::Spec->catfile($plugin_dir, 'openclaw.plugin.json');
        my $has_manifest = -f $manifest_path;
        
        my $package_json_path = File::Spec->catfile($plugin_dir, 'package.json');
        my $package_json = read_bundled_plugin_package_json($package_json_path);
        
        my @top_level_public_surface_entries = collect_top_level_public_surface_entries($plugin_dir);
        
        if (!$has_manifest && 
            !is_manifestless_bundled_runtime_support_package({
                dir_name => $dir,
                package_json => $package_json,
                top_level_public_surface_entries => \@top_level_public_surface_entries
            })) {
            next;
        }
        
        next unless should_build_bundled_cluster($dir, $env, { package_json => $package_json });
        
        my @source_entries = ();
        if ($has_manifest) {
            @source_entries = collect_plugin_source_entries($package_json);
        }
        push @source_entries, @top_level_public_surface_entries;
        
        my %seen;
        @source_entries = grep { !$seen{$_}++ } @source_entries;
        
        push @entries, {
            id => $dir,
            has_manifest => $has_manifest,
            has_package_json => defined($package_json),
            package_json => $package_json,
            source_entries => \@source_entries
        };
    }
    
    return @entries;
}

sub list_bundled_plugin_build_entries {
    my ($params) = @_;
    $params //= {};
    
    my @entries = collect_bundled_plugin_build_entries($params);
    my %result = ();
    
    for my $entry (@entries) {
        for my $source_entry (@{$entry->{source_entries}}) {
            my $normalized_entry = $source_entry;
            $normalized_entry =~ s/^\.\/+//;
            
            my $entry_key_base = $normalized_entry;
            $entry_key_base =~ s/\.[^.]+$//;
            
            my $entry_key = bundled_plugin_file($entry->{id}, $entry_key_base);
            my $path_value = to_posix_path(File::Spec->catfile($BUNDLED_PLUGIN_ROOT_DIR, $entry->{id}, $normalized_entry));
            
            $result{$entry_key} = $path_value;
        }
    }
    
    return %result;
}

sub list_bundled_plugin_pack_artifacts {
    my ($params) = @_;
    $params //= {};
    
    my @entries = collect_bundled_plugin_build_entries($params);
    my %artifacts = ();
    
    for my $entry (@entries) {
        next if exists $NON_PACKAGED_BUNDLED_PLUGIN_DIRS{$entry->{id}};
        
        if ($entry->{has_manifest}) {
            $artifacts{bundled_dist_plugin_file($entry->{id}, 'openclaw.plugin.json')} = 1;
        }
        
        if ($entry->{has_package_json}) {
            $artifacts{bundled_dist_plugin_file($entry->{id}, 'package.json')} = 1;
        }
        
        for my $source_entry (@{$entry->{source_entries}}) {
            my $normalized_entry = $source_entry;
            $normalized_entry =~ s/^\.\/+//;
            $normalized_entry =~ s/\.[^.]+$//;
            
            $artifacts{bundled_dist_plugin_file($entry->{id}, "${normalized_entry}.js")} = 1;
        }
    }
    
    my @sorted_artifacts = sort keys %artifacts;
    return @sorted_artifacts;
}

sub list_bundled_plugin_runtime_dependencies {
    my ($params) = @_;
    $params //= {};
    
    my %runtime_dependencies = ();
    my @entries = collect_bundled_plugin_build_entries($params);
    
    for my $entry (@entries) {
        next unless should_stage_bundled_plugin_runtime_dependencies($entry->{package_json});
        
        if (ref($entry->{package_json}->{dependencies}) eq 'HASH') {
            for my $dependency_name (keys %{$entry->{package_json}->{dependencies}}) {
                $runtime_dependencies{$dependency_name} = 1;
            }
        }
        
        if (ref($entry->{package_json}->{optionalDependencies}) eq 'HASH') {
            for my $dependency_name (keys %{$entry->{package_json}->{optionalDependencies}}) {
                $runtime_dependencies{$dependency_name} = 1;
            }
        }
    }
    
    my @sorted_deps = sort keys %runtime_dependencies;
    return @sorted_deps;
}

1;
