#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9a44a497df649f06cae7880f90729856d3605966fa694a5f5278fd04c6af1e8d", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "ruby"}
# bundle-a2ui.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'pathname'

def fail(message)
  $stderr.puts message
  $stderr.puts "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle"
  $stderr.puts "If this persists, verify pnpm deps and try again."
  exit 1
end

def path_exists?(target_path)
  File.exist?(target_path)
rescue
  false
end

def normalize_path(file_path)
  file_path.gsub(File::SEPARATOR, '/')
end

def is_bundle_hash_input_path(file_path, repo_root = @root_dir)
  relative_path = normalize_path(Pathname.new(file_path).relative_path_from(repo_root).to_s)
  !@ignored_bundle_hash_input_prefixes.any? do |ignored_path|
    relative_path == ignored_path || relative_path.start_with?("#{ignored_path}/")
  end
end

def get_local_rolldown_cli_candidates(repo_root = @root_dir)
  [
    File.join(repo_root, "node_modules", "rolldown", "bin", "cli.mjs"),
    File.join(repo_root, "node_modules", ".pnpm", "node_modules", "rolldown", "bin", "cli.mjs"),
    File.join(
      repo_root,
      "node_modules",
      ".pnpm",
      "rolldown@1.0.0-rc.12",
      "node_modules",
      "rolldown",
      "bin",
      "cli.mjs"
    )
  ]
end

def walk_files(entry_path, files)
  return unless is_bundle_hash_input_path(entry_path)
  
  if File.directory?(entry_path)
    Dir.entries(entry_path).each do |entry|
      next if entry == '.' || entry == '..'
      walk_files(File.join(entry_path, entry), files)
    end
  else
    files << entry_path
  end
end

def list_tracked_input_files
  stdout, stderr, status = Open3.capture3("git", "ls-files", "--", *@relative_input_paths, chdir: @root_dir)
  
  if status != 0
    return nil
  end
  
  stdout.split("\n").select(&:present?).map do |file_path|
    File.join(@root_dir, file_path)
  end.select do |file_path|
    is_bundle_hash_input_path(file_path)
  end
rescue
  nil
end

def compute_hash
  files = list_tracked_input_files
  
  if files.nil?
    files = []
    @input_paths.each do |input_path|
      walk_files(input_path, files)
    end
  end
  
  files.sort! do |left, right|
    normalize_path(left) <=> normalize_path(right)
  end
  
  hash = Digest::SHA256.new
  
  files.each do |file_path|
    hash.update(normalize_path(Pathname.new(file_path).relative_path_from(@root_dir).to_s))
    hash.update("\0")
    hash.update(File.read(file_path))
    hash.update("\0")
  end
  
  hash.hexdigest
end

def run_step(command, args, options = {})
  argv = [command] + args
  stdin, stdout, stderr, wait_thr = Open3.popen3(*argv, chdir: @root_dir)
  
  stdin.close
  stdout.close
  stderr.close
  
  exit_status = wait_thr.value
  unless exit_status.success?
    exit exit_status.exitstatus || 1
  end
end

def run_pnpm(pnpm_args)
  # Simplified implementation - assumes pnpm is available in PATH
  run_step("pnpm", pnpm_args)
end

def main
  has_renderer_dir = path_exists?(@a2ui_renderer_dir)
  has_app_dir = path_exists?(@a2ui_app_dir)
  has_output_file = path_exists?(@output_file)
  
  if !has_renderer_dir || !has_app_dir
    if has_output_file
      puts "A2UI sources missing; keeping prebuilt bundle."
      return
    end
    
    if ENV['OPENCLAW_SPARSE_PROFILE'] || ENV['OPENCLAW_A2UI_SKIP_MISSING'] == '1'
      $stderr.puts "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set."
      return
    end
    
    fail "A2UI sources missing and no prebuilt bundle found at: #{@output_file}"
  end
  
  current_hash = compute_hash
  
  if path_exists?(@hash_file)
    previous_hash = File.read(@hash_file).strip
    if previous_hash == current_hash && has_output_file
      puts "A2UI bundle up to date; skipping."
      return
    end
  end
  
  run_pnpm(["-s", "exec", "tsc", "-p", File.join(@a2ui_renderer_dir, "tsconfig.json")])
  
  local_rolldown_cli_candidates = get_local_rolldown_cli_candidates(@root_dir)
  local_rolldown_cli = local_rolldown_cli_candidates.find { |candidate| path_exists?(candidate) }
  
  if local_rolldown_cli
    run_step("node", [local_rolldown_cli, "-c", File.join(@a2ui_app_dir, "rolldown.config.mjs")])
  else
    run_pnpm(["-s", "exec", "rolldown", "-c", File.join(@a2ui_app_dir, "rolldown.config.mjs")])
  end
  
  File.write(@hash_file, "#{current_hash}\n")
end

# Initialize constants
script_path = File.expand_path(__FILE__)
@root_dir = File.expand_path("..", File.dirname(script_path))

@hash_file = File.join(@root_dir, "src", "canvas-host", "a2ui", ".bundle.hash")
@output_file = File.join(@root_dir, "src", "canvas-host", "a2ui", "a2ui.bundle.js")
@a2ui_renderer_dir = File.join(@root_dir, "vendor", "a2ui", "renderers", "lit")
@a2ui_app_dir = File.join(@root_dir, "apps", "shared", "OpenClawKit", "Tools", "CanvasA2UI")

@input_paths = [
  File.join(@root_dir, "package.json"),
  File.join(@root_dir, "pnpm-lock.yaml"),
  @a2ui_renderer_dir,
  @a2ui_app_dir
]

@ignored_bundle_hash_input_prefixes = ["vendor/a2ui/renderers/lit/dist"]
@relative_input_paths = @input_paths.map do |input_path|
  normalize_path(Pathname.new(input_path).relative_path_from(@root_dir).to_s)
end

if __FILE__ == $0
  begin
    main
  rescue => e
    fail(e.message)
  end
end
