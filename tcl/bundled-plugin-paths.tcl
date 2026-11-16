#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "6f0ecc4b39f6dba0ee984f996bcf1d8d6612d76c0daa3456d5482167c62f690c", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "tcl"}
# bundled-plugin-paths.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Definition der Konstanten
set BUNDLED_PLUGIN_ROOT_DIR "extensions"
set BUNDLED_PLUGIN_PATH_PREFIX "${BUNDLED_PLUGIN_ROOT_DIR}/"
set BUNDLED_PLUGIN_TEST_GLOB "${BUNDLED_PLUGIN_ROOT_DIR}/**/*.test.ts"
set BUNDLED_PLUGIN_E2E_TEST_GLOB "${BUNDLED_PLUGIN_ROOT_DIR}/**/*.e2e.test.ts"
set BUNDLED_PLUGIN_LIVE_TEST_GLOB "${BUNDLED_PLUGIN_ROOT_DIR}/**/*.live.test.ts"

# Funktion: bundledPluginRoot
proc bundledPluginRoot {pluginId} {
    global BUNDLED_PLUGIN_PATH_PREFIX
    return "${BUNDLED_PLUGIN_PATH_PREFIX}${pluginId}"
}

# Funktion: bundledPluginFile
proc bundledPluginFile {pluginId relativePath} {
    set root [bundledPluginRoot $pluginId]
    return "${root}/${relativePath}"
}

# Funktion: bundledDistPluginRoot
proc bundledDistPluginRoot {pluginId} {
    set pluginRoot [bundledPluginRoot $pluginId]
    return "dist/${pluginRoot}"
}

# Funktion: bundledDistPluginFile
proc bundledDistPluginFile {pluginId relativePath} {
    set distRoot [bundledDistPluginRoot $pluginId]
    return "${distRoot}/${relativePath}"
}

# Funktion: bundledPluginCallsite
proc bundledPluginCallsite {pluginId relativePath line} {
    set file [bundledPluginFile $pluginId $relativePath]
    return "${file}:${line}"
}
