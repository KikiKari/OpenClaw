#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "704dac0c8cfaa91ecc4da0e1d4430f8e3511c1542cc6c651c6ed4965e712f37f", "source_sha256": "12dffdae6f3576ff268694787ca9415cbb1e307cb0b7cb39a0784412c35e1318", "target_language": "ruby"}
# run-extension-oxlint.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/run-extension-oxlint.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require 'tmpdir'
require 'pathname'

def run_extension_oxlint(params)
  repo_root = Dir.pwd
  oxlint_path = File.expand_path('node_modules/.bin/oxlint')
  release_lock = acquire_local_heavy_check_lock_sync(
    cwd: repo_root,
    env: ENV.to_h,
    tool_name: params[:tool_name],
    lock_name: params[:lock_name]
  )
  temp_dir = Dir.mktmpdir(params[:temp_dir_prefix])
  temp_config_path = File.join(temp_dir, 'oxlint.json')
  exit_code = 0

  begin
    prepare_extension_package_boundary_artifacts(repo_root)

    extension_files = params[:roots].flat_map do |root|
      collect_typescript_files(File.expand_path(root, repo_root))
    end

    if extension_files.empty?
      STDERR.puts params[:empty_message]
      exit 1
    end

    write_temp_oxlint_config(repo_root, temp_config_path)

    base_args = ['-c', temp_config_path] + ARGV + extension_files
    final_args, env = apply_local_oxlint_policy(base_args, ENV.to_h)
    
    result = nil
    if Gem.win_platform?
      result = system(env, oxlint_path, *final_args)
    else
      result = system(env, "#{oxlint_path} #{final_args.join(' ')}")
    end
    
    exit_code = $?.exitstatus || 1
  ensure
    FileUtils.rm_rf(temp_dir)
    release_lock.call if release_lock.respond_to?(:call)
  end

  exit exit_code
end

def prepare_extension_package_boundary_artifacts(repo_root)
  release_lock = acquire_local_heavy_check_lock_sync(
    cwd: repo_root,
    env: ENV.to_h,
    tool_name: 'extension-package-boundary-artifacts',
    lock_name: 'extension-package-boundary-artifacts'
  )
  exit_code = 0

  begin
    script_path = File.expand_path('scripts/prepare-extension-package-boundary-artifacts.mjs', repo_root)
    result = system(ENV.to_h, "node #{script_path}")
    exit_code = $?.exitstatus || 1
  ensure
    release_lock.call if release_lock.respond_to?(:call)
  end

  exit exit_code unless exit_code == 0
end

def write_temp_oxlint_config(repo_root, config_path)
  config_file = File.expand_path('.oxlintrc.json', repo_root)
  config = JSON.parse(File.read(config_file))

  config.delete('$schema')

  if config['ignorePatterns'].is_a?(Array)
    extensions_ignore_pattern = config['ignorePatterns'].find do |pattern|
      is_top_level_extensions_ignore_pattern(pattern)
    end
    if extensions_ignore_pattern
      raise "Refusing to run extension oxlint with .oxlintrc.json ignore pattern #{extensions_ignore_pattern.inspect}. Remove the top-level extensions ignore so root and focused lint agree."
    end
  end

  File.write(config_path, "#{JSON.pretty_generate(config)}\n")
end

def is_top_level_extensions_ignore_pattern(pattern)
  normalized = pattern.strip.gsub('\\', '/').gsub(%r{^\.?/}, '')
  ['extensions', 'extensions/', 'extensions/**'].include?(normalized)
end

def collect_typescript_files(directory_path)
  entries = Dir.entries(directory_path).sort.map do |entry|
    File.join(directory_path, entry)
  end
  
  files = []

  entries.each do |entry_path|
    if File.directory?(entry_path)
      files.concat(collect_typescript_files(entry_path))
      next
    end

    next unless File.file?(entry_path)

    name = File.basename(entry_path)
    next unless name.end_with?('.ts') || name.end_with?('.tsx')

    relative_path = Pathname.new(entry_path).relative_path_from(Pathname.new(Dir.pwd)).to_s.gsub(File::SEPARATOR, '/')
    files.push(relative_path)
  end

  files
end

# Placeholder functions that would need to be implemented based on local-heavy-check-runtime.mjs
def acquire_local_heavy_check_lock_sync(options)
  # Implementation needed
  lambda {}
end

def apply_local_oxlint_policy(args, env)
  # Implementation needed
  [args, env]
end
