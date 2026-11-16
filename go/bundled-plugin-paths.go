// abstraction-provenance: {"artifact_sha256": "83f8b9a365fa35c91ba40dc650adb75b1f34593c2aa47c0e01b51c4a447ff088", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "go"}
// bundled-plugin-paths.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

const BUNDLED_PLUGIN_ROOT_DIR = "extensions"
const BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_ROOT_DIR + "/"
const BUNDLED_PLUGIN_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.test.ts"
const BUNDLED_PLUGIN_E2E_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.e2e.test.ts"
const BUNDLED_PLUGIN_LIVE_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.live.test.ts"

func bundledPluginRoot(pluginId string) string {
	return BUNDLED_PLUGIN_PATH_PREFIX + pluginId
}

func bundledPluginFile(pluginId string, relativePath string) string {
	return bundledPluginRoot(pluginId) + "/" + relativePath
}

func bundledDistPluginRoot(pluginId string) string {
	return "dist/" + bundledPluginRoot(pluginId)
}

func bundledDistPluginFile(pluginId string, relativePath string) string {
	return bundledDistPluginRoot(pluginId) + "/" + relativePath
}

func bundledPluginCallsite(pluginId string, relativePath string, line int) string {
	return bundledPluginFile(pluginId, relativePath) + ":" + string(rune(line))
}
