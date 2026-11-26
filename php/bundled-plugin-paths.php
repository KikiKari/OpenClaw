<?php
// abstraction-provenance: {"artifact_sha256": "8deed3cf4938b9050dde688034516196d6ec63a726437579ab20f001e4720f9c", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "php"}
// bundled-plugin-paths.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
const BUNDLED_PLUGIN_ROOT_DIR = "extensions";
const BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_ROOT_DIR . "/";
const BUNDLED_PLUGIN_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR . "/**/*.test.ts";
const BUNDLED_PLUGIN_E2E_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR . "/**/*.e2e.test.ts";
const BUNDLED_PLUGIN_LIVE_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR . "/**/*.live.test.ts";

function bundledPluginRoot($pluginId) {
    return BUNDLED_PLUGIN_PATH_PREFIX . $pluginId;
}

function bundledPluginFile($pluginId, $relativePath) {
    return bundledPluginRoot($pluginId) . "/" . $relativePath;
}

function bundledDistPluginRoot($pluginId) {
    return "dist/" . bundledPluginRoot($pluginId);
}

function bundledDistPluginFile($pluginId, $relativePath) {
    return bundledDistPluginRoot($pluginId) . "/" . $relativePath;
}

function bundledPluginCallsite($pluginId, $relativePath, $line) {
    return bundledPluginFile($pluginId, $relativePath) . ":" . $line;
}

?>
