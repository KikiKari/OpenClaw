#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "35dfea83fcf096a3d1f720405c8a50389fe29d49fc78442f9df143a5e8ab1758", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "perl5"}
# bundled-plugin-paths.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

package BundledPluginPaths;

use Exporter 'import';
our @EXPORT_OK = qw(
    BUNDLED_PLUGIN_ROOT_DIR
    BUNDLED_PLUGIN_PATH_PREFIX
    BUNDLED_PLUGIN_TEST_GLOB
    BUNDLED_PLUGIN_E2E_TEST_GLOB
    BUNDLED_PLUGIN_LIVE_TEST_GLOB
    bundledPluginRoot
    bundledPluginFile
    bundledDistPluginRoot
    bundledDistPluginFile
    bundledPluginCallsite
);

use constant BUNDLED_PLUGIN_ROOT_DIR => "extensions";
use constant BUNDLED_PLUGIN_PATH_PREFIX => BUNDLED_PLUGIN_ROOT_DIR . "/";
use constant BUNDLED_PLUGIN_TEST_GLOB => BUNDLED_PLUGIN_ROOT_DIR . "/**/*.test.ts";
use constant BUNDLED_PLUGIN_E2E_TEST_GLOB => BUNDLED_PLUGIN_ROOT_DIR . "/**/*.e2e.test.ts";
use constant BUNDLED_PLUGIN_LIVE_TEST_GLOB => BUNDLED_PLUGIN_ROOT_DIR . "/**/*.live.test.ts";

sub bundledPluginRoot {
    my ($pluginId) = @_;
    return BUNDLED_PLUGIN_PATH_PREFIX . $pluginId;
}

sub bundledPluginFile {
    my ($pluginId, $relativePath) = @_;
    return bundledPluginRoot($pluginId) . "/" . $relativePath;
}

sub bundledDistPluginRoot {
    my ($pluginId) = @_;
    return "dist/" . bundledPluginRoot($pluginId);
}

sub bundledDistPluginFile {
    my ($pluginId, $relativePath) = @_;
    return bundledDistPluginRoot($pluginId) . "/" . $relativePath;
}

sub bundledPluginCallsite {
    my ($pluginId, $relativePath, $line) = @_;
    return bundledPluginFile($pluginId, $relativePath) . ":" . $line;
}

1;
