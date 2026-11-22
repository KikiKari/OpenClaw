#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "cb282d8b470556da2d9c2d72e9238a7f1d5297a4311942774ed439f68e80422b", "source_sha256": "a06acfb1e69451fcfc8e5635f9059bac455efbbaca76e0edae285b866e7f8409", "target_language": "ruby"}
# run-node.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-node.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require_relative './build_stamp'
require_relative './bundled_plugin_paths'
require_relative './runtime_postbuild'

BUILD_SCRIPT = 'scripts/tsdown-build.mjs'.freeze
COMPILER_ARGS = [BUILD_SCRIPT, '--no-clean'].freeze

RUN_NODE_SOURCE_ROOTS = ['src', BUNDLED_PLUGIN_ROOT_DIR].freeze
RUN_NODE_CONFIG_FILES = ['tsconfig.json', 'package.json', 'tsdown.config.ts'].freeze
RUN_NODE_WATCHED_PATHS = RUN_NODE_SOURCE_ROOTS + RUN_NODE_CONFIG_FILES

EXTENSION_SOURCE_FILE_PATTERN = /\.(?:[cm]?[jt]sx?)$/
EXTENSION_RESTART_METADATA_FILES = Set.new(['openclaw.plugin.json', 'package.json']).freeze

def normalize_path(file_path)
  (file_path || '').to_s.gsub('\\', '/')
end

def is_ignored_source_path(relative_path)
  normalized_path = normalize_path(relative_path)
  normalized_path.end_with?('.test.ts') ||
    normalized_path.end_with?('.test.tsx') ||
    normalized_path.end_with?('test-helpers.ts')
end

def is_build_relevant_source_path(relative_path)
  normalized_path = normalize_path(relative_path)
  EXTENSION_SOURCE_FILE_PATTERN.match?(normalized_path) && !is_ignored_source_path(normalized_path)
end

def is_build_relevant_run_node_path(repo_path)
  normalized_path = normalize_path(repo_path).sub(/^\.\/+/, '')
  if RUN_NODE_CONFIG_FILES.include?(normalized_path)
    return true
  end
  if normalized_path.start_with?('src/')
    return !is_ignored_source_path(normalized_path[4..])
  end
  if normalized_path.start_with?(BUNDLED_PLUGIN_PATH_PREFIX)
    return is_build_relevant_source_path(normalized_path[BUNDLED_PLUGIN_PATH_PREFIX.length..])
  end
  false
end

def is_restart_relevant_extension_path(relative_path)
  normalized_path = normalize_path(relative_path)
  basename = File.basename(normalized_path)
  if EXTENSION_RESTART_METADATA_FILES.include?(basename)
    return true
  end
  is_build_relevant_source_path(normalized_path)
end

def is_restart_relevant_run_node_path(repo_path)
  normalized_path = normalize_path(repo_path).sub(/^\.\/+/, '')
  if RUN_NODE_CONFIG_FILES.include?(normalized_path)
    return true
  end
  if normalized_path.start_with?('src/')
    return !is_ignored_source_path(normalized_path[4..])
  end
  if normalized_path.start_with?(BUNDLED_PLUGIN_PATH_PREFIX)
    return is_restart_relevant_extension_path(normalized_path[BUNDLED_PLUGIN_PATH_PREFIX.length..])
  end
  false
end

def stat_mtime(file_path, fs_impl = nil)
  fs_impl ||= File
  fs_impl.mtime(file_path).to_f * 1000
rescue
  nil
end

def is_excluded_source(file_path, source_root, source_root_name)
  relative_path = normalize_path(Pathname.new(file_path).relative_path_from(Pathname.new(source_root)).to_s)
  if relative_path.start_with?('..')
    return false
  end
  !is_build_relevant_run_node_path(File.join(source_root_name, relative_path))
end

def find_latest_mtime(dir_path, should_skip = nil, deps)
  latest = nil
  queue = [dir_path]
  
  while !queue.empty?
    current = queue.pop
    next unless current
    
    entries = []
    begin
      entries = Dir.children(current).map do |name|
        full_path = File.join(current, name)
        stat = deps[:fs].stat(full_path)
        {
          name: name,
          full_path: full_path,
          directory?: stat.directory?,
          file?: stat.file?
        }
      end
    rescue
      next
    end
    
    entries.each do |entry|
      if entry[:directory?]
        queue.push(entry[:full_path])
        next
      end
      
      next unless entry[:file?]
      
      if should_skip&.call(entry[:full_path])
        next
      end
      
      mtime = stat_mtime(entry[:full_path], deps[:fs])
      next unless mtime
      
      if latest.nil? || mtime > latest
        latest = mtime
      end
    end
  end
  
  latest
end

def read_git_status(deps)
  begin
    result = deps[:spawn_sync].call(
      'git',
      ['status', '--porcelain', '--untracked-files=normal', '--'] + RUN_NODE_WATCHED_PATHS,
      { chdir: deps[:cwd], out: :pipe, err: :discard }
    )
    
    if result.success?
      result.out
    else
      nil
    end
  rescue
    nil
  end
end

def parse_git_status_paths(output)
  return [] unless output
  
  output.split("\n").flat_map do |line|
    line[3..].split(' -> ')
  end.map do |entry|
    normalize_path(entry.strip)
  end.select(&:present?)
end

def has_dirty_source_tree(deps)
  output = read_git_status(deps)
  return nil if output.nil?
  
  parse_git_status_paths(output).any? { |repo_path| is_build_relevant_run_node_path(repo_path) }
end

def read_build_stamp(deps)
  mtime = stat_mtime(deps[:build_stamp_path], deps[:fs])
  return { mtime: nil, head: nil } if mtime.nil?
  
  begin
    raw = deps[:fs].read(deps[:build_stamp_path]).strip
    unless raw.start_with?('{')
      return { mtime: mtime, head: nil }
    end
    
    parsed = JSON.parse(raw)
    head = parsed['head'].is_a?(String) && !parsed['head'].strip.empty? ? parsed['head'].strip : nil
    { mtime: mtime, head: head }
  rescue
    { mtime: mtime, head: nil }
  end
end

def has_source_mtime_changed(stamp_mtime, deps)
  latest_source_mtime = nil
  
  deps[:source_roots].each do |source_root|
    source_mtime = find_latest_mtime(
      source_root[:path],
      ->(candidate) { is_excluded_source(candidate, source_root[:path], source_root[:name]) },
      deps
    )
    
    if source_mtime && (latest_source_mtime.nil? || source_mtime > latest_source_mtime)
      latest_source_mtime = source_mtime
    end
  end
  
  !latest_source_mtime.nil? && latest_source_mtime > stamp_mtime
end

def resolve_build_requirement(deps)
  if deps[:env]['OPENCLAW_FORCE_BUILD'] == '1'
    return { should_build: true, reason: 'force_build' }
  end
  
  stamp = read_build_stamp(deps)
  if stamp[:mtime].nil?
    return { should_build: true, reason: 'missing_build_stamp' }
  end
  
  if stat_mtime(deps[:dist_entry], deps[:fs]).nil?
    return { should_build: true, reason: 'missing_dist_entry' }
  end
  
  deps[:config_files].each do |file_path|
    mtime = stat_mtime(file_path, deps[:fs])
    if mtime && mtime > stamp[:mtime]
      return { should_build: true, reason: 'config_newer' }
    end
  end
  
  current_head = resolve_git_head(deps)
  if current_head && stamp[:head].nil?
    return { should_build: true, reason: 'build_stamp_missing_head' }
  end
  
  if current_head && stamp[:head] && current_head != stamp[:head]
    return { should_build: true, reason: 'git_head_changed' }
  end
  
  if current_head
    dirty = has_dirty_source_tree(deps)
    if dirty == true
      return { should_build: true, reason: 'dirty_watched_tree' }
    end
    if dirty == false
      return { should_build: false, reason: 'clean' }
    end
  end
  
  if has_source_mtime_changed(stamp[:mtime], deps)
    return { should_build: true, reason: 'source_mtime_newer' }
  end
  
  { should_build: false, reason: 'clean' }
end

BUILD_REASON_LABELS = {
  'force_build' => 'forced by OPENCLAW_FORCE_BUILD',
  'missing_build_stamp' => 'build stamp missing',
  'missing_dist_entry' => 'dist entry missing',
  'config_newer' => 'config newer than build stamp',
  'build_stamp_missing_head' => 'build stamp missing git head',
  'git_head_changed' => 'git head changed',
  'dirty_watched_tree' => 'dirty watched source tree',
  'source_mtime_newer' => 'source mtime newer than build stamp',
  'clean' => 'clean'
}.freeze

def format_build_reason(reason)
  BUILD_REASON_LABELS[reason] || reason
end

SIGNAL_EXIT_CODES = {
  'SIGINT' => 130,
  'SIGTERM' => 143
}.freeze

def is_signal_key(signal)
  SIGNAL_EXIT_CODES.key?(signal)
end

def get_signal_exit_code(signal)
  is_signal_key(signal) ? SIGNAL_EXIT_CODES[signal] : 1
end

def log_runner(message, deps)
  return if deps[:env]['OPENCLAW_RUNNER_LOG'] == '0'
  deps[:stderr].puts("[openclaw] #{message}")
end

def wait_for_spawned_process(child_process, deps)
  forwarded_signal = nil
  on_sigint = nil
  on_sigterm = nil
  
  cleanup_signals = lambda do
    if on_sigint
      deps[:process].trap('SIGINT', 'DEFAULT')
    end
    if on_sigterm
      deps[:process].trap('SIGTERM', 'DEFAULT')
    end
  end
  
  forward_signal = lambda do |signal|
    return if forwarded_signal
    forwarded_signal = signal
    begin
      Process.kill(signal, child_process.pid) if child_process.alive?
    rescue
      # Best-effort only. Exit handling still happens via the child "exit" event.
    end
  end
  
  on_sigint = lambda { forward_signal.call('SIGINT') }
  on_sigterm = lambda { forward_signal.call('SIGTERM') }
  
  deps[:process].trap('SIGINT', on_sigint)
  deps[:process].trap('SIGTERM', on_sigterm)
  
  begin
    child_process.wait
    { 
      exit_code: child_process.exit_status, 
      exit_signal: child_process.termsig ? Signal.signame(child_process.termsig) : nil, 
      forwarded_signal: forwarded_signal 
    }
  ensure
    cleanup_signals.call
  end
rescue => e
  cleanup_signals.call
  raise e
end

def run_open_claw(deps)
  child_process = deps[:spawn].call(deps[:exec_path], ['openclaw.mjs'] + deps[:args], {
    chdir: deps[:cwd],
    unsetenv_others: false,
    in: :inherit,
    out: :inherit,
    err: :inherit
  })
  
  res = wait_for_spawned_process(child_process, deps)
  
  if res[:exit_signal]
    return get_signal_exit_code(res[:exit_signal])
  end
  
  if res[:forwarded_signal]
    return get_signal_exit_code(res[:forwarded_signal])
  end
  
  res[:exit_code] || 1
end

def sync_runtime_artifacts(deps)
  deps[:run_runtime_post_build].call(cwd: deps[:cwd])
  true
rescue => error
  log_runner("Failed to write runtime build artifacts: #{error.message || 'unknown error'}", deps)
  false
end

def write_build_stamp(deps)
  write_dist_build_stamp(
    cwd: deps[:cwd],
    fs: deps[:fs],
    spawn_sync: deps[:spawn_sync]
  )
rescue => error
  # Best-effort stamp; still allow the runner to start.
  log_runner("Failed to write build stamp: #{error.message || 'unknown error'}", deps)
end

def should_skip_clean_watch_runtime_sync(deps)
  deps[:env]['OPENCLAW_WATCH_MODE'] == '1'
end

def run_node_main(params = {})
  deps = {
    spawn: params[:spawn] || method(:spawn),
    spawn_sync: params[:spawn_sync] || method(:spawn_sync),
    fs: params[:fs] || File,
    stderr: params[:stderr] || $stderr,
    process: params[:process] || Process,
    exec_path: params[:exec_path] || RbConfig.ruby,
    cwd: params[:cwd] || Dir.pwd,
    args: params[:args] || ARGV,
    env: params[:env] ? params[:env].dup : ENV.to_h,
    run_runtime_post_build: params[:run_runtime_post_build] || method(:run_runtime_post_build)
  }
  
  deps[:dist_root] = File.join(deps[:cwd], 'dist')
  deps[:dist_entry] = File.join(deps[:dist_root], 'entry.js')
  deps[:build_stamp_path] = File.join(deps[:dist_root], '.buildstamp')
  deps[:source_roots] = RUN_NODE_SOURCE_ROOTS.map do |source_root|
    { name: source_root, path: File.join(deps[:cwd], source_root) }
  end
  deps[:config_files] = RUN_NODE_CONFIG_FILES.map { |file_path| File.join(deps[:cwd], file_path) }
  
  build_requirement = resolve_build_requirement(deps)
  unless build_requirement[:should_build]
    unless should_skip_clean_watch_runtime_sync(deps) || sync_runtime_artifacts(deps)
      return 1
    end
    return run_open_claw(deps)
  end
  
  log_runner(
    "Building TypeScript (dist is stale: #{build_requirement[:reason]} - #{format_build_reason(build_requirement[:reason])}).",
    deps
  )
  
  build_cmd = deps[:exec_path]
  build_args = COMPILER_ARGS
  child_process = deps[:spawn].call(build_cmd, build_args, {
    chdir: deps[:cwd],
    unsetenv_others: false,
    in: :inherit,
    out: :inherit,
    err: :inherit
  })
  
  build_res = wait_for_spawned_process(child_process, deps)
  
  if build_res[:exit_signal]
    return get_signal_exit_code(build_res[:exit_signal])
  end
  
  if build_res[:forwarded_signal]
    return get_signal_exit_code(build_res[:forwarded_signal])
  end
  
  if build_res[:exit_code] && build_res[:exit_code] != 0
    return build_res[:exit_code]
  end
  
  unless sync_runtime_artifacts(deps)
    return 1
  end
  
  write_build_stamp(deps)
  run_open_claw(deps)
end

# Helper methods for process spawning
def spawn(command, args, options = {})
  Process.spawn(command, *args, options)
end

def spawn_sync(command, args, options = {})
  Open3.popen3(command, *args, options) do |stdin, stdout, stderr, wait_thr|
    {
      success?: wait_thr.value.success?,
      out: stdout.read,
      err: stderr.read
    }
  end
rescue => e
  {
    success?: false,
    out: '',
    err: e.message
  }
end

if __FILE__ == $0
  exit(run_node_main)
end
