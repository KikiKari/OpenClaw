#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "4cce5ff30612ecb9b8ad748c0187bc13f77028580cace86b7d89c48d1f70e16e", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "ruby"}
# bundled-plugin-build-entries.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'

# Assuming these constants are defined elsewhere or will be passed as parameters
# For now, we'll define them here as they're not provided in the original code
BUNDLED_PLUGIN_ROOT_DIR = 'extensions' unless defined?(BUNDLED_PLUGIN_ROOT_DIR)

def bundled_dist_plugin_file(id, filename)
  "#{id}/#{filename}"
end

def bundled_plugin_file(id, filename)
  "#{id}/#{filename}"
end

def should_build_bundled_cluster(dir_name, env, package_json: nil)
  # Placeholder implementation - replace with actual logic
  true
end

TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS = Set.new(['.ts', '.js', '.mts', '.cts', '.mjs', '.cjs'])
NON_PACKAGED_BUNDLED_PLUGIN_DIRS = Set.new(['qa-channel', 'qa-lab'])

def to_posix_path(value)
  value.gsub('\\', '/')
end

def read_bundled_plugin_package_json(package_json_path)
  return nil unless File.exist?(package_json_path)
  
  begin
    JSON.parse(File.read(package_json_path))
  rescue
    nil
  end
end

def is_manifestless_bundled_runtime_support_package(params)
  package_name = params[:package_json]&.[]('name').is_a?(String) ? params[:package_json]['name'] : ''
  return false if package_name != "@openclaw/#{params[:dir_name]}"
  
  params[:top_level_public_surface_entries].length > 0
end

def collect_plugin_source_entries(package_json)
  package_entries = package_json&.[]('openclaw')&.[]('extensions').is_a?(Array) ? 
    package_json['openclaw']['extensions'].select { |entry| entry.is_a?(String) && entry.strip.length > 0 } : []
  
  setup_entry = package_json&.[]('openclaw')&.[]('setupEntry').is_a?(String) && 
                package_json['openclaw']['setupEntry'].strip.length > 0 ? 
                package_json['openclaw']['setupEntry'] : nil
  
  if setup_entry
    package_entries = (package_entries + [setup_entry]).uniq
  end
  
  package_entries.length > 0 ? package_entries : ['./index.ts']
end

def should_stage_bundled_plugin_runtime_dependencies(package_json)
  package_json&.[]('openclaw')&.[]('bundle')&.[]('stageRuntimeDependencies') == true
end

def collect_top_level_public_surface_entries(plugin_dir)
  return [] unless Dir.exist?(plugin_dir)
  
  Dir.children(plugin_dir).flat_map do |filename|
    filepath = File.join(plugin_dir, filename)
    next [] unless File.file?(filepath)
    
    ext = File.extname(filename)
    next [] unless TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS.include?(ext)
    
    normalized_name = filename.downcase
    next [] if normalized_name.end_with?('.d.ts') || 
               /^config-api\.(?:[cm]?[jt]s)$/ =~ normalized_name ||
               normalized_name.include?('.test.') ||
               normalized_name.include?('.spec.') ||
               normalized_name.include?('.fixture.') ||
               normalized_name.include?('.snap')
    
    ["./#{filename}"]
  end.sort
end

def collect_bundled_plugin_build_entries(params = {})
  cwd = params[:cwd] || Dir.pwd
  env = params[:env] || ENV
  extensions_root = File.join(cwd, BUNDLED_PLUGIN_ROOT_DIR)
  entries = []
  
  return entries unless Dir.exist?(extensions_root)
  
  Dir.children(extensions_root).each do |dirname|
    dirpath = File.join(extensions_root, dirname)
    next unless Dir.exist?(dirpath)
    
    plugin_dir = dirpath
    manifest_path = File.join(plugin_dir, 'openclaw.plugin.json')
    has_manifest = File.exist?(manifest_path)
    package_json_path = File.join(plugin_dir, 'package.json')
    package_json = read_bundled_plugin_package_json(package_json_path)
    top_level_public_surface_entries = collect_top_level_public_surface_entries(plugin_dir)
    
    unless has_manifest || is_manifestless_bundled_runtime_support_package({
        dir_name: dirname,
        package_json: package_json,
        top_level_public_surface_entries: top_level_public_surface_entries
      })
      next
    end
    
    unless should_build_bundled_cluster(dirname, env, package_json: package_json)
      next
    end
    
    entries.push({
      id: dirname,
      has_manifest: has_manifest,
      has_package_json: package_json != nil,
      package_json: package_json,
      source_entries: (has_manifest ? collect_plugin_source_entries(package_json) : [] + 
                       top_level_public_surface_entries).uniq
    })
  end
  
  entries
end

def list_bundled_plugin_build_entries(params = {})
  result = {}
  
  collect_bundled_plugin_build_entries(params).each do |entry|
    entry[:source_entries].each do |source_entry|
      normalized_entry = source_entry.sub(%r{^\./}, '')
      entry_key = bundled_plugin_file(entry[:id], normalized_entry.sub(/\.[^.]+\z/, ''))
      result[entry_key] = to_posix_path(File.join(BUNDLED_PLUGIN_ROOT_DIR, entry[:id], normalized_entry))
    end
  end
  
  result
end

def list_bundled_plugin_pack_artifacts(params = {})
  entries = collect_bundled_plugin_build_entries(params).select do |entry|
    !NON_PACKAGED_BUNDLED_PLUGIN_DIRS.include?(entry[:id])
  end
  
  artifacts = Set.new
  
  entries.each do |entry|
    if entry[:has_manifest]
      artifacts.add(bundled_dist_plugin_file(entry[:id], 'openclaw.plugin.json'))
    end
    
    if entry[:has_package_json]
      artifacts.add(bundled_dist_plugin_file(entry[:id], 'package.json'))
    end
    
    entry[:source_entries].each do |source_entry|
      normalized_entry = source_entry.sub(%r{^\./}, '').sub(/\.[^.]+\z/, '')
      artifacts.add(bundled_dist_plugin_file(entry[:id], "#{normalized_entry}.js"))
    end
  end
  
  artifacts.to_a.sort
end

def list_bundled_plugin_runtime_dependencies(params = {})
  runtime_dependencies = Set.new
  
  collect_bundled_plugin_build_entries(params).each do |entry|
    package_json = entry[:package_json]
    next unless should_stage_bundled_plugin_runtime_dependencies(package_json)
    
    (package_json&.[]('dependencies')&.keys || []).each do |dependency_name|
      runtime_dependencies.add(dependency_name)
    end
    
    (package_json&.[]('optionalDependencies')&.keys || []).each do |dependency_name|
      runtime_dependencies.add(dependency_name)
    end
  end
  
  runtime_dependencies.to_a.sort
end
