#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "75acf7794e057918476892ee26abba1d4e730605f124d68b9e821df19622cf08", "source_sha256": "fd0e09df4d2dcc4aafd9784f264f0b9e5a046c02335886978c614026a9f3648c", "target_language": "ruby"}
# runtime-postbuild.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/runtime-postbuild.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require "fileutils"
require "pathname"
require_relative "copy_bundled_plugin_metadata"
require_relative "copy_plugin_sdk_root_alias"
require_relative "runtime_postbuild_shared"
require_relative "stage_bundled_plugin_runtime_deps"
require_relative "stage_bundled_plugin_runtime"
require_relative "write_official_channel_catalog"

ROOT = Pathname.new(__FILE__).dirname.parent.to_s.freeze
ROOT_RUNTIME_ALIAS_PATTERN = /^(?<base>.+\.(?:runtime|contract))-[A-Za-z0-9_-]+\.js$/i.freeze

# Copy static (non-transpiled) runtime assets that are referenced by their
# source-relative path inside bundled extension code.
#
# Each entry: { src: repo-root-relative source, dest: dist-relative dest }
STATIC_EXTENSION_ASSETS = [
  # acpx MCP proxy — co-deployed alongside the acpx index bundle so that
  # `path.resolve(dirname(import.meta.url), "mcp-proxy.mjs")` resolves correctly
  # at runtime from the built ACPX extension directory.
  {
    src: "extensions/acpx/src/runtime-internals/mcp-proxy.mjs",
    dest: "dist/extensions/acpx/mcp-proxy.mjs",
  },
  # diffs viewer runtime bundle — co-deployed inside the plugin package so the
  # built bundle can resolve `./assets/viewer-runtime.js` from dist.
  {
    src: "extensions/diffs/assets/viewer-runtime.js",
    dest: "dist/extensions/diffs/assets/viewer-runtime.js",
  },
].freeze

def list_static_extension_asset_outputs(params = {})
  assets = params[:assets] || STATIC_EXTENSION_ASSETS
  assets.map { |asset| asset[:dest].gsub("\\", "/") }.sort
end

def copy_static_extension_assets(params = {})
  root_dir = params[:root_dir] || ROOT
  assets = params[:assets] || STATIC_EXTENSION_ASSETS
  fs_impl = params[:fs] || FileUtils
  warn_proc = params[:warn] || method(:warn)

  assets.each do |asset|
    src_path = File.join(root_dir, asset[:src])
    dest_path = File.join(root_dir, asset[:dest])

    if File.exist?(src_path)
      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.cp(src_path, dest_path)
    else
      warn_proc.call("[runtime-postbuild] static asset not found, skipping: #{asset[:src]}")
    end
  end
end

def write_stable_root_runtime_aliases(params = {})
  root_dir = params[:root_dir] || ROOT
  dist_dir = File.join(root_dir, "dist")
  fs_impl = params[:fs] || Dir

  entries = []
  begin
    entries = Dir.children(dist_dir).select { |entry| File.file?(File.join(dist_dir, entry)) }
  rescue StandardError
    return
  end

  entries.each do |entry_name|
    match = entry_name.match(ROOT_RUNTIME_ALIAS_PATTERN)
    next unless match && match[:base]

    alias_path = File.join(dist_dir, "#{match[:base]}.js")
    write_text_file_if_changed(alias_path, "export * from \"./#{entry_name}\";\n")
  end
end

def run_runtime_post_build(params = {})
  copy_plugin_sdk_root_alias(params)
  copy_bundled_plugin_metadata(params)
  write_official_channel_catalog(params)
  stage_bundled_plugin_runtime_deps(params)
  stage_bundled_plugin_runtime(params)
  write_stable_root_runtime_aliases(params)
  copy_static_extension_assets(params)
end

if __FILE__ == $PROGRAM_NAME
  run_runtime_post_build
end
