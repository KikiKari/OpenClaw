#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "607b8ff40f4c52bfc939b3ba4f5f3f1618b428b8d6a7b8ba2546ed5228273d0f", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "ruby"}
# bundled-plugin-source-utils.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require "json"
require "fileutils"

def read_if_exists(file_path)
  File.read(file_path)
rescue Errno::ENOENT
  nil
end

def collect_bundled_plugin_sources(params = {})
  repo_root = params[:repo_root] || Dir.pwd
  extensions_root = File.join(repo_root, "extensions")
  return [] unless Dir.exist?(extensions_root)

  require_package_json = params[:require_package_json] == true
  entries = []

  Dir.foreach(extensions_root) do |entry|
    next if entry == "." || entry == ".."

    plugin_dir = File.join(extensions_root, entry)
    next unless Dir.exist?(plugin_dir)

    manifest_path = File.join(plugin_dir, "openclaw.plugin.json")
    package_json_path = File.join(plugin_dir, "package.json")

    next unless File.exist?(manifest_path)
    next if require_package_json && !File.exist?(package_json_path)

    entry_data = {
      dir_name: entry,
      plugin_dir: plugin_dir,
      manifest_path: manifest_path,
      manifest: JSON.parse(File.read(manifest_path))
    }

    if File.exist?(package_json_path)
      entry_data[:package_json_path] = package_json_path
      entry_data[:package_json] = JSON.parse(File.read(package_json_path))
    end

    entries << entry_data
  end

  entries.sort_by { |entry| entry[:dir_name] }
end
