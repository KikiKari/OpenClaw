#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "2c831f568de8930bbd560cf6b8d7db3da056e52ad23eca4580f15b1d5f0f4a25", "source_sha256": "dc65d4759ce1efe8d0c6f037b64d65c1aa1f73b83a3cd928ceebdaf24ed53da6", "target_language": "perl5"}
# stage-bundled-plugin-runtime.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use Cwd qw(abs_path getcwd);
use File::Find qw(find);
use Config;

# Helper functions
sub symlink_type {
    return $^O eq "MSWin32" ? "junction" : "dir";
}

sub relative_symlink_target {
    my ($source_path, $target_path) = @_;
    my $target_dir = dirname($target_path);
    my $relative_target = abs_path(File::Spec->abs2rel($source_path, $target_dir));
    return $relative_target || ".";
}

sub should_fallback_to_copy {
    my ($error) = @_;
    return $^O eq "MSWin32" && ($error->{code} eq "EPERM" || $error->{code} eq "EINVAL" || $error->{code} eq "UNKNOWN");
}

sub copy_path_fallback {
    my ($source_path, $target_path) = @_;
    remove_path_if_exists($target_path);
    my @stat = stat($source_path);
    make_path(dirname($target_path));
    if (-d $source_path) {
        system("cp", "-r", $source_path, $target_path);
        return;
    }
    copy($source_path, $target_path) or die "Copy failed: $!";
}

sub ensure_symlink {
    my ($target_value, $target_path, $type, $fallback_source_path) = @_;
    eval {
        symlink($target_value, $target_path) or die "Symlink failed: $!";
        return;
    };
    if ($@) {
        my $error = $@;
        if ($fallback_source_path && should_fallback_to_copy({ code => $! })) {
            copy_path_fallback($fallback_source_path, $target_path);
            return;
        }
        die $error unless $!{EEXIST};
    }

    eval {
        if (-l $target_path && readlink($target_path) eq $target_value) {
            return;
        }
    };

    remove_path_if_exists($target_path);
    eval {
        symlink($target_value, $target_path) or die "Symlink failed: $!";
    };
    if ($@) {
        my $error = $@;
        if ($fallback_source_path && should_fallback_to_copy({ code => $! })) {
            copy_path_fallback($fallback_source_path, $target_path);
            return;
        }
        die $error;
    }
}

sub symlink_path {
    my ($source_path, $target_path, $type) = @_;
    ensure_symlink(relative_symlink_target($source_path, $target_path), $target_path, $type, $source_path);
}

sub should_wrap_runtime_js_file {
    my ($source_path) = @_;
    return $source_path =~ /\.js$/;
}

sub should_copy_runtime_file {
    my ($source_path) = @_;
    my $relative_path = $source_path;
    $relative_path =~ s/\\/\//g;
    return $relative_path =~ m{/(package\.json|openclaw\.plugin\.json|\.codex-plugin/plugin\.json|\.claude-plugin/plugin\.json|\.cursor-plugin/plugin\.json|SKILL\.md)$};
}

sub write_runtime_module_wrapper {
    my ($source_path, $target_path) = @_;
    my $specifier = relative_symlink_target($source_path, $target_path);
    $specifier =~ s/\\/\//g;
    my $normalized_specifier = $specifier =~ /^\./ ? $specifier : "./$specifier";
    open(my $fh, '>', $target_path) or die "Cannot open $target_path: $!";
    print $fh "export * from " . to_json($normalized_specifier) . ";\n";
    print $fh "import * as module from " . to_json($normalized_specifier) . ";\n";
    print $fh "export default module.default;\n\n";
    close($fh);
}

sub to_json {
    my ($str) = @_;
    $str =~ s/"/\\"/g;
    return "\"$str\"";
}

sub stage_plugin_runtime_overlay {
    my ($source_dir, $target_dir) = @_;
    make_path($target_dir);
    opendir(my $dh, $source_dir) or die "Cannot opendir $source_dir: $!";
    while (readdir $dh) {
        next if $_ eq '.' || $_ eq '..';
        next if $_ eq 'node_modules';
        my $source_path = File::Spec->catfile($source_dir, $_);
        my $target_path = File::Spec->catfile($target_dir, $_);

        if (-d $source_path) {
            stage_plugin_runtime_overlay($source_path, $target_path);
            next;
        }

        if (-l $source_path) {
            ensure_symlink(readlink($source_path), $target_path, undef, $source_path);
            next;
        }

        unless (-f $source_path) {
            next;
        }

        if (should_wrap_runtime_js_file($source_path)) {
            write_runtime_module_wrapper($source_path, $target_path);
            next;
        }

        if (should_copy_runtime_file($source_path)) {
            copy($source_path, $target_path) or die "Copy failed: $!";
            next;
        }

        symlink_path($source_path, $target_path);
    }
    closedir $dh;
}

sub link_plugin_node_modules {
    my ($params) = @_;
    my $runtime_node_modules_dir = File::Spec->catdir($params->{runtimePluginDir}, "node_modules");
    remove_path_if_exists($runtime_node_modules_dir);
    return unless -d $params->{sourcePluginNodeModulesDir};
    ensure_symlink(
        $params->{sourcePluginNodeModulesDir},
        $runtime_node_modules_dir,
        symlink_type(),
        $params->{sourcePluginNodeModulesDir}
    );
}

sub remove_path_if_exists {
    my ($path) = @_;
    remove_tree($path) if -e $path;
}

sub dirname {
    my ($path) = @_;
    my @parts = split '/', $path;
    pop @parts;
    return join('/', @parts) || '/';
}

sub stage_bundled_plugin_runtime {
    my ($params) = @_;
    $params //= {};
    my $repo_root = $params->{cwd} // $params->{repoRoot} // getcwd();
    my $dist_root = File::Spec->catdir($repo_root, "dist");
    my $runtime_root = File::Spec->catdir($repo_root, "dist-runtime");
    my $dist_extensions_root = File::Spec->catdir($dist_root, "extensions");
    my $runtime_extensions_root = File::Spec->catdir($runtime_root, "extensions");

    unless (-d $dist_extensions_root) {
        remove_path_if_exists($runtime_root);
        return;
    }

    remove_path_if_exists($runtime_root);
    make_path($runtime_extensions_root);

    opendir(my $dh, $dist_extensions_root) or die "Cannot opendir $dist_extensions_root: $!";
    while (readdir $dh) {
        next unless -d File::Spec->catdir($dist_extensions_root, $_);
        my $dist_plugin_dir = File::Spec->catdir($dist_extensions_root, $_);
        my $runtime_plugin_dir = File::Spec->catdir($runtime_extensions_root, $_);
        my $dist_plugin_node_modules_dir = File::Spec->catdir($dist_plugin_dir, "node_modules");

        stage_plugin_runtime_overlay($dist_plugin_dir, $runtime_plugin_dir);
        link_plugin_node_modules({
            runtimePluginDir => $runtime_plugin_dir,
            sourcePluginNodeModulesDir => $dist_plugin_node_modules_dir
        });
    }
    closedir $dh;
}

# Main execution
stage_bundled_plugin_runtime();
