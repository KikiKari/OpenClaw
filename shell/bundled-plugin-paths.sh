#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "ac98ca16cf5e7d49a4d91f34e1defbe3be44e66ded2de7034fcba8a7c6fb9aee", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "shell"}
# bundled-plugin-paths.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

BUNDLED_PLUGIN_ROOT_DIR="extensions"
BUNDLED_PLUGIN_PATH_PREFIX="${BUNDLED_PLUGIN_ROOT_DIR}/"
BUNDLED_PLUGIN_TEST_GLOB="${BUNDLED_PLUGIN_ROOT_DIR}/**/*.test.ts"
BUNDLED_PLUGIN_E2E_TEST_GLOB="${BUNDLED_PLUGIN_ROOT_DIR}/**/*.e2e.test.ts"
BUNDLED_PLUGIN_LIVE_TEST_GLOB="${BUNDLED_PLUGIN_ROOT_DIR}/**/*.live.test.ts"

bundledPluginRoot() {
  local pluginId="$1"
  echo "${BUNDLED_PLUGIN_PATH_PREFIX}${pluginId}"
}

bundledPluginFile() {
  local pluginId="$1"
  local relativePath="$2"
  echo "$(bundledPluginRoot "${pluginId}")/${relativePath}"
}

bundledDistPluginRoot() {
  local pluginId="$1"
  echo "dist/$(bundledPluginRoot "${pluginId}")"
}

bundledDistPluginFile() {
  local pluginId="$1"
  local relativePath="$2"
  echo "$(bundledDistPluginRoot "${pluginId}")/${relativePath}"
}

bundledPluginCallsite() {
  local pluginId="$1"
  local relativePath="$2"
  local line="$3"
  echo "$(bundledPluginFile "${pluginId}" "${relativePath}"):${line}"
}
