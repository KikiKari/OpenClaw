// abstraction-provenance: {"artifact_sha256": "f32b5785e5b21b62f693b5793b3f3062a716c19719f24465bb922f5ffb301cb3", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "java"}
// bundled-plugin-paths.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

public class BundledPluginPaths {
    public static final String BUNDLED_PLUGIN_ROOT_DIR = "extensions";
    public static final String BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_ROOT_DIR + "/";
    public static final String BUNDLED_PLUGIN_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.test.ts";
    public static final String BUNDLED_PLUGIN_E2E_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.e2e.test.ts";
    public static final String BUNDLED_PLUGIN_LIVE_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR + "/**/*.live.test.ts";

    public static String bundledPluginRoot(String pluginId) {
        return BUNDLED_PLUGIN_PATH_PREFIX + pluginId;
    }

    public static String bundledPluginFile(String pluginId, String relativePath) {
        return bundledPluginRoot(pluginId) + "/" + relativePath;
    }

    public static String bundledDistPluginRoot(String pluginId) {
        return "dist/" + bundledPluginRoot(pluginId);
    }

    public static String bundledDistPluginFile(String pluginId, String relativePath) {
        return bundledDistPluginRoot(pluginId) + "/" + relativePath;
    }

    public static String bundledPluginCallsite(String pluginId, String relativePath, int line) {
        return bundledPluginFile(pluginId, relativePath) + ":" + line;
    }
}
