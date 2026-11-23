#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "32fa666c544a22185a67b8d486138b99da9ccbfa3c0236d3a5cefd2f1601c095", "source_sha256": "481f90055fd746cf4af45da5765d09d2a9289bac2b7aa0b2fecc8558803339d5", "target_language": "ruby"}
# stage-bundled-plugin-runtime-deps.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime-deps.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require 'tmpdir'
require 'securerandom'
require 'digest'
require 'pathname'

# Simulate semver satisfies functionality
def semver_satisfies(version, spec)
  # This is a simplified check - in production you might want a proper semver library
  spec_parts = spec.split(/[<>=~^]/)
  return true if spec_parts.empty?
  
  spec_version = spec_parts.first.strip
  return version == spec_version if spec.include?('=')
  return true # Simplified - real implementation would parse operators properly
end

STAGED_RUNTIME_DEP_PRUNE_RULES = {
  '@larksuiteoapi/node-sdk' => ['types']
}.freeze

RUNTIME_DEPS_STAGING_VERSION = 2

def read_json(file_path)
  JSON.parse(File.read(file_path))
end

def write_json(file_path, value)
  File.write(file_path, "#{JSON.pretty_generate(value)}\n")
end

def remove_path_if_exists(target_path)
  FileUtils.rm_rf(target_path)
rescue
  # Ignore errors
end

def make_temp_dir(parent_dir, prefix)
  Dir.mktmpdir(prefix, parent_dir)
end

def sanitize_temp_prefix_segment(value)
  normalized = value.gsub(/[^A-Za-z0-9._-]+/, '-').gsub(/-+/, '-')
  normalized.length > 0 ? normalized : 'plugin'
end

def replace_dir(target_path, source_path)
  remove_path_if_exists(target_path)
  begin
    FileUtils.mv(source_path, target_path)
    return
  rescue => error
    raise error unless error.message.include?('cross-device')
  end
  FileUtils.cp_r(source_path, target_path, remove_destination: true)
  remove_path_if_exists(source_path)
end

def dependency_node_modules_path(node_modules_dir, dep_name)
  File.join(node_modules_dir, *dep_name.split('/'))
end

def read_installed_dependency_version(node_modules_dir, dep_name)
  package_json_path = File.join(dependency_node_modules_path(node_modules_dir, dep_name), 'package.json')
  return nil unless File.exist?(package_json_path)
  
  version = read_json(package_json_path)['version']
  version.is_a?(String) ? version : nil
rescue
  nil
end

def dependency_version_satisfied(spec, installed_version)
  semver_satisfies(installed_version, spec)
end

def collect_installed_runtime_closure(root_node_modules_dir, dependency_specs)
  package_cache = {}
  closure = Set.new
  queue = dependency_specs.to_a

  while queue.any?
    dep_name, spec = queue.shift
    installed_version = read_installed_dependency_version(root_node_modules_dir, dep_name)
    return nil if installed_version.nil? || !dependency_version_satisfied(spec, installed_version)
    next if closure.include?(dep_name)

    package_json_path = File.join(dependency_node_modules_path(root_node_modules_dir, dep_name), 'package.json')
    package_json = package_cache[dep_name] || read_json(package_json_path)
    package_cache[dep_name] = package_json
    closure.add(dep_name)

    (package_json['dependencies'] || {}).each do |child_name, child_spec|
      queue.push([child_name, child_spec])
    end
    
    (package_json['optionalDependencies'] || {}).each do |child_name, child_spec|
      queue.push([child_name, child_spec])
    end
  end

  closure.to_a
end

def prune_staged_installed_dependency_cargo(node_modules_dir, dep_name)
  prune_paths = STAGED_RUNTIME_DEP_PRUNE_RULES[dep_name]
  return unless prune_paths

  dep_root = dependency_node_modules_path(node_modules_dir, dep_name)
  prune_paths.each do |relative_path|
    remove_path_if_exists(File.join(dep_root, relative_path))
  end
end

def prune_staged_runtime_dependency_cargo(node_modules_dir)
  STAGED_RUNTIME_DEP_PRUNE_RULES.keys.each do |dep_name|
    prune_staged_installed_dependency_cargo(node_modules_dir, dep_name)
  end
end

def list_bundled_plugin_runtime_dirs(repo_root)
  extensions_root = File.join(repo_root, 'dist', 'extensions')
  return [] unless Dir.exist?(extensions_root)

  Dir.children(extensions_root)
    .select { |name| Dir.exist?(File.join(extensions_root, name)) }
    .map { |name| File.join(extensions_root, name) }
    .select { |plugin_dir| File.exist?(File.join(plugin_dir, 'package.json')) }
end

def has_runtime_deps(package_json)
  ((package_json['dependencies'] || {}).length > 0) ||
  ((package_json['optionalDependencies'] || {}).length > 0)
end

def should_stage_runtime_deps(package_json)
  package_json.dig('openclaw', 'bundle', 'stageRuntimeDependencies') == true
end

def sanitize_bundled_manifest_for_runtime_install(plugin_dir)
  manifest_path = File.join(plugin_dir, 'package.json')
  package_json = read_json(manifest_path)
  changed = false

  if package_json.key?('peerDependencies')
    package_json.delete('peerDependencies')
    changed = true
  end

  if package_json.key?('peerDependenciesMeta')
    package_json.delete('peerDependenciesMeta')
    changed = true
  end

  if package_json.key?('devDependencies')
    package_json.delete('devDependencies')
    changed = true
  end

  write_json(manifest_path, package_json) if changed
  package_json
end

def resolve_runtime_deps_stamp_path(plugin_dir)
  File.join(plugin_dir, '.openclaw-runtime-deps-stamp.json')
end

def create_runtime_deps_fingerprint(package_json)
  data = {
    packageJson: package_json,
    pruneRules: STAGED_RUNTIME_DEP_PRUNE_RULES.to_a,
    version: RUNTIME_DEPS_STAGING_VERSION
  }
  Digest::SHA256.hexdigest(JSON.generate(data))
end

def read_runtime_deps_stamp(stamp_path)
  return nil unless File.exist?(stamp_path)
  read_json(stamp_path)
rescue
  nil
end

def stage_installed_root_runtime_deps(params)
  fingerprint = params[:fingerprint]
  package_json = params[:package_json]
  plugin_dir = params[:plugin_dir]
  repo_root = params[:repo_root]

  dependency_specs = {}
  dependency_specs.merge!(package_json['dependencies'] || {})
  dependency_specs.merge!(package_json['optionalDependencies'] || {})

  root_node_modules_dir = File.join(repo_root, 'node_modules')
  return false if dependency_specs.empty? || !Dir.exist?(root_node_modules_dir)

  dependency_names = collect_installed_runtime_closure(root_node_modules_dir, dependency_specs)
  return false if dependency_names.nil?

  node_modules_dir = File.join(plugin_dir, 'node_modules')
  stamp_path = resolve_runtime_deps_stamp_path(plugin_dir)
  
  temp_dir = make_temp_dir(Dir.tmpdir, "openclaw-runtime-deps-#{sanitize_temp_prefix_segment(File.basename(plugin_dir))}-")
  staged_node_modules_dir = File.join(temp_dir, 'node_modules')

  begin
    dependency_names.each do |dep_name|
      source_path = dependency_node_modules_path(root_node_modules_dir, dep_name)
      target_path = dependency_node_modules_path(staged_node_modules_dir, dep_name)
      FileUtils.mkdir_p(File.dirname(target_path))
      FileUtils.cp_r(source_path, target_path, remove_destination: true)
    end
    
    prune_staged_runtime_dependency_cargo(staged_node_modules_dir)
    
    replace_dir(node_modules_dir, staged_node_modules_dir)
    write_json(stamp_path, {
      fingerprint: fingerprint,
      generatedAt: Time.now.utc.iso8601
    })
    true
  ensure
    remove_path_if_exists(temp_dir)
  end
end

def install_plugin_runtime_deps(params)
  fingerprint = params[:fingerprint]
  package_json = params[:package_json]
  plugin_dir = params[:plugin_dir]
  plugin_id = params[:plugin_id]
  repo_root = params[:repo_root]

  if repo_root && stage_installed_root_runtime_deps(
    fingerprint: fingerprint,
    package_json: package_json,
    plugin_dir: plugin_dir,
    repo_root: repo_root
  )
    return
  end

  node_modules_dir = File.join(plugin_dir, 'node_modules')
  stamp_path = resolve_runtime_deps_stamp_path(plugin_dir)
  
  temp_install_dir = make_temp_dir(
    Dir.tmpdir,
    "openclaw-runtime-deps-#{sanitize_temp_prefix_segment(plugin_id)}-"
  )

  begin
    write_json(File.join(temp_install_dir, 'package.json'), package_json)
    
    result = system('npm', 'install', '--omit=dev', '--silent', '--ignore-scripts', '--legacy-peer-deps', '--package-lock=false', 
                     chdir: temp_install_dir, out: '/dev/null', err: '/dev/null')
    
    unless result
      raise "failed to stage bundled runtime deps for #{plugin_id}: npm install failed"
    end

    staged_node_modules_dir = File.join(temp_install_dir, 'node_modules')
    unless Dir.exist?(staged_node_modules_dir)
      raise "failed to stage bundled runtime deps for #{plugin_id}: npm install produced no node_modules directory"
    end

    prune_staged_runtime_dependency_cargo(staged_node_modules_dir)
    
    replace_dir(node_modules_dir, staged_node_modules_dir)
    write_json(stamp_path, {
      fingerprint: fingerprint,
      generatedAt: Time.now.utc.iso8601
    })
  ensure
    remove_path_if_exists(temp_install_dir)
  end
end

def install_plugin_runtime_deps_with_retries(params)
  attempts = params[:attempts] || 3
  last_error = nil
  
  (1..attempts).each do |attempt|
    begin
      params[:install].call(params[:install_params].merge(attempt: attempt))
      return
    rescue => error
      last_error = error
      raise error if attempt == attempts
    end
  end
  
  raise last_error
end

def stage_bundled_plugin_runtime_deps(params = {})
  repo_root = params[:cwd] || params[:repo_root] || Dir.pwd
  install_plugin_runtime_deps_impl = params[:install_plugin_runtime_deps_impl] || method(:install_plugin_runtime_deps)
  install_attempts = params[:install_attempts] || 3

  list_bundled_plugin_runtime_dirs(repo_root).each do |plugin_dir|
    plugin_id = File.basename(plugin_dir)
    package_json = sanitize_bundled_manifest_for_runtime_install(plugin_dir)
    node_modules_dir = File.join(plugin_dir, 'node_modules')
    stamp_path = resolve_runtime_deps_stamp_path(plugin_dir)

    unless has_runtime_deps(package_json) && should_stage_runtime_deps(package_json)
      remove_path_if_exists(node_modules_dir)
      remove_path_if_exists(stamp_path)
      next
    end

    fingerprint = create_runtime_deps_fingerprint(package_json)
    stamp = read_runtime_deps_stamp(stamp_path)

    if Dir.exist?(node_modules_dir) && stamp&.dig('fingerprint') == fingerprint
      next
    end

    install_plugin_runtime_deps_with_retries(
      attempts: install_attempts,
      install: install_plugin_runtime_deps_impl,
      install_params: {
        fingerprint: fingerprint,
        package_json: package_json,
        plugin_dir: plugin_dir,
        plugin_id: plugin_id,
        repo_root: repo_root
      }
    )
  end
end

if __FILE__ == $0
  stage_bundled_plugin_runtime_deps
end
