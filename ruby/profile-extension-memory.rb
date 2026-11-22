#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "02206af57ecfdce83004ba1cb7c46f2efb6ce1eec764bf1ce67c31d2cb9f37ac", "source_sha256": "93ecf5d3490bf6c88b3f288ec409b9375009242d467e26772ba3a10251e1d9b7", "target_language": "ruby"}
# profile-extension-memory.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/profile-extension-memory.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require "json"
require "fileutils"
require "tmpdir"
require "pathname"
require "securerandom"
require "open3"
require "English"

DEFAULT_CONCURRENCY = 6
DEFAULT_TIMEOUT_MS = 90_000
DEFAULT_COMBINED_TIMEOUT_MS = 180_000
DEFAULT_TOP = 10
RSS_MARKER = "__OPENCLAW_MAX_RSS_KB__=".freeze

def print_help
  puts <<~HELP
    Usage: ruby scripts/profile-extension-memory.rb [options]

    Profiles peak RSS for built bundled plugin entrypoints.
    Run pnpm build first if you want stats for the latest source changes.

    Options:
      --extension, -e <id>     Limit profiling to one or more extension ids (repeatable)
      --concurrency <n>        Number of per-extension workers (default: #{DEFAULT_CONCURRENCY})
      --timeout-ms <ms>        Per-extension timeout in milliseconds (default: #{DEFAULT_TIMEOUT_MS})
      --combined-timeout-ms <ms>
                               Combined-import timeout in milliseconds (default: #{DEFAULT_COMBINED_TIMEOUT_MS})
      --top <n>                Show top N entries by delta from baseline (default: #{DEFAULT_TOP})
      --json <path>            Write full JSON report to this path
      --skip-combined          Skip the combined all-imports measurement
      --help                   Show this help

    Examples:
      pnpm test:extensions:memory
      pnpm test:extensions:memory -- --extension discord
      pnpm test:extensions:memory -- --extension discord --extension telegram --skip-combined
  HELP
end

def parse_positive_int(raw, flag_name)
  parsed = Integer(raw)
  raise "#{flag_name} must be a positive integer" unless parsed > 0
  parsed
rescue ArgumentError
  raise "#{flag_name} must be a positive integer"
end

def parse_args(argv)
  options = {
    extensions: [],
    concurrency: DEFAULT_CONCURRENCY,
    timeout_ms: DEFAULT_TIMEOUT_MS,
    combined_timeout_ms: DEFAULT_COMBINED_TIMEOUT_MS,
    top: DEFAULT_TOP,
    json_path: nil,
    skip_combined: false
  }

  index = 0
  while index < argv.length
    arg = argv[index]
    case arg
    when "--"
      # ignore
    when "--extension", "-e"
      next_arg = argv[index + 1]
      raise "#{arg} requires a value" unless next_arg
      options[:extensions] << next_arg
      index += 1
    when "--concurrency"
      options[:concurrency] = parse_positive_int(argv[index + 1], arg)
      index += 1
    when "--timeout-ms"
      options[:timeout_ms] = parse_positive_int(argv[index + 1], arg)
      index += 1
    when "--combined-timeout-ms"
      options[:combined_timeout_ms] = parse_positive_int(argv[index + 1], arg)
      index += 1
    when "--top"
      options[:top] = parse_positive_int(argv[index + 1], arg)
      index += 1
    when "--json"
      next_arg = argv[index + 1]
      raise "#{arg} requires a value" unless next_arg
      options[:json_path] = Pathname.new(next_arg).expand_path.to_s
      index += 1
    when "--skip-combined"
      options[:skip_combined] = true
    when "--help", "-h"
      print_help
      exit(0)
    else
      raise "Unknown argument: #{arg}"
    end
    index += 1
  end

  options
end

def parse_max_rss_mb(stderr)
  matches = stderr.scan(/^#{RSS_MARKER}(\d+)\s*$/)
  last_match = matches.last
  last_match ? last_match[0].to_f / 1024 : nil
end

def summarize_stderr(stderr, lines = 8)
  stderr.strip.split("\n").reject(&:empty?).first(lines).join("\n")
end

def run_case(repo_root:, env:, hook_path:, name:, body:, timeout_ms:)
  Thread.new do
    stdin, stdout, stderr, wait_thr = Open3.popen3(
      RUBY_ENGINE == "jruby" ? "java" : RUBY_PLATFORM.include?("mingw") ? "ruby.exe" : "ruby",
      "--disable=gems",
      "-r", hook_path,
      "-e", body,
      chdir: repo_root,
      unsetenv_others: true,
      pgroup: true
    )

    output = ""
    error_output = ""

    begin
      Timeout.timeout(timeout_ms / 1000.0) do
        stdout_thread = Thread.new { output = stdout.read }
        stderr_thread = Thread.new { error_output = stderr.read }
        
        stdout_thread.join
        stderr_thread.join
        
        wait_thr.join
      end
      timed_out = false
    rescue Timeout::Error
      Process.kill("KILL", wait_thr.pid)
      timed_out = true
    end

    {
      name: name,
      code: wait_thr.value.exitstatus,
      signal: nil,
      timed_out: timed_out,
      stdout: output,
      stderr: error_output,
      max_rss_mb: parse_max_rss_mb(error_output)
    }
  end.value
end

def build_import_body(entry_files, label)
  imports = entry_files.map { |file_path| "require #{file_path.inspect}" }.join("\n")
  "#{imports}\nputs #{label.inspect}\nexit(0)\n"
end

def find_extension_entries(repo_root)
  extensions_dir = File.join(repo_root, "dist", "extensions")
  raise "dist/extensions not found. Run pnpm build first." unless Dir.exist?(extensions_dir)

  entries = Dir.children(extensions_dir).map do |dir|
    file = File.join(extensions_dir, dir, "index.js")
    { dir: dir, file: file } if File.exist?(file)
  end.compact.sort_by { |entry| entry[:dir] }

  raise "No built bundled plugin entrypoints found in the dist plugin tree" if entries.empty?
  entries
end

def main
  options = parse_args(ARGV)
  repo_root = Dir.pwd
  all_entries = find_extension_entries(repo_root)
  
  selected_entries = if options[:extensions].empty?
                      all_entries
                    else
                      all_entries.select { |entry| options[:extensions].include?(entry[:dir]) }
                    end

  missing = options[:extensions] - all_entries.map { |entry| entry[:dir] }
  raise "Unknown built extension ids: #{missing.join(', ')}" unless missing.empty?
  raise "No extensions selected for profiling" if selected_entries.empty?

  tmp_home = Dir.mktmpdir("openclaw-extension-memory-")
  hook_path = File.join(tmp_home, "measure-rss.rb")
  json_path = options[:json_path] || File.join(Dir.tmpdir, "openclaw-extension-memory.json")

  File.write(hook_path, <<~HOOK, mode: "w")
    at_exit do
      usage = Process::Status.new($CHILD_STATUS).inspect rescue nil
      if defined?(Process::CLOCK_PROCESS_CPUTIME) || RUBY_PLATFORM.include?('linux')
        rss = `ps -o rss= -p #{$PROCESS_ID}`.to_i rescue 0
        $stderr.puts '#{RSS_MARKER}' + rss.to_s if rss > 0
      end
    end
  HOOK

  env = ENV.to_h.merge({
    "HOME" => tmp_home,
    "USERPROFILE" => tmp_home,
    "XDG_CONFIG_HOME" => File.join(tmp_home, ".config"),
    "XDG_DATA_HOME" => File.join(tmp_home, ".local", "share"),
    "XDG_CACHE_HOME" => File.join(tmp_home, ".cache"),
    "NODE_DISABLE_COMPILE_CACHE" => "1",
    "OPENCLAW_NO_RESPAWN" => "1",
    "TERM" => ENV["TERM"] || "dumb",
    "LANG" => ENV["LANG"] || "C.UTF-8"
  })

  begin
    baseline = run_case(
      repo_root: repo_root,
      env: env,
      hook_path: hook_path,
      name: "baseline",
      body: "exit(0)",
      timeout_ms: options[:timeout_ms]
    )

    combined = if options[:skip_combined]
                 nil
               else
                 run_case(
                   repo_root: repo_root,
                   env: env,
                   hook_path: hook_path,
                   name: "combined",
                   body: build_import_body(selected_entries.map { |entry| entry[:file] }, "IMPORTED_ALL"),
                   timeout_ms: options[:combined_timeout_ms]
                 )
               end

    pending = selected_entries.dup
    results = []

    workers = []
    concurrency = [options[:concurrency], selected_entries.length].min
    concurrency.times do
      workers << Thread.new do
        loop do
          next_entry = nil
          Thread.exclusive do
            break if pending.empty?
            next_entry = pending.shift
          end
          break unless next_entry

          result = run_case(
            repo_root: repo_root,
            env: env,
            hook_path: hook_path,
            name: next_entry[:dir],
            body: build_import_body([next_entry[:file]], "IMPORTED"),
            timeout_ms: options[:timeout_ms]
          )

          status = if result[:timed_out]
                     "timeout"
                   elsif result[:code] == 0
                     "ok"
                   else
                     "fail"
                   end

          delta_from_baseline_mb = if result[:max_rss_mb] && baseline[:max_rss_mb]
                                     result[:max_rss_mb] - baseline[:max_rss_mb]
                                   else
                                     nil
                                   end

          results << {
            dir: next_entry[:dir],
            file: next_entry[:file],
            status: status,
            max_rss_mb: result[:max_rss_mb],
            delta_from_baseline_mb: delta_from_baseline_mb,
            stderr_preview: summarize_stderr(result[:stderr])
          }

          rss = result[:max_rss_mb] ? "#{result[:max_rss_mb].round(1)} MB" : "n/a"
          puts "[extension-memory] #{next_entry[:dir]}: #{status} #{rss}"
        end
      end
    end

    workers.each(&:join)

    results.sort! { |a, b| a[:dir] <=> b[:dir] }
    top = results
           .select { |entry| entry[:status] == "ok" && entry[:delta_from_baseline_mb].is_a?(Numeric) }
           .sort { |a, b| b[:delta_from_baseline_mb] <=> a[:delta_from_baseline_mb] }
           .first(options[:top])

    report = {
      generated_at: Time.now.utc.iso8601,
      repo_root: repo_root,
      selected_extensions: selected_entries.map { |entry| entry[:dir] },
      baseline: {
        status: baseline[:timed_out] ? "timeout" : (baseline[:code] == 0 ? "ok" : "fail"),
        max_rss_mb: baseline[:max_rss_mb]
      },
      combined: combined.nil? ? nil : {
        status: combined[:timed_out] ? "timeout" : (combined[:code] == 0 ? "ok" : "fail"),
        max_rss_mb: combined[:max_rss_mb],
        stderr_preview: summarize_stderr(combined[:stderr], 12)
      },
      counts: {
        total_entries: selected_entries.length,
        ok: results.count { |entry| entry[:status] == "ok" },
        fail: results.count { |entry| entry[:status] == "fail" },
        timeout: results.count { |entry| entry[:status] == "timeout" }
      },
      options: {
        concurrency: options[:concurrency],
        timeout_ms: options[:timeout_ms],
        combined_timeout_ms: options[:combined_timeout_ms],
        skip_combined: options[:skip_combined]
      },
      top_by_delta_mb: top,
      results: results
    }

    File.write(json_path, JSON.pretty_generate(report) + "\n", mode: "w")

    puts "[extension-memory] report: #{json_path}"
    puts JSON.pretty_generate({
      baseline_mb: report[:baseline][:max_rss_mb],
      combined_mb: report[:combined]&.[](:max_rss_mb),
      counts: report[:counts],
      top_by_delta_mb: report[:top_by_delta_mb]
    })
  ensure
    FileUtils.rm_rf(tmp_home)
  end
end

begin
  main
rescue => error
  puts "[extension-memory] #{error.message}"
  exit(1)
end
