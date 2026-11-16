#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8360ab0ca5376132ed8b956039c7c0dc31573fc4157a356321eb5f600850ca0c", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "lua"}
-- bundled-plugin-paths.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local BUNDLED_PLUGIN_ROOT_DIR = "extensions"
local BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_ROOT_DIR .. "/"
local BUNDLED_PLUGIN_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR .. "/**/*.test.ts"
local BUNDLED_PLUGIN_E2E_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR .. "/**/*.e2e.test.ts"
local BUNDLED_PLUGIN_LIVE_TEST_GLOB = BUNDLED_PLUGIN_ROOT_DIR .. "/**/*.live.test.ts"

local function bundledPluginRoot(pluginId)
  return BUNDLED_PLUGIN_PATH_PREFIX .. pluginId
end

local function bundledPluginFile(pluginId, relativePath)
  return bundledPluginRoot(pluginId) .. "/" .. relativePath
end

local function bundledDistPluginRoot(pluginId)
  return "dist/" .. bundledPluginRoot(pluginId)
end

local function bundledDistPluginFile(pluginId, relativePath)
  return bundledDistPluginRoot(pluginId) .. "/" .. relativePath
end

local function bundledPluginCallsite(pluginId, relativePath, line)
  return bundledPluginFile(pluginId, relativePath) .. ":" .. line
end

return {
  BUNDLED_PLUGIN_ROOT_DIR = BUNDLED_PLUGIN_ROOT_DIR,
  BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_PATH_PREFIX,
  BUNDLED_PLUGIN_TEST_GLOB = BUNDLED_PLUGIN_TEST_GLOB,
  BUNDLED_PLUGIN_E2E_TEST_GLOB = BUNDLED_PLUGIN_E2E_TEST_GLOB,
  BUNDLED_PLUGIN_LIVE_TEST_GLOB = BUNDLED_PLUGIN_LIVE_TEST_GLOB,
  bundledPluginRoot = bundledPluginRoot,
  bundledPluginFile = bundledPluginFile,
  bundledDistPluginRoot = bundledDistPluginRoot,
  bundledDistPluginFile = bundledDistPluginFile,
  bundledPluginCallsite = bundledPluginCallsite
}
