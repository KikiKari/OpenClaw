#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "71465c6069f1ce71e60a5d4695b02eaa57922a1f1eade1a0aef33b55065e7210", "source_sha256": "dc65d4759ce1efe8d0c6f037b64d65c1aa1f73b83a3cd928ceebdaf24ed53da6", "target_language": "ruby"}
# stage-bundled-plugin-runtime.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'pathname'

def symlink_type
  Gem.win_platform? ? :junction : :dir
end

def relative_symlink_target(source_path, target_path)
  source_pathname = Pathname.new(source_path)
  target_dir = File.dirname(target_path)
  relative_target = source_pathname.relative_path_from(Pathname.new(target_dir)).to_s
  relative_target.empty? ? '.' : relative_target
rescue
  source_path
end

def should_fallback_to_copy(error)
  Gem.win_platform? && ['EPERM', 'EINVAL', 'UNKNOWN'].include?(error&.message)
end

def copy_path_fallback(source_path, target_path)
  remove_path_if_exists(target_path)
  FileUtils.mkdir_p(File.dirname(target_path))
  
  if File.directory?(source_path)
    FileUtils.cp_r(source_path, target_path, preserve: true)
  else
    FileUtils.cp(source_path, target_path)
  end
end

def remove_path_if_exists(path)
  return unless File.exist?(path) || File.symlink?(path)
  
  if File.directory?(path) && !File.symlink?(path)
    FileUtils.rm_rf(path)
  else
    FileUtils.rm_f(path)
  end
end

def ensure_symlink(target_value, target_path, type = nil, fallback_source_path = nil)
  begin
    FileUtils.ln_s(target_value, target_path, force: true)
    return
  rescue => error
    if fallback_source_path && should_fallback_to_copy(error)
      copy_path_fallback(fallback_source_path, target_path)
      return
    end
    
    raise error unless error.message.include?('EEXIST')
  end
  
  begin
    if File.symlink?(target_path) && File.readlink(target_path) == target_value
      return
    end
  rescue
    # Fall through and recreate the target when inspection fails
  end
  
  remove_path_if_exists(target_path)
  
  begin
    FileUtils.ln_s(target_value, target_path)
  rescue => error
    if fallback_source_path && should_fallback_to_copy(error)
      copy_path_fallback(fallback_source_path, target_path)
      return
    end
    raise error
  end
end

def symlink_path(source_path, target_path, type = nil)
  ensure_symlink(relative_symlink_target(source_path, target_path), target_path, type, source_path)
end

def should_wrap_runtime_js_file(source_path)
  File.extname(source_path) == '.js'
end

def should_copy_runtime_file(source_path)
  relative_path = source_path.gsub('\\', '/')
  %w[
    /package.json
    /openclaw.plugin.json
    /.codex-plugin/plugin.json
    /.claude-plugin/plugin.json
    /.cursor-plugin/plugin.json
    /SKILL.md
  ].any? { |suffix| relative_path.end_with?(suffix) }
end

def write_runtime_module_wrapper(source_path, target_path)
  specifier = relative_symlink_target(source_path, target_path).gsub('\\', '/')
  normalized_specifier = specifier.start_with?('.') ? specifier : "./#{specifier}"
  
  content = [
    "export * from #{normalized_specifier.inspect};",
    "import * as module from #{normalized_specifier.inspect};",
    "export default module.default;",
    ""
  ].join("\n")
  
  File.write(target_path, content, encoding: 'utf-8')
end

def stage_plugin_runtime_overlay(source_dir, target_dir)
  FileUtils.mkdir_p(target_dir)
  
  Dir.foreach(source_dir) do |entry|
    next if entry == '.' || entry == '..'
    next if entry == 'node_modules'
    
    source_path = File.join(source_dir, entry)
    target_path = File.join(target_dir, entry)
    
    if File.directory?(source_path)
      stage_plugin_runtime_overlay(source_path, target_path)
      next
    end
    
    if File.symlink?(source_path)
      ensure_symlink(File.readlink(source_path), target_path, nil, source_path)
      next
    end
    
    next unless File.file?(source_path)
    
    if should_wrap_runtime_js_file(source_path)
      write_runtime_module_wrapper(source_path, target_path)
      next
    end
    
    if should_copy_runtime_file(source_path)
      FileUtils.cp(source_path, target_path)
      next
    end
    
    symlink_path(source_path, target_path)
  end
end

def link_plugin_node_modules(params)
  runtime_node_modules_dir = File.join(params[:runtime_plugin_dir], 'node_modules')
  remove_path_if_exists(runtime_node_modules_dir)
  
  return unless File.exist?(params[:source_plugin_node_modules_dir])
  
  ensure_symlink(
    params[:source_plugin_node_modules_dir],
    runtime_node_modules_dir,
    symlink_type,
    params[:source_plugin_node_modules_dir]
  )
end

def stage_bundled_plugin_runtime(params = {})
  repo_root = params[:cwd] || params[:repo_root] || Dir.pwd
  dist_root = File.join(repo_root, 'dist')
  runtime_root = File.join(repo_root, 'dist-runtime')
  dist_extensions_root = File.join(dist_root, 'extensions')
  runtime_extensions_root = File.join(runtime_root, 'extensions')
  
  unless File.exist?(dist_extensions_root)
    remove_path_if_exists(runtime_root)
    return
  end
  
  remove_path_if_exists(runtime_root)
  FileUtils.mkdir_p(runtime_extensions_root)
  
  Dir.foreach(dist_extensions_root) do |entry|
    next if entry == '.' || entry == '..'
    next unless File.directory?(File.join(dist_extensions_root, entry))
    
    dist_plugin_dir = File.join(dist_extensions_root, entry)
    runtime_plugin_dir = File.join(runtime_extensions_root, entry)
    dist_plugin_node_modules_dir = File.join(dist_plugin_dir, 'node_modules')
    
    stage_plugin_runtime_overlay(dist_plugin_dir, runtime_plugin_dir)
    link_plugin_node_modules({
      runtime_plugin_dir: runtime_plugin_dir,
      source_plugin_node_modules_dir: dist_plugin_node_modules_dir
    })
  end
end

if __FILE__ == $0
  stage_bundled_plugin_runtime
end
