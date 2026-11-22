#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f0c23d83232263c8c4076e2c9869e07cd584d8435cc60d91737c34494d74616c", "source_sha256": "047c165dbfdfa71d13cb6cf0b23d2b60439a2e0ec23e6951411b25fd91c6dcab", "target_language": "ruby"}
# run-vitest-profile.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest-profile.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'tmpdir'
require 'pathname'
require 'open3'

# Helper method to format error messages
def format_error_message(error)
  # Simple implementation - in real scenario, you might want more sophisticated formatting
  error.message
end

def parse_args(argv)
  args = {
    mode: "",
    output_dir: ENV['OPENCLAW_VITEST_PROFILE_DIR']&.strip || ""
  }

  i = 0
  while i < argv.length
    arg = argv[i]
    if arg == "--output-dir"
      args[:output_dir] = argv[i + 1] || ""
      i += 1
    elsif args[:mode].empty?
      args[:mode] = arg
    else
      raise "Unknown argument: #{arg}"
    end
    i += 1
  end

  unless ['main', 'runner'].include?(args[:mode])
    raise "Usage: ruby run-vitest-profile.rb <main|runner> [--output-dir <dir>]"
  end

  args
end

def resolve_vitest_profile_dir(mode:, output_dir:)
  if output_dir && !output_dir.strip.empty?
    return Pathname.new(output_dir).expand_path.to_s
  end

  Dir.mktmpdir("openclaw-vitest-#{mode}-profile-")
end

def build_vitest_profile_command(mode:, output_dir:)
  if mode == "main"
    {
      command: RbConfig.ruby,
      args: [
        "--cpu-prof",
        "--cpu-prof-dir=#{output_dir}",
        "./node_modules/vitest/vitest.mjs",
        "run",
        "--config",
        "test/vitest/vitest.unit.config.ts",
        "--no-file-parallelism"
      ]
    }
  else
    {
      command: "pnpm",
      args: [
        "vitest",
        "run",
        "--config",
        "test/vitest/vitest.unit.config.ts",
        "--no-file-parallelism",
        "--execArgv=--cpu-prof",
        "--execArgv=--cpu-prof-dir=#{output_dir}",
        "--execArgv=--heap-prof",
        "--execArgv=--heap-prof-dir=#{output_dir}"
      ]
    }
  end
end

def main
  parsed = parse_args(ARGV)
  output_dir = resolve_vitest_profile_dir(mode: parsed[:mode], output_dir: parsed[:output_dir])
  FileUtils.mkdir_p(output_dir)

  plan = build_vitest_profile_command(mode: parsed[:mode], output_dir: output_dir)

  puts "[run-vitest-profile] writing #{parsed[:mode]} profiles to #{output_dir}"

  # For Windows compatibility with pnpm
  shell = Gem.win_platform? && plan[:command] == "pnpm"

  Open3.popen3(plan[:command], *plan[:args]) do |stdin, stdout, stderr, wait_thr|
    # Inherit stdio by connecting to current process streams
    stdin.close
    
    # Forward output streams
    threads = []
    threads << Thread.new do
      stdout.each_line { |line| puts line }
    end if stdout
    
    threads << Thread.new do
      stderr.each_line { |line| $stderr.puts line }
    end if stderr
    
    threads.each(&:join)
    
    exit_status = wait_thr.value.exitstatus
    exit(exit_status || 1)
  end
rescue => error
  puts format_error_message(error)
  exit(1)
end

# Check if this script is being run directly
if __FILE__ == $0
  main
end
