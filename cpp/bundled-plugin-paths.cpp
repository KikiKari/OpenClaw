// abstraction-provenance: {"artifact_sha256": "23c9cc989e91397a8ff32782f06a4d693cafc85fa5ff53aadfdd9500c97bea93", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "cpp"}
// bundled-plugin-paths.mjs — portiert nach cpp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#ifndef BUNDLED_PLUGIN_PATHS_H
#define BUNDLED_PLUGIN_PATHS_H

#include <string>

const std::string BUNDLED_PLUGIN_ROOT_DIR = "extensions";
const std::string BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_ROOT_DIR + "/";
const std::string BUNDLED_PLUGIN_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.test.ts";
const std::string BUNDLED_PLUGIN_E2E_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.e2e.test.ts";
const std::string BUNDLED_PLUGIN_LIVE_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.live.test.ts";

std::string bundledPluginRoot(const std::string& pluginId) {
    return BUNDLED_PLUGIN_PATH_PREFIX + pluginId;
}

std::string bundledPluginFile(const std::string& pluginId, const std::string& relativePath) {
    return bundledPluginRoot(pluginId) + "/" + relativePath;
}

std::string bundledDistPluginRoot(const std::string& pluginId) {
    return "dist/" + bundledPluginRoot(pluginId);
}

std::string bundledDistPluginFile(const std::string& pluginId, const std::string& relativePath) {
    return bundledDistPluginRoot(pluginId) + "/" + relativePath;
}

std::string bundledPluginCallsite(const std::string& pluginId, const std::string& relativePath, const std::string& line) {
    return bundledPluginFile(pluginId, relativePath) + ":" + line;
}

#endif // BUNDLED_PLUGIN_PATHS_H
