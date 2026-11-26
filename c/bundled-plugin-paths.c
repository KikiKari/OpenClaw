// abstraction-provenance: {"artifact_sha256": "5257e7ce33b02eca327e55bf2443f7b5a2cda169cb7d192154a46423f85eb9a9", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "c"}
// bundled-plugin-paths.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>

const char* BUNDLED_PLUGIN_ROOT_DIR = "extensions";
const char* BUNDLED_PLUGIN_PATH_PREFIX = "extensions/";
const char* BUNDLED_PLUGIN_TEST_GLOB = "extensions/**/*.test.ts";
const char* BUNDLED_PLUGIN_E2E_TEST_GLOB = "extensions/**/*.e2e.test.ts";
const char* BUNDLED_PLUGIN_LIVE_TEST_GLOB = "extensions/**/*.live.test.ts";

char* bundledPluginRoot(const char* pluginId) {
    int len = snprintf(NULL, 0, "%s%s", BUNDLED_PLUGIN_PATH_PREFIX, pluginId);
    char* result = (char*)malloc(len + 1);
    sprintf(result, "%s%s", BUNDLED_PLUGIN_PATH_PREFIX, pluginId);
    return result;
}

char* bundledPluginFile(const char* pluginId, const char* relativePath) {
    char* root = bundledPluginRoot(pluginId);
    int len = snprintf(NULL, 0, "%s/%s", root, relativePath);
    char* result = (char*)malloc(len + 1);
    sprintf(result, "%s/%s", root, relativePath);
    free(root);
    return result;
}

char* bundledDistPluginRoot(const char* pluginId) {
    char* root = bundledPluginRoot(pluginId);
    int len = snprintf(NULL, 0, "dist/%s", root);
    char* result = (char*)malloc(len + 1);
    sprintf(result, "dist/%s", root);
    free(root);
    return result;
}

char* bundledDistPluginFile(const char* pluginId, const char* relativePath) {
    char* distRoot = bundledDistPluginRoot(pluginId);
    int len = snprintf(NULL, 0, "%s/%s", distRoot, relativePath);
    char* result = (char*)malloc(len + 1);
    sprintf(result, "%s/%s", distRoot, relativePath);
    free(distRoot);
    return result;
}

char* bundledPluginCallsite(const char* pluginId, const char* relativePath, int line) {
    char* file = bundledPluginFile(pluginId, relativePath);
    int len = snprintf(NULL, 0, "%s:%d", file, line);
    char* result = (char*)malloc(len + 1);
    sprintf(result, "%s:%d", file, line);
    free(file);
    return result;
}
