#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0fdba1f36ca0adbdadad92742df2173454e2ebd366e38c2461c57973a0356391", "source_sha256": "04f0268dc494793e85c15189558b4768a3e49a147b113ecc0fe3456b05d0eb20", "target_language": "ruby"}
# check-cli-startup-memory.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-cli-startup-memory.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'tempfile'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'json'

IS_LINUX = RUBY_PLATFORM.include?('linux')
IS_MAC = RUBY_PLATFORM.include?('darwin')

unless IS_LINUX || IS_MAC
  puts "[startup-memory] Skipping on unsupported platform: #{RUBY_PLATFORM}"
  exit(0)
end

repo_root = Dir.pwd
tmp_home = Dir.mktmpdir('openclaw-startup-memory-')
tmp_dir = ENV['TMPDIR'] || ENV['TEMP'] || ENV['TMP'] || Dir.tmpdir
rss_hook_path = File.join(tmp_home, 'measure-rss.rb')
MAX_RSS_MARKER = '__OPENCLAW_MAX_RSS_KB__='.freeze

File.write(rss_hook_path, <<~RUBY)
  at_exit do
    begin
      rss = Process.maxrss rescue nil
      if rss
        $stderr.puts "#{MAX_RSS_MARKER}\#{rss}"
      end
    rescue => e
      # Ignore errors in RSS measurement
    end
  end
RUBY

DEFAULT_LIMITS_MB = {
  help: 100,
  status_json: 400,
  gateway_status: 500
}.freeze

test_cases = [
  {
    id: 'help',
    label: '--help',
    args: ['openclaw.rb', '--help'],
    limit_mb: (ENV['OPENCLAW_STARTUP_MEMORY_HELP_MB'] || DEFAULT_LIMITS_MB[:help]).to_i
  },
  {
    id: 'status_json',
    label: 'status --json',
    args: ['openclaw.rb', 'status', '--json'],
    limit_mb: (ENV['OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB'] || DEFAULT_LIMITS_MB[:status_json]).to_i
  },
  {
    id: 'gateway_status',
    label: 'gateway status',
    args: ['openclaw.rb', 'gateway', 'status'],
    limit_mb: (ENV['OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB'] || DEFAULT_LIMITS_MB[:gateway_status]).to_i
  }
]

def format_fix_guidance(test_case, details)
  command = "ruby #{test_case[:args].join(' ')}"
  guidance = [
    '[startup-memory] Fix guidance',
    "Case: #{test_case[:label]}",
    "Command: #{command}",
    'Next steps:',
    "1. Run `#{command}` locally on the built tree.",
    '2. If this is an RSS overage, compare the startup import graph against the last passing commit and look for newly eager imports, bootstrap side effects, or plugin loading on the command path.',
    '3. If this is a non-zero exit, inspect the first transitive import/config error in stderr and fix that root cause before re-checking memory.',
    'LLM prompt:',
    "\"OpenClaw startup-memory CI failed for '#{test_case[:label]}'. Analyze this failure, identify the first runtime/import side effect that makes startup heavier or broken, and propose the smallest safe patch. Failure output:\n#{details}\""
  ]
  "#{guidance.join("\n")}\n"
end

def format_failure(test_case, message, details = '')
  trimmed_details = details.strip
  sections = [message]
  sections << trimmed_details unless trimmed_details.empty?
  sections << format_fix_guidance(test_case, trimmed_details.empty? ? message : trimmed_details)
  sections.join("\n\n")
end

def parse_max_rss_mb(stderr_output)
  matches = stderr_output.scan(/^#{Regexp.escape(MAX_RSS_MARKER)}(\d+)\s*$/)
  return nil if matches.empty?
  matches.last.first.to_f / 1024
end

def build_bench_env(tmp_home, tmp_dir)
  env = {
    'HOME' => tmp_home,
    'USERPROFILE' => tmp_home,
    'XDG_CONFIG_HOME' => File.join(tmp_home, '.config'),
    'XDG_DATA_HOME' => File.join(tmp_home, '.local', 'share'),
    'XDG_CACHE_HOME' => File.join(tmp_home, '.cache'),
    'PATH' => ENV['PATH'] || '',
    'TMPDIR' => tmp_dir,
    'TEMP' => tmp_dir,
    'TMP' => tmp_dir,
    'LANG' => ENV['LANG'] || 'C.UTF-8',
    'TERM' => ENV['TERM'] || 'dumb',
    'RUBY_DISABLE_COMPILE_CACHE' => '1' # Equivalent to NODE_DISABLE_COMPILE_CACHE
  }

  env['LC_ALL'] = ENV['LC_ALL'] if ENV['LC_ALL']
  env['CI'] = ENV['CI'] if ENV['CI']
  
  # Keep the benchmark on a single process so RSS reflects the actual command
  # path rather than the warning-suppression respawn wrapper.
  env['OPENCLAW_NO_RESPAWN'] = '1'

  env
end

def run_case(test_case, repo_root, tmp_home, tmp_dir, rss_hook_path)
  env = build_bench_env(tmp_home, tmp_dir)
  
  stdin, stdout, stderr, wait_thr = Open3.popen3(
    'ruby', '-r', rss_hook_path, *test_case[:args],
    chdir: repo_root,
    unsetenv_others: false
  )

  stdin.close
  
  stdout_data = stdout.read
  stderr_data = stderr.read
  
  stdout.close
  stderr.close
  
  status = wait_thr.value
  
  max_rss_mb = parse_max_rss_mb(stderr_data)
  matrix_bootstrap_warning = stderr_data.match?(/matrix: crypto runtime bootstrap failed/i)

  if !status.success?
    raise format_failure(
      test_case,
      "#{test_case[:label]} exited with #{status.exitstatus}",
      (stderr_data.strip.empty? ? stdout_data : stderr_data).strip
    )
  end

  if max_rss_mb.nil?
    raise format_failure(test_case, "#{test_case[:label]} did not report max RSS", stderr_data)
  end

  if matrix_bootstrap_warning
    raise format_failure(test_case, "#{test_case[:label]} triggered Matrix crypto bootstrap during startup")
  end

  if max_rss_mb > test_case[:limit_mb]
    raise format_failure(
      test_case,
      "#{test_case[:label]} used #{format('%.1f', max_rss_mb)} MB RSS (limit #{test_case[:limit_mb]} MB)"
    )
  end

  puts "[startup-memory] #{test_case[:label]}: #{format('%.1f', max_rss_mb)} MB RSS (limit #{test_case[:limit_mb]} MB)"
end

begin
  test_cases.each do |test_case|
    run_case(test_case, repo_root, tmp_home, tmp_dir, rss_hook_path)
  end
ensure
  FileUtils.rm_rf(tmp_home)
end
