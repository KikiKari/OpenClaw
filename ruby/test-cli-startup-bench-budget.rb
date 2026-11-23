#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "73af760c023511374b573fd7bcda056cf2b72058acdc11b60abc1a6aeb998f6f", "source_sha256": "c6c7301dda8709e6c39c53f79a83f8f7938854384f4e21e1114095d876e51a6d", "target_language": "ruby"}
# test-cli-startup-bench-budget.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-cli-startup-bench-budget.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require "json"
require "fileutils"
require "open3"

CLI_STARTUP_BENCH_FIXTURE_PATH = "test/fixtures/cli-startup-bench.json".freeze

def format_ms(value)
  "#{value.round(1)}ms"
end

def format_mb(value)
  "#{value.round(1)}MB"
end

def read_env_number(key)
  value = ENV[key]
  value&.to_f
end

def parse_flag_args(args, defaults, flag_definitions)
  options = defaults.dup

  i = 0
  while i < args.length
    arg = args[i]
    matched = false

    flag_definitions.each do |flag_def|
      if arg == flag_def[:flag]
        matched = true
        value = args[i + 1]
        raise "Missing value for flag #{flag_def[:flag]}" unless value

        parsed_value = case flag_def[:type]
                       when :int
                         val = value.to_i
                         if flag_def[:min] && val < flag_def[:min]
                           raise "Value for #{flag_def[:flag]} must be >= #{flag_def[:min]}"
                         end
                         val
                       when :float
                         val = value.to_f
                         if flag_def[:min] && val < flag_def[:min]
                           raise "Value for #{flag_def[:flag]} must be >= #{flag_def[:min]}"
                         end
                         val
                       when :string
                         value
                       end

        options[flag_def[:key]] = parsed_value
        i += 2
        break
      end
    end

    i += 1 unless matched
  end

  options
end

def string_flag(flag, key)
  { flag: flag, key: key, type: :string }
end

def int_flag(flag, key, constraints = {})
  { flag: flag, key: key, type: :int, min: constraints[:min] }
end

def float_flag(flag, key, constraints = {})
  { flag: flag, key: key, type: :float, min: constraints[:min] }
end

if ARGV.include?("--help")
  puts <<~HELP
    Usage: ruby scripts/test-cli-startup-bench-budget.rb [options]

    Compare current CLI benchmark results against the checked-in fixture.

    Options:
      --baseline <path>             Baseline fixture path
      --report <path>               Reuse an existing current benchmark report
      --entry <path>                CLI entry to benchmark when report is omitted
      --preset <name>               startup | real | all (default: all)
      --runs <n>                    Measured runs per case (default: 1)
      --warmup <n>                  Warmup runs per case (default: 0)
      --timeout-ms <ms>             Per-run timeout (default: 30000)
      --max-duration-regression-pct <n>
                                    Fail if avg duration regresses more than this percent
      --max-rss-regression-pct <n>  Fail if avg RSS regresses more than this percent
      --help                        Show this help text

    Example:
      ruby scripts/test-cli-startup-bench-budget.rb --preset real --max-duration-regression-pct 15
  HELP
  exit(0)
end

defaults = {
  "baseline" => CLI_STARTUP_BENCH_FIXTURE_PATH,
  "report" => "",
  "entry" => "openclaw.mjs",
  "preset" => "all",
  "runs" => 1,
  "warmup" => 0,
  "timeoutMs" => 30_000,
  "maxDurationRegressionPct" => read_env_number("OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT") || 20,
  "maxRssRegressionPct" => read_env_number("OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT") || 20,
}

flag_definitions = [
  string_flag("--baseline", "baseline"),
  string_flag("--report", "report"),
  string_flag("--entry", "entry"),
  string_flag("--preset", "preset"),
  int_flag("--runs", "runs", min: 1),
  int_flag("--warmup", "warmup", min: 0),
  int_flag("--timeout-ms", "timeoutMs", min: 1),
  float_flag("--max-duration-regression-pct", "maxDurationRegressionPct", min: 0),
  float_flag("--max-rss-regression-pct", "maxRssRegressionPct", min: 0),
]

opts = parse_flag_args(ARGV, defaults, flag_definitions)

def read_json_file(path)
  return nil unless File.exist?(path)
  JSON.parse(File.read(path))
rescue => e
  STDERR.puts "Error reading JSON file #{path}: #{e.message}"
  nil
end

def resolve_current_report_path(opts)
  return opts["report"] unless opts["report"].empty?

  report_path = ".artifacts/cli-startup-bench.current.json"
  FileUtils.mkdir_p(".artifacts")

  args = [
    "--import",
    "tsx",
    "scripts/bench-cli-startup.ts",
    "--entry",
    opts["entry"],
    "--preset",
    opts["preset"],
    "--runs",
    opts["runs"].to_s,
    "--warmup",
    opts["warmup"].to_s,
    "--timeout-ms",
    opts["timeoutMs"].to_s,
    "--output",
    report_path,
  ]

  stdin, stdout, stderr, wait_thr = Open3.popen3("node", *args)
  stdin.close
  stdout.close
  stderr.close
  exit_status = wait_thr.value

  unless exit_status.success?
    exit(exit_status.exitstatus || 1)
  end

  report_path
end

def index_cases(report)
  cases = {}
  (report&.dig("primary", "cases") || []).each do |entry|
    cases[entry["id"]] = entry
  end
  cases
end

baseline = read_json_file(opts["baseline"])
current = read_json_file(resolve_current_report_path(opts))
baseline_cases = index_cases(baseline)
current_cases = index_cases(current)

failed = false

baseline_cases.each do |id, baseline_case|
  current_case = current_cases[id]
  if current_case.nil?
    STDERR.puts "[test-cli-startup-bench-budget] missing current case #{id}"
    failed = true
    next
  end

  baseline_duration = baseline_case.dig("summary", "durationMs", "avg")
  current_duration = current_case.dig("summary", "durationMs", "avg")

  if baseline_duration.is_a?(Numeric) && current_duration.is_a?(Numeric) && baseline_duration > 0
    allowed_duration = baseline_duration * (1 + opts["maxDurationRegressionPct"] / 100.0)
    if current_duration > allowed_duration
      STDERR.puts "[test-cli-startup-bench-budget] #{baseline_case['name']} avg duration #{format_ms(current_duration)} exceeded #{format_ms(allowed_duration)} (baseline #{format_ms(baseline_duration)}, +#{opts['maxDurationRegressionPct']}%)."
      failed = true
    end
  end

  baseline_rss = baseline_case.dig("summary", "maxRssMb", "avg")
  current_rss = current_case.dig("summary", "maxRssMb", "avg")

  if baseline_rss.is_a?(Numeric) && current_rss.is_a?(Numeric) && baseline_rss > 0
    allowed_rss = baseline_rss * (1 + opts["maxRssRegressionPct"] / 100.0)
    if current_rss > allowed_rss
      STDERR.puts "[test-cli-startup-bench-budget] #{baseline_case['name']} avg RSS #{format_mb(current_rss)} exceeded #{format_mb(allowed_rss)} (baseline #{format_mb(baseline_rss)}, +#{opts['maxRssRegressionPct']}%)."
      failed = true
    end
  end

  duration_str = current_duration.is_a?(Numeric) ? format_ms(current_duration) : "n/a"
  baseline_duration_str = baseline_duration.is_a?(Numeric) ? format_ms(baseline_duration) : "n/a"
  rss_str = current_rss.is_a?(Numeric) ? format_mb(current_rss) : "n/a"
  baseline_rss_str = baseline_rss.is_a?(Numeric) ? format_mb(baseline_rss) : "n/a"

  puts "[test-cli-startup-bench-budget] #{baseline_case['name']} duration=#{duration_str} baseline=#{baseline_duration_str} rss=#{rss_str} baselineRss=#{baseline_rss_str}"
end

exit(1) if failed
