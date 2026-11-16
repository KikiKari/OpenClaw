#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "092677eea0ce0e2bd9fcb7a4887b458051edade26e222ab6b6509e78eda4c24f", "source_sha256": "c621fd196534668fd5c4de67b6a62dc07e1ffe3cdab77931626c91c04d7d16de", "target_language": "ruby"}
# bundled-plugin-paths.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-paths.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

module BundledPluginPaths
  BUNDLED_PLUGIN_ROOT_DIR = 'extensions'
  BUNDLED_PLUGIN_PATH_PREFIX = "#{BUNDLED_PLUGIN_ROOT_DIR}/"
  BUNDLED_PLUGIN_TEST_GLOB = "#{BUNDLED_PLUGIN_ROOT_DIR}/**/*.test.ts"
  BUNDLED_PLUGIN_E2E_TEST_GLOB = "#{BUNDLED_PLUGIN_ROOT_DIR}/**/*.e2e.test.ts"
  BUNDLED_PLUGIN_LIVE_TEST_GLOB = "#{BUNDLED_PLUGIN_ROOT_DIR}/**/*.live.test.ts"

  def self.bundled_plugin_root(plugin_id)
    "#{BUNDLED_PLUGIN_PATH_PREFIX}#{plugin_id}"
  end

  def self.bundled_plugin_file(plugin_id, relative_path)
    "#{bundled_plugin_root(plugin_id)}/#{relative_path}"
  end

  def self.bundled_dist_plugin_root(plugin_id)
    "dist/#{bundled_plugin_root(plugin_id)}"
  end

  def self.bundled_dist_plugin_file(plugin_id, relative_path)
    "#{bundled_dist_plugin_root(plugin_id)}/#{relative_path}"
  end

  def self.bundled_plugin_callsite(plugin_id, relative_path, line)
    "#{bundled_plugin_file(plugin_id, relative_path)}:#{line}"
  end
end
