#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "e3d3ca065f1e0b83322156a874cd434713280a463b4b8e859755d14a1a59a7bd", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "ruby"}
# bundled-plugin-root-runtime-mirrors.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'

JS_EXTENSIONS = %w[.cjs .js .mjs].freeze

def collect_runtime_dependency_specs(package_json = {})
  deps = package_json['dependencies'] || {}
  optional_deps = package_json['optionalDependencies'] || {}
  
  (deps.to_a + optional_deps.to_a)
    .select { |_, spec| spec.is_a?(String) && !spec.empty? }
    .to_h
end

def package_name_from_specifier(specifier)
  return nil unless specifier.is_a?(String)
  return nil if specifier.start_with?('.', '/', 'node:', '#')

  parts = specifier.split('/')
  return nil if parts.empty?

  parts.first.start_with?('@') && parts.size > 1 ? "#{parts[0]}/#{parts[1]}" : parts[0]
end

def read_json(file_path)
  JSON.parse(File.read(file_path))
end

def collect_package_json_paths(root_dir)
  return [] unless Dir.exist?(root_dir)

  Dir.children(root_dir)
    .select { |entry| File.directory?(File.join(root_dir, entry)) }
    .map { |entry| File.join(root_dir, entry, 'package.json') }
    .select { |path| File.exist?(path) }
    .sort
end

def collect_bundled_plugin_runtime_dependency_specs(bundled_plugins_dir)
  specs = {}

  collect_package_json_paths(bundled_plugins_dir).each do |package_json_path|
    package_json = read_json(package_json_path)
    plugin_id = File.basename(File.dirname(package_json_path))
    
    collect_runtime_dependency_specs(package_json).each do |name, spec|
      existing = specs[name]
      if existing
        if existing[:spec] != spec
          existing[:conflicts] << { plugin_id: plugin_id, spec: spec }
        elsif !existing[:plugin_ids].include?(plugin_id)
          existing[:plugin_ids] << plugin_id
        end
        next
      end
      
      specs[name] = { conflicts: [], plugin_ids: [plugin_id], spec: spec }
    end
  end

  specs
end

def walk_javascript_files(root_dir)
  files = []
  return files unless Dir.exist?(root_dir)

  queue = [root_dir]
  until queue.empty?
    current = queue.shift
    Dir.children(current).each do |entry_name|
      full_path = File.join(current, entry_name)
      if File.directory?(full_path)
        next if full_path.split(File::SEPARATOR).include?('extensions')
        
        queue << full_path
        next
      end
      
      if File.file?(full_path) && JS_EXTENSIONS.include?(File.extname(entry_name))
        files << full_path
      end
    end
  end
  
  files.sort
end

def extract_module_specifiers(source)
  specifiers = Set.new
  patterns = [
    /\bfrom\s*["']([^"']+)["']/,
    /\bimport\s*["']([^"']+)["']/,
    /\bimport\s*\(\s*["']([^"']+)["']\s*\)/,
    /\brequire\s*\(\s*["']([^"']+)["']\s*\)/
  ]
  
  patterns.each do |pattern|
    source.scan(pattern) do |match|
      specifiers.add(match[0]) if match[0]
    end
  end
  
  specifiers
end

def collect_root_dist_bundled_runtime_mirrors(params)
  dist_dir = params[:dist_dir]
  bundled_specs = params[:bundled_runtime_dependency_specs]
  mirrors = {}

  walk_javascript_files(dist_dir).each do |file_path|
    source = File.read(file_path)
    relative_path = file_path.sub("#{dist_dir}/", '').gsub(File::SEPARATOR, '/')
    
    extract_module_specifiers(source).each do |specifier|
      dependency_name = package_name_from_specifier(specifier)
      next unless dependency_name && bundled_specs.key?(dependency_name)
      
      bundled_spec = bundled_specs[dependency_name]
      existing = mirrors[dependency_name]
      
      if existing
        existing[:importers].add(relative_path)
        next
      end
      
      mirrors[dependency_name] = {
        importers: Set.new([relative_path]),
        plugin_ids: bundled_spec[:plugin_ids],
        spec: bundled_spec[:spec]
      }
    end
  end

  mirrors
end

def collect_bundled_plugin_root_runtime_mirror_errors(params)
  root_runtime_deps = collect_runtime_dependency_specs(params[:root_package_json])
  errors = []

  params[:bundled_runtime_dependency_specs].each do |dependency_name, record|
    record[:conflicts].each do |conflict|
      errors << "bundled runtime dependency '#{dependency_name}' has conflicting plugin specs: #{record[:plugin_ids].join(', ')} use '#{record[:spec]}', #{conflict[:plugin_id]} uses '#{conflict[:spec]}'."
    end
  end

  params[:required_root_mirrors].each do |dependency_name, mirror|
    root_spec = root_runtime_deps[dependency_name]
    importers = mirror[:importers].to_a.sort
    importer_label = importers.join(', ')
    plugin_label = mirror[:plugin_ids].sort.join(', ')
    
    if !root_spec.is_a?(String) || root_spec.empty?
      errors << "root dist imports bundled plugin runtime dependency '#{dependency_name}' from #{importer_label}; mirror '#{dependency_name}: #{mirror[:spec]}' in root package.json (declared by #{plugin_label})."
      next
    end
    
    if root_spec != mirror[:spec]
      errors << "root dist imports bundled plugin runtime dependency '#{dependency_name}' from #{importer_label}; root package.json has '#{root_spec}' but plugin manifest declares '#{mirror[:spec]}' (#{plugin_label})."
    end
  end

  errors
end
