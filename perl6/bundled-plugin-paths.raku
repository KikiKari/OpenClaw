#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "6d0b2d152ac9f54f5e72a2dcec6b815327ffbd9f6969f660822c8c4e33e9008c", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "perl6"}
# bundled-plugin-paths.mjs — portiert nach perl6
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use v6;

our $BUNDLED_PLUGIN_ROOT_DIR = 'extensions';
our $BUNDLED_PLUGIN_PATH_PREFIX = "{$BUNDLED_PLUGIN_ROOT_DIR}/";
our $BUNDLED_PLUGIN_TEST_GLOB = "{$BUNDLED_PLUGIN_ROOT_DIR}/**/*.test.ts";
our $BUNDLED_PLUGIN_E2E_TEST_GLOB = "{$BUNDLED_PLUGIN_ROOT_DIR}/**/*.e2e.test.ts";
our $BUNDLED_PLUGIN_LIVE_TEST_GLOB = "{$BUNDLED_PLUGIN_ROOT_DIR}/**/*.live.test.ts";

sub bundledPluginRoot($pluginId) {
    return "{$BUNDLED_PLUGIN_PATH_PREFIX}{$pluginId}";
}

sub bundledPluginFile($pluginId, $relativePath) {
    return "{bundledPluginRoot($pluginId)}/{$relativePath}";
}

sub bundledDistPluginRoot($pluginId) {
    return "dist/{bundledPluginRoot($pluginId)}";
}

sub bundledDistPluginFile($pluginId, $relativePath) {
    return "{bundledDistPluginRoot($pluginId)}/{$relativePath}";
}

sub bundledPluginCallsite($pluginId, $relativePath, $line) {
    return "{bundledPluginFile($pluginId, $relativePath)}:{$line}";
}

# Export symbols
our &bundledPluginRoot is export(:MANDATORY);
our &bundledPluginFile is export(:MANDATORY);
our &bundledDistPluginRoot is export(:MANDATORY);
our &bundledDistPluginFile is export(:MANDATORY);
our &bundledPluginCallsite is export(:MANDATORY);
our $BUNDLED_PLUGIN_ROOT_DIR is export(:MANDATORY);
our $BUNDLED_PLUGIN_PATH_PREFIX is export(:MANDATORY);
our $BUNDLED_PLUGIN_TEST_GLOB is export(:MANDATORY);
our $BUNDLED_PLUGIN_E2E_TEST_GLOB is export(:MANDATORY);
our $BUNDLED_PLUGIN_LIVE_TEST_GLOB is export(:MANDATORY);
