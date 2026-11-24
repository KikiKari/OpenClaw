#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "53007ecde743ebc1effe724886b0ae7ba47db4ceff1ccc018b16b6a83561e3bb", "source_sha256": "4252ea2457fcacdde20bb203479a1fcfbb9fa70ecf111838b7f2ac7c0902a093", "target_language": "ruby"}
# test-hotspots.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-hotspots.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

require_relative './lib/vitest-report-cli-utils'
require_relative './test-report-utils'

if ARGV.include?('--help')
  puts [
    "Usage: ruby scripts/test-hotspots.rb [options]",
    "",
    "Print the slowest test files from a Vitest JSON report.",
    "",
    "Options:",
    "  --config <path>    Vitest config to run when no report is supplied",
    "  --report <path>    Reuse an existing Vitest JSON report",
    "  --limit <count>    Number of files to print (default: 20)",
    "  --help             Show this help text",
    "",
    "Examples:",
    "  ruby scripts/test-hotspots.rb",
    "  ruby scripts/test-hotspots.rb --config test/vitest/vitest.channels.config.ts --limit 10",
    "  ruby scripts/test-hotspots.rb --report /tmp/vitest-report.json",
  ].join("\n")
  exit(0)
end

opts = parse_vitest_report_args(ARGV, {
  'config' => 'test/vitest/vitest.unit.config.ts',
  'limit' => 20
})
report = load_vitest_report_from_args(opts, 'openclaw-vitest-hotspots')
file_results = collect_vitest_file_durations(report).sort_by { |item| -item[:duration_ms] }

top = file_results[0, opts['limit']]
total_duration_ms = file_results.sum { |item| item[:duration_ms] }
puts "\n[test-hotspots] top #{top.size} by file duration (#{format_ms(total_duration_ms)} total)"

top.each_with_index do |item, index|
  label = (index + 1).to_s.rjust(2, ' ')
  duration = format_ms(item[:duration_ms]).rjust(10, ' ')
  tests = item[:test_count].to_s.rjust(4, ' ')
  puts "#{label}. #{duration} | tests=#{tests} | #{item[:file]}"
end
