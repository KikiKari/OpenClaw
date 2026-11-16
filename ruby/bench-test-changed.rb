#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "57ba0c5d3c7d949554f402e667d5ac96600815fb04d21a1b5e29cd890256cb91", "source_sha256": "671775b966561d4c6120ff043a4bb70e355d548215a9adf110f38e78918fc1e2", "target_language": "ruby"}
# bench-test-changed.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bench-test-changed.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'open3'
require 'pathname'

def parse_args(argv)
  args = {
    cwd: Dir.pwd,
    ref: 'origin/main',
    rss: RUBY_PLATFORM.include?('darwin'),
    mode: 'ref'
  }
  unknown_args = []
  i = 0
  while i < argv.length
    arg = argv[i]
    case arg
    when '--cwd'
      args[:cwd] = argv[i + 1]
      i += 1
    when '--ref'
      args[:ref] = argv[i + 1]
      i += 1
    when '--max-workers'
      args[:max_workers] = argv[i + 1].to_f
      i += 1
    when '--no-rss'
      args[:rss] = false
    when '--worktree'
      args[:mode] = 'worktree'
    else
      unknown_args << arg
    end
    i += 1
  end
  
  resolved_cwd = Pathname.new(args[:cwd]).expand_path.to_s
  {
    cwd: resolved_cwd,
    mode: args[:mode],
    ref: args[:ref],
    rss: args[:rss],
    max_workers: args[:max_workers] ? args[:max_workers].truncate : nil
  }
end

def quote_arg(arg)
  arg.match?(/[^A-Za-z0-9_\.\/:-]/) ? JSON.generate(arg) : arg
end

def run_git_list(args, cwd)
  stdout, stderr, status = Open3.capture3('git', *args, chdir: cwd)
  unless status.success?
    raise "git #{args.join(' ')} failed: #{stderr.empty? ? stdout : stderr}"
  end
  stdout.split("\n").map(&:strip).select { |line| !line.empty? }
end

def list_changed_paths(opts)
  if opts[:mode] == 'worktree'
    diff_files = run_git_list(['diff', '--name-only', '--relative', 'HEAD', '--'], opts[:cwd])
    untracked_files = run_git_list(['ls-files', '--others', '--exclude-standard'], opts[:cwd])
    (diff_files + untracked_files).uniq.sort
  else
    run_git_list(['diff', '--name-only', "#{opts[:ref]}...HEAD"], opts[:cwd])
  end
end

def parse_max_rss_kb(output)
  match = output.match(/(\d+)\s+maximum resident set size/)
  match ? match[1].to_i : nil
end

def format_rss(value_kb)
  if value_kb.nil?
    'n/a'
  else
    "#{'%.1f' % (value_kb / 1024.0)}MB"
  end
end

def format_ms(ms)
  if ms >= 1000
    "#{'%.1f' % (ms / 1000)}s"
  else
    "#{'%.0f' % ms}ms"
  end
end

def run_bench_command(params)
  env = ENV.to_h
  if params[:max_workers]
    env['OPENCLAW_VITEST_MAX_WORKERS'] = params[:max_workers].to_s
  end
  
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  
  if params[:rss]
    command = ['/usr/bin/time', '-l'] + params[:command]
    stdin, stdout, stderr, wait_thr = Open3.popen3(*command, chdir: params[:cwd], unsetenv_others: false)
    stdin.close
    output = stdout.read + stderr.read
    status = wait_thr.value
  else
    command = params[:command]
    stdin, stdout, stderr, wait_thr = Open3.popen3(command.first, *command[1..], chdir: params[:cwd], unsetenv_others: false, env: env)
    stdin.close
    output = stdout.read + stderr.read
    status = wait_thr.value
  end
  
  elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - started_at) / 1_000_000.0
  
  {
    elapsed_ms: elapsed_ms,
    max_rss_kb: params[:rss] ? parse_max_rss_kb(output) : nil,
    status: status.exitstatus || 1,
    output: output
  }
end

def print_run_summary(label, result)
  puts "#{label.ljust(8)} wall=#{format_ms(result[:elapsed_ms]).rjust(9)} rss=#{format_rss(result[:max_rss_kb]).rjust(9)}"
end

opts = parse_args(ARGV)
changed_paths = list_changed_paths(opts)

if changed_paths.empty?
  if opts[:mode] == 'worktree'
    puts '[bench-test-changed] no changed paths in worktree'
  else
    puts "[bench-test-changed] no changed paths for #{opts[:ref]}...HEAD"
  end
  exit(0)
end

if opts[:mode] == 'worktree'
  puts '[bench-test-changed] mode=worktree'
else
  puts "[bench-test-changed] ref=#{opts[:ref]}"
end

puts '[bench-test-changed] changed paths:'
changed_paths.each do |path|
  puts "- #{path}"
end

routed_command = if opts[:mode] == 'worktree'
                   [RbConfig.ruby, 'scripts/test-projects.mjs'] + changed_paths
                 else
                   [RbConfig.ruby, 'scripts/test-projects.mjs', '--changed', opts[:ref]]
                 end

root_command = [
  RbConfig.ruby,
  'scripts/run-vitest.mjs',
  'run',
  '--config',
  'vitest.config.ts'
] + changed_paths

puts "[bench-test-changed] routed: #{routed_command.map { |arg| quote_arg(arg) }.join(' ')}"
routed = run_bench_command({
  command: routed_command,
  cwd: opts[:cwd],
  rss: opts[:rss],
  max_workers: opts[:max_workers]
})

unless routed[:status].zero?
  $stderr.write(routed[:output])
  exit(routed[:status])
end

puts "[bench-test-changed] root:   #{root_command.map { |arg| quote_arg(arg) }.join(' ')}"
root = run_bench_command({
  command: root_command,
  cwd: opts[:cwd],
  rss: opts[:rss],
  max_workers: opts[:max_workers]
})

unless root[:status].zero?
  $stderr.write(root[:output])
  exit(root[:status])
end

print_run_summary('routed', routed)
print_run_summary('root', root)

delta_rss = if routed[:max_rss_kb] && root[:max_rss_kb]
              format_rss(root[:max_rss_kb] - routed[:max_rss_kb])
            else
              'n/a'
            end

puts "[bench-test-changed] delta wall=#{format_ms(root[:elapsed_ms] - routed[:elapsed_ms])} rss=#{delta_rss}"
