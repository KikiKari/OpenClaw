// abstraction-provenance: {"artifact_sha256": "ee1bd4d400e7439ec340bae275580c514a133e0dec16601a61537b67721b0917", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "fsharp"}
// bundled-plugin-paths.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module BundledPluginPaths

let BUNDLED_PLUGIN_ROOT_DIR = "extensions"
let BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_ROOT_DIR + "/"
let BUNDLED_PLUGIN_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.test.ts"
let BUNDLED_PLUGIN_E2E_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.e2e.test.ts"
let BUNDLED_PLUGIN_LIVE_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.live.test.ts"

let bundledPluginRoot pluginId =
    BUNDLED_PLUGIN_PATH_PREFIX + pluginId

let bundledPluginFile pluginId relativePath =
    (bundledPluginRoot pluginId) + "/" + relativePath

let bundledDistPluginRoot pluginId =
    "dist/" + (bundledPluginRoot pluginId)

let bundledDistPluginFile pluginId relativePath =
    (bundledDistPluginRoot pluginId) + "/" + relativePath

let bundledPluginCallsite pluginId relativePath line =
    (bundledPluginFile pluginId relativePath) + ":" + line
