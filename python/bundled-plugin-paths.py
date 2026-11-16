#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "3af928ff960c353ad5630f2cb6fb3696c954d61ab874217ab40cd00928600133", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "python"}
# bundled-plugin-paths.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

BUNDLED_PLUGIN_ROOT_DIR = "extensions"
BUNDLED_PLUGIN_PATH_PREFIX = f"{BUNDLED_PLUGIN_ROOT_DIR}/"
BUNDLED_PLUGIN_TEST_GLOB = f"{BUNDLED_PLUGIN_ROOT_DIR}/**/*.test.ts"
BUNDLED_PLUGIN_E2E_TEST_GLOB = f"{BUNDLED_PLUGIN_ROOT_DIR}/**/*.e2e.test.ts"
BUNDLED_PLUGIN_LIVE_TEST_GLOB = f"{BUNDLED_PLUGIN_ROOT_DIR}/**/*.live.test.ts"

def bundled_plugin_root(plugin_id):
    return f"{BUNDLED_PLUGIN_PATH_PREFIX}{plugin_id}"

def bundled_plugin_file(plugin_id, relative_path):
    return f"{bundled_plugin_root(plugin_id)}/{relative_path}"

def bundled_dist_plugin_root(plugin_id):
    return f"dist/{bundled_plugin_root(plugin_id)}"

def bundled_dist_plugin_file(plugin_id, relative_path):
    return f"{bundled_dist_plugin_root(plugin_id)}/{relative_path}"

def bundled_plugin_callsite(plugin_id, relative_path, line):
    return f"{bundled_plugin_file(plugin_id, relative_path)}:{line}"
