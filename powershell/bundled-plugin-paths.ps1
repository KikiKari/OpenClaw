#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "aa30d2ad4014fcbe0019b93dc7efe2c4488abda023c678d327905c11a5e50299", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "powershell"}
# bundled-plugin-paths.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$BUNDLED_PLUGIN_ROOT_DIR = "extensions"
$BUNDLED_PLUGIN_PATH_PREFIX = "${BUNDLED_PLUGIN_ROOT_DIR}/"
$BUNDLED_PLUGIN_TEST_GLOB = "${BUNDLED_PLUGIN_ROOT_DIR}/**/*.test.ts"
$BUNDLED_PLUGIN_E2E_TEST_GLOB = "${BUNDLED_PLUGIN_ROOT_DIR}/**/*.e2e.test.ts"
$BUNDLED_PLUGIN_LIVE_TEST_GLOB = "${BUNDLED_PLUGIN_ROOT_DIR}/**/*.live.test.ts"

function bundledPluginRoot($pluginId) {
  return "${BUNDLED_PLUGIN_PATH_PREFIX}${pluginId}"
}

function bundledPluginFile($pluginId, $relativePath) {
  return "$(bundledPluginRoot -pluginId $pluginId)/${relativePath}"
}

function bundledDistPluginRoot($pluginId) {
  return "dist/$(bundledPluginRoot -pluginId $pluginId)"
}

function bundledDistPluginFile($pluginId, $relativePath) {
  return "$(bundledDistPluginRoot -pluginId $pluginId)/${relativePath}"
}

function bundledPluginCallsite($pluginId, $relativePath, $line) {
  return "$(bundledPluginFile -pluginId $pluginId -relativePath $relativePath):${line}"
}
