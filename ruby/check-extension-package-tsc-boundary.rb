#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f723f53f2c4b9ef5c6c7fd838b1232706f756fe269b479633a14ad1b05ff53f2", "source_sha256": "d3c03c21143a83c5721fdec0e2390424f9c499b86d0c2744a94c154b1be4b2bc", "target_language": "ruby"}
# check-extension-package-tsc-boundary.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-package-tsc-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require 'pathname'
require 'open3'
require 'securerandom'

REPO_ROOT = Pathname.new(__FILE__).dirname.parent.to_s.freeze
TSC_BIN = File.join(REPO_ROOT, 'node_modules/typescript/bin/tsc')
PREPARE_BOUNDARY_ARTIFACTS_BIN = File.join(REPO_ROOT, 'scripts/prepare-extension-package-boundary-artifacts.mjs')
EXTENSION_PACKAGE_BOUNDARY_BASE_CONFIG = '../tsconfig.package-boundary.base.json'
FAILURE_OUTPUT_TAIL_LINES = 40
SLOW_COMPILE_SUMMARY_LIMIT = 10
COMPILE_INPUT_EXTENSIONS = Set.new(%w[.ts .tsx .mts .cts .js .mjs .json])
ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH = '../../src/plugins/contracts/rootdir-boundary-canary.ts'
ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT = 'src/plugins/contracts/rootdir-boundary-canary.ts'

class BoundaryChecker
  def initialize
    @repo_root = REPO_ROOT
    @tsc_bin = TSC_BIN
    @prepare_boundary_artifacts_bin = PREPARE_BOUNDARY_ARTIFACTS_BIN
    @extension_package_boundary_base_config = EXTENSION_PACKAGE_BOUNDARY_BASE_CONFIG
    @failure_output_tail_lines = FAILURE_OUTPUT_TAIL_LINES
    @slow_compile_summary_limit = SLOW_COMPILE_SUMMARY_LIMIT
    @compile_input_extensions = COMPILE_INPUT_EXTENSIONS
    @rootdir_boundary_canary_import_path = ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH
    @rootdir_boundary_canary_output_hint = ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT
  end

  def parse_mode(argv)
    mode_arg = argv.find { |arg| arg.start_with?('--mode=') }
    mode = mode_arg ? mode_arg.split('=', 2).last : 'all'
    raise "Unknown mode: #{mode}" unless %w[all compile canary].include?(mode)
    mode
  end

  def resolve_compile_concurrency
    raw = ENV['OPENCLAW_EXTENSION_BOUNDARY_CONCURRENCY']
    parsed = raw ? Integer(raw) : nil
    if parsed.is_a?(Integer) && parsed > 0
      parsed
    else
      [(Etc.nprocessors / 2).floor, 1].max
    end
  rescue
    1
  end

  def read_json_file(file_path)
    JSON.parse(File.read(file_path))
  end

  def summarize_output_section(name, output)
    trimmed = output.strip
    return '' if trimmed.empty?

    lines = trimmed.split("\n")
    if lines.length <= @failure_output_tail_lines
      "#{name}:\n#{trimmed}"
    else
      omitted_line_count = lines.length - @failure_output_tail_lines
      tail = lines.last(@failure_output_tail_lines).join("\n")
      "#{name}:\n[... #{omitted_line_count} earlier lines omitted ...]\n#{tail}"
    end
  end

  def format_failure_footer(params = {})
    footer_lines = []
    footer_lines << "kind: #{params[:kind]}" if params[:kind]
    footer_lines << "elapsed: #{params[:elapsed_ms]}ms" if params[:elapsed_ms].is_a?(Numeric)
    footer_lines << params[:note] if params[:note]
    footer_lines.join("\n")
  end

  def format_boundary_check_success_summary(params = {})
    lines = ['extension package boundary check passed']
    lines << "mode: #{params[:mode]}" if params[:mode]
    lines << "compiled plugins: #{params[:compile_count]}" if params[:compile_count].is_a?(Integer)
    lines << "skipped plugins: #{params[:skipped_compile_count]}" if params[:skipped_compile_count].is_a?(Integer) && params[:skipped_compile_count] > 0
    lines << "canary plugins: #{params[:canary_count]}" if params[:canary_count].is_a?(Integer)
    lines << "prep elapsed: #{params[:prep_elapsed_ms]}ms" if params[:prep_elapsed_ms].is_a?(Numeric) && params[:prep_elapsed_ms] > 0
    lines << "compile elapsed: #{params[:compile_elapsed_ms]}ms" if params[:compile_elapsed_ms].is_a?(Numeric) && params[:compile_elapsed_ms] > 0
    lines << "canary elapsed: #{params[:canary_elapsed_ms]}ms" if params[:canary_elapsed_ms].is_a?(Numeric) && params[:canary_elapsed_ms] > 0
    lines << "elapsed: #{params[:elapsed_ms]}ms" if params[:elapsed_ms].is_a?(Numeric)
    "#{lines.join("\n")}\n"
  end

  def format_skipped_compile_progress(params = {})
    skipped_count = params[:skipped_count] || 0
    total_count = params[:total_count] || 0
    return '' unless skipped_count.is_a?(Integer) && skipped_count > 0

    stale_count = [0, total_count - skipped_count].max
    if stale_count > 0
      "skipped #{skipped_count} fresh plugin compiles before running #{stale_count} stale plugin checks\n"
    else
      "skipped #{skipped_count} fresh plugin compiles\n"
    end
  end

  def format_slow_compile_summary(params = {})
    compile_timings = params[:compile_timings].is_a?(Array) ? params[:compile_timings] : []
    return '' if compile_timings.empty?

    limit = params[:limit].is_a?(Integer) && params[:limit] > 0 ? params[:limit] : @slow_compile_summary_limit
    sorted_timings = compile_timings.sort_by { |t| -t[:elapsed_ms] }.first(limit)
    lines = ['slowest plugin compiles:']
    sorted_timings.each do |timing|
      lines << "- #{timing[:extension_id]}: #{timing[:elapsed_ms]}ms"
    end
    "#{lines.join("\n")}\n"
  end

  def format_step_failure(label, params = {})
    stdout_section = summarize_output_section('stdout', params[:stdout] || '')
    stderr_section = summarize_output_section('stderr', params[:stderr] || '')
    footer = format_failure_footer(params)
    [label, stdout_section, stderr_section, footer].reject(&:empty?).join("\n\n")
  end

  def attach_step_failure_metadata(error, label, params = {})
    error.instance_variable_set(:@step_label, label)
    error.instance_variable_set(:@kind, params[:kind] || 'unknown')
    error.instance_variable_set(:@elapsed_ms, params[:elapsed_ms] || nil)
    full_output_parts = [label, params[:stdout] || '', params[:stderr] || '', format_failure_footer(params)].reject(&:empty?)
    error.instance_variable_set(:@full_output, full_output_parts.join("\n").strip)
    error
  end

  def collect_bundled_extension_ids
    extensions_dir = File.join(@repo_root, 'extensions')
    return [] unless Dir.exist?(extensions_dir)
    
    Dir.children(extensions_dir)
       .select { |entry| File.directory?(File.join(extensions_dir, entry)) }
       .sort
  end

  def resolve_extension_tsconfig_path(extension_id)
    File.join(@repo_root, 'extensions', extension_id, 'tsconfig.json')
  end

  def read_extension_tsconfig(extension_id)
    read_json_file(resolve_extension_tsconfig_path(extension_id))
  end

  def collect_opt_in_extension_ids
    collect_bundled_extension_ids.select do |extension_id|
      tsconfig_path = resolve_extension_tsconfig_path(extension_id)
      File.exist?(tsconfig_path) && 
        read_extension_tsconfig(extension_id)['extends'] == @extension_package_boundary_base_config
    end
  end

  def collect_canary_extension_ids(extension_ids)
    unique_configs = {}
    extension_ids.each do |extension_id|
      config_key = JSON.generate(read_extension_tsconfig(extension_id))
      unique_configs[config_key] = extension_id
    end
    unique_configs.values
  end

  def is_relevant_compile_input(file_path)
    basename = File.basename(file_path)
    return false if %w[__rootdir_boundary_canary__.ts tsconfig.rootdir-canary.json].include?(basename)
    return false if basename.end_with?('.tsbuildinfo')
    @compile_input_extensions.include?(File.extname(file_path))
  end

  def collect_newest_mtime(entry_path, params = {})
    include_file = params[:include_file] || ->(_) { true }
    skip_dist_directories = params.fetch(:skip_dist_directories, true)
    newest_mtime_ms = 0

    visit = lambda do |current_path|
      return unless File.exist?(current_path)
      
      stat = File.stat(current_path)
      if stat.directory?
        basename = File.basename(current_path)
        return if (skip_dist_directories && basename == 'dist') || basename == 'node_modules'
        
        Dir.children(current_path).each do |child|
          visit.call(File.join(current_path, child))
        end
        return
      end
      
      return unless include_file.call(current_path)
      newest_mtime_ms = [newest_mtime_ms, stat.mtime.to_f * 1000].max
    end

    visit.call(entry_path)
    newest_mtime_ms
  end

  def collect_oldest_mtime(paths)
    oldest_mtime_ms = Float::INFINITY
    
    paths.each do |entry_path|
      return nil unless File.exist?(entry_path)
      oldest_mtime_ms = [oldest_mtime_ms, File.stat(entry_path).mtime.to_f * 1000].min
    end
    
    oldest_mtime_ms.finite? ? oldest_mtime_ms : nil
  end

  def is_boundary_compile_fresh(extension_id, params = {})
    root_dir = params[:root_dir] || @repo_root
    extension_root = File.join(root_dir, 'extensions', extension_id)
    
    extension_newest_input_mtime_ms = params[:extension_newest_input_mtime_ms] || 
      collect_newest_mtime(extension_root, include_file: method(:is_relevant_compile_input))
    
    shared_newest_input_mtime_ms = params[:shared_newest_input_mtime_ms] || 
      [
        collect_newest_mtime(File.join(root_dir, 'dist/plugin-sdk'), skip_dist_directories: false),
        collect_newest_mtime(File.join(root_dir, 'packages/plugin-sdk/dist'), skip_dist_directories: false)
      ].max
    
    newest_input_mtime_ms = [extension_newest_input_mtime_ms, shared_newest_input_mtime_ms].max
    oldest_output_mtime_ms = collect_oldest_mtime([resolve_boundary_ts_stamp_path(extension_id, root_dir)])
    
    oldest_output_mtime_ms != nil && oldest_output_mtime_ms >= newest_input_mtime_ms
  end

  def write_stamp_file(file_path)
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "#{Time.now.iso8601}\n", encoding: 'utf-8')
  end

  def run_node_step(label, args, timeout_ms)
    started_at = Time.now
    stdin, stdout, stderr, wait_thr = Open3.popen3(*([RbConfig.ruby] + args), chdir: @repo_root)
    
    begin
      stdin.close
      output_thread = Thread.new do
        result = { stdout: '', stderr: '' }
        stdout_thread = Thread.new { result[:stdout] = stdout.read }
        stderr_thread = Thread.new { result[:stderr] = stderr.read }
        stdout_thread.join
        stderr_thread.join
        result
      end
      
      result = output_thread.value
      status = wait_thr.value
      
      if status.success?
        return result.merge(elapsed_ms: ((Time.now - started_at) * 1000).to_i)
      end
      
      elapsed_ms = ((Time.now - started_at) * 1000).to_i
      kind = 'nonzero-exit'
      note = ''
      
      if result[:stderr]&.include?('ETIMEDOUT')
        kind = 'timeout'
        note = "#{label} timed out after #{timeout_ms}ms"
      end
      
      failure = attach_step_failure_metadata(
        StandardError.new(format_step_failure(label, {
          stdout: result[:stdout],
          stderr: result[:stderr],
          kind: kind,
          elapsed_ms: elapsed_ms,
          note: note
        })),
        label,
        {
          stdout: result[:stdout],
          stderr: result[:stderr],
          kind: kind,
          elapsed_ms: elapsed_ms,
          note: note
        }
      )
      failure.instance_variable_set(:@status, status.exitstatus || 1)
      raise failure
    ensure
      stdin.close if !stdin.closed?
      stdout.close if !stdout.closed?
      stderr.close if !stderr.closed?
    end
  end

  def abort_sibling_steps(abort_controller)
    # In Ruby we don't have AbortController equivalent, so this is a no-op
  end

  def run_node_step_async(label, args, timeout_ms, params = {})
    abort_controller = params[:abort_controller]
    on_failure = params[:on_failure]
    started_at = Time.now
    
    promise = Concurrent::Promise.execute do
      stdin, stdout, stderr, wait_thr = Open3.popen3(*([RbConfig.ruby] + args), chdir: @repo_root)
      
      begin
        stdin.close
        result = { stdout: '', stderr: '', elapsed_ms: 0 }
        
        # Read output with timeout
        output_thread = Thread.new do
          begin
            result[:stdout] = stdout.read_nonblock(16 * 1024 * 1024) while true
          rescue EOFError
          rescue IO::WaitReadable
            IO.select([stdout])
            retry
          end
          
          begin
            result[:stderr] = stderr.read_nonblock(16 * 1024 * 1024) while true
          rescue EOFError
          rescue IO::WaitReadable
            IO.select([stderr])
            retry
          end
        end
        
        # Handle timeout
        timeout_thread = Thread.new do
          sleep(timeout_ms / 1000.0)
          Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
        end
        
        output_thread.join
        timeout_thread.kill
        status = wait_thr.value
        
        result[:elapsed_ms] = ((Time.now - started_at) * 1000).to_i
        
        if status.success?
          result
        else
          kind = 'nonzero-exit'
          note = ''
          
          if result[:stderr]&.include?('ETIMEDOUT')
            kind = 'timeout'
            note = "#{label} timed out after #{timeout_ms}ms"
          end
          
          error = attach_step_failure_metadata(
            StandardError.new(format_step_failure(label, {
              stdout: result[:stdout],
              stderr: result[:stderr],
              kind: kind,
              elapsed_ms: result[:elapsed_ms],
              note: note
            })),
            label,
            {
              stdout: result[:stdout],
              stderr: result[:stderr],
              kind: kind,
              elapsed_ms: result[:elapsed_ms],
              note: note
            }
          )
          on_failure&.call(error)
          raise error
        end
      ensure
        stdin.close if !stdin.closed?
        stdout.close if !stdout.closed?
        stderr.close if !stderr.closed?
      end
    end
    
    promise
  end

  def run_node_steps_with_concurrency(steps, concurrency)
    # Simplified implementation - run sequentially for now
    steps.each do |step|
      step[:on_start]&.call
      run_node_step(step[:label], step[:args], step[:timeout_ms])
      step[:on_success]&.call({ elapsed_ms: 0 }) # Placeholder
    end
  end

  def resolve_canary_artifact_paths(extension_id, root_dir = @repo_root)
    extension_root = File.join(root_dir, 'extensions', extension_id)
    {
      extension_root: extension_root,
      canary_path: File.join(extension_root, '__rootdir_boundary_canary__.ts'),
      tsconfig_path: File.join(extension_root, 'tsconfig.rootdir-canary.json')
    }
  end

  def cleanup_canary_artifacts(extension_id, root_dir = @repo_root)
    paths = resolve_canary_artifact_paths(extension_id, root_dir)
    File.delete(paths[:canary_path]) if File.exist?(paths[:canary_path])
    File.delete(paths[:tsconfig_path]) if File.exist?(paths[:tsconfig_path])
  end

  def cleanup_canary_artifacts_for_extensions(extension_ids, root_dir = @repo_root)
    extension_ids.each { |id| cleanup_canary_artifacts(id, root_dir) }
  end

  def install_canary_artifact_cleanup(extension_ids, params = {})
    root_dir = params[:root_dir] || @repo_root
    at_exit { cleanup_canary_artifacts_for_extensions(extension_ids, root_dir) }
  end

  def resolve_boundary_ts_build_info_path(extension_id)
    File.join(@repo_root, 'extensions', extension_id, 'dist', '.boundary-tsc.tsbuildinfo')
  end

  def resolve_boundary_ts_stamp_path(extension_id, root_dir = @repo_root)
    File.join(root_dir, 'extensions', extension_id, 'dist', '.boundary-tsc.stamp')
  end

  def resolve_boundary_check_lock_path(root_dir = @repo_root)
    File.join(root_dir, 'dist', '.extension-package-boundary.lock')
  end

  def resolve_boundary_check_lock_owner_path(lock_path)
    File.join(lock_path, 'owner.json')
  end

  def is_process_alive(pid)
    return false unless pid.is_a?(Integer) && pid > 0
    begin
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end
  end

  def remove_stale_boundary_check_lock(lock_path)
    owner_path = resolve_boundary_check_lock_owner_path(lock_path)
    owner = nil
    
    begin
      owner = JSON.parse(File.read(owner_path))
    rescue
      FileUtils.rm_rf(lock_path)
      return true
    end
    
    if owner.is_a?(Hash) && is_process_alive(owner['pid'])
      false
    else
      FileUtils.rm_rf(lock_path)
      true
    end
  end

  def acquire_boundary_check_lock(params = {})
    root_dir = params[:root_dir] || @repo_root
    lock_path = resolve_boundary_check_lock_path(root_dir)
    FileUtils.mkdir_p(File.dirname(lock_path))
    
    begin
      Dir.mkdir(lock_path)
    rescue Errno::EEXIST
      if remove_stale_boundary_check_lock(lock_path)
        Dir.mkdir(lock_path)
      else
        error = attach_step_failure_metadata(
          StandardError.new([
            'extension package boundary check',
            'kind: lock-contention',
            "lock: #{lock_path}",
            'another extension package boundary check is already running in this checkout'
          ].join("\n\n")),
          'extension package boundary check',
          {
            kind: 'lock-contention',
            note: "lock: #{lock_path}\nanother extension package boundary check is already running in this checkout"
          }
        )
        raise error
      end
    end
    
    File.write(
      resolve_boundary_check_lock_owner_path(lock_path),
      JSON.pretty_generate({ pid: Process.pid, started_at: Time.now.iso8601 }) + "\n",
      encoding: 'utf-8'
    )
    
    release_proc = lambda { FileUtils.rm_rf(lock_path) }
    at_exit(&release_proc)
    release_proc
  end

  def run_compile_check(extension_ids)
    prep_started_at = Time.now
    puts "preparing plugin-sdk boundary artifacts for #{extension_ids.length} plugins"
    run_node_step('plugin-sdk boundary prep', [@prepare_boundary_artifacts_bin], 420_000)
    prep_elapsed_ms = ((Time.now - prep_started_at) * 1000).to_i
    
    concurrency = resolve_compile_concurrency
    verbose_fresh_logs = ENV['OPENCLAW_EXTENSION_BOUNDARY_VERBOSE_FRESH'] == '1'
    
    shared_newest_input_mtime_ms = [
      collect_newest_mtime(File.join(@repo_root, 'dist/plugin-sdk'), skip_dist_directories: false),
      collect_newest_mtime(File.join(@repo_root, 'packages/plugin-sdk/dist'), skip_dist_directories: false)
    ].max
    
    puts "compile concurrency #{concurrency}"
    compile_started_at = Time.now
    skipped_compile_count = 0
    compile_timings = []
    
    steps = extension_ids.map.with_index do |extension_id, index|
      ts_build_info_path = resolve_boundary_ts_build_info_path(extension_id)
      extension_newest_input_mtime_ms = collect_newest_mtime(
        File.join(@repo_root, 'extensions', extension_id),
        include_file: method(:is_relevant_compile_input)
      )
      
      FileUtils.mkdir_p(File.dirname(ts_build_info_path))
      
      if is_boundary_compile_fresh(extension_id, {
        extension_newest_input_mtime_ms: extension_newest_input_mtime_ms,
        shared_newest_input_mtime_ms: shared_newest_input_mtime_ms
      })
        skipped_compile_count += 1
        if verbose_fresh_logs
          puts "[#{index + 1}/#{extension_ids.length}] #{extension_id} (fresh; skipping)"
        end
        next nil
      end
      
      {
        label: extension_id,
        on_start: lambda { puts "[#{index + 1}/#{extension_ids.length}] #{extension_id}" },
        on_success: lambda do |result|
          write_stamp_file(resolve_boundary_ts_stamp_path(extension_id))
          compile_timings << {
            extension_id: extension_id,
            elapsed_ms: result[:elapsed_ms]
          }
        end,
        args: [
          @tsc_bin,
          '-p',
          File.join(@repo_root, 'extensions', extension_id, 'tsconfig.json'),
          '--noEmit',
          '--incremental',
          '--tsBuildInfoFile',
          ts_build_info_path
        ],
        timeout_ms: 120_000
      }
    end.compact
    
    unless verbose_fresh_logs || skipped_compile_count.zero?
      puts format_skipped_compile_progress({
        skipped_count: skipped_compile_count,
        total_count: extension_ids.length
      })
    end
    
    unless steps.empty?
      run_node_steps_with_concurrency(steps, concurrency)
    end
    
    {
      prep_elapsed_ms: prep_elapsed_ms,
      compile_count: steps.length,
      skipped_compile_count: skipped_compile_count,
      compile_elapsed_ms: ((Time.now - compile_started_at) * 1000).to_i,
      compile_timings: compile_timings
    }
  end

  def run_canary_check(extension_ids)
    started_at = Time.now
    extension_ids.each_with_index do |extension_id, index|
      paths = resolve_canary_artifact_paths(extension_id)
      
      cleanup_canary_artifacts(extension_id)
      puts "[#{index + 1}/#{extension_ids.length}] #{extension_id} canary"
      
      begin
        File.write(
          paths[:canary_path],
          [
            "import { ROOTDIR_BOUNDARY_CANARY } from \"#{@rootdir_boundary_canary_import_path}\";",
            'void ROOTDIR_BOUNDARY_CANARY;',
            'export {};',
            ''
          ].join("\n"),
          encoding: 'utf-8'
        )
        
        File.write(
          paths[:tsconfig_path],
          JSON.pretty_generate({
            extends: './tsconfig.json',
            include: ['./__rootdir_boundary_canary__.ts'],
            exclude: []
          }) + "\n",
          encoding: 'utf-8'
        )
        
        result = run_node_step_async(
          "#{extension_id} canary",
          [@tsc_bin, '-p', paths[:tsconfig_path], '--noEmit'],
          120_000,
          {}
        ).value!
        
        raise StandardError.new("#{extension_id} canary unexpectedly passed\n#{result[:stdout]}#{result[:stderr]}")
      rescue => error
        output = error.instance_variable_get(:@full_output) || error.to_s
        unless output.include?('TS6059') && output.include?(@rootdir_boundary_canary_output_hint)
          raise error
        end
      ensure
        cleanup_canary_artifacts(extension_id)
      end
    end
    
    {
      canary_elapsed_ms: ((Time.now - started_at) * 1000).to_i
    }
  end

  def main(argv = ARGV)
    started_at = Time.now
    mode = parse_mode(argv)
    opt_in_extension_ids = collect_opt_in_extension_ids
    canary_extension_ids = collect_canary_extension_ids(opt_in_extension_ids)
    cleanup_extension_ids = opt_in_extension_ids
    should_run_canary = mode == 'all' || mode == 'canary'
    
    release_boundary_lock = acquire_boundary_check_lock
    teardown_canary_cleanup = install_canary_artifact_cleanup(cleanup_extension_ids)
    
    prep_elapsed_ms = nil
    compile_count = 0
    skipped_compile_count = 0
    compile_elapsed_ms = nil
    compile_timings = []
    canary_elapsed_ms = nil
    
    begin
      cleanup_canary_artifacts_for_extensions(cleanup_extension_ids)
      
      if mode == 'all' || mode == 'compile'
        results = run_compile_check(opt_in_extension_ids)
        prep_elapsed_ms = results[:prep_elapsed_ms]
        compile_count = results[:compile_count]
        skipped_compile_count = results[:skipped_compile_count]
        compile_elapsed_ms = results[:compile_elapsed_ms]
        compile_timings = results[:compile_timings]
      end
      
      if should_run_canary
        canary_results = run_canary_check(canary_extension_ids)
        canary_elapsed_ms = canary_results[:canary_elapsed_ms]
      end
      
      puts format_boundary_check_success_summary({
        mode: mode,
        compile_count: compile_count,
        skipped_compile_count: skipped_compile_count,
        canary_count: should_run_canary ? canary_extension_ids.length : 0,
        prep_elapsed_ms: prep_elapsed_ms,
        compile_elapsed_ms: compile_elapsed_ms,
        canary_elapsed_ms: canary_elapsed_ms,
        elapsed_ms: ((Time.now - started_at) * 1000).to_i
      })
      
      puts format_slow_compile_summary({
        compile_timings: compile_timings
      })
    ensure
      release_boundary_lock&.call
      teardown_canary_cleanup&.call
      cleanup_canary_artifacts_for_extensions(cleanup_extension_ids)
    end
  end
end

# Main execution
if __FILE__ == $0
  checker = BoundaryChecker.new
  checker.main
end
