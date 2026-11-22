#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "379d04c0235e0b53157fd895bb84a590a398300696ac9747b6df500ef063fdfb", "source_sha256": "2516612af0a0435eb92af19fa6d322dbf03b3c95168e1f623ea14087f9e79413", "target_language": "ruby"}
# run-vitest.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require 'open3'
require_relative 'pnpm_runner'
require_relative 'vitest_process_group'

TRUTHY_ENV_VALUES = ['1', 'true', 'yes', 'on'].freeze
SUPPRESSED_VITEST_STDERR_PATTERNS = ['[PLUGIN_TIMINGS] Warning:'].freeze

def is_truthy_env_value(value)
  TRUTHY_ENV_VALUES.include?(value&.strip&.downcase)
end

def resolve_vitest_node_args(env = ENV)
  if is_truthy_env_value(env['OPENCLAW_VITEST_ENABLE_MAGLEV'])
    []
  else
    ['--no-maglev']
  end
end

def resolve_vitest_cli_entry
  vitest_package_json = Gem::Specification.find_by_name('vitest').gem_dir
  File.join(vitest_package_json, 'vitest.mjs')
rescue Gem::LoadError
  # fallback to node resolution if gem not found
  vitest_path = `node -p "require.resolve('vitest/package.json')"`.strip
  File.join(File.dirname(vitest_path), 'vitest.mjs')
end

def resolve_vitest_spawn_params(env = ENV, platform = RUBY_PLATFORM)
  {
    env: env.to_h,
    detached: should_use_detached_vitest_process_group(platform),
    pgroup: true
  }
end

def should_suppress_vitest_stderr_line(line)
  SUPPRESSED_VITEST_STDERR_PATTERNS.any? { |pattern| line.include?(pattern) }
end

def forward_vitest_output(stream, target, suppress_predicate = nil)
  return unless stream

  Thread.new do
    buffer = ''
    stream.each_char do |char|
      if char == "\n"
        line = buffer + char
        buffer = ''
        next if suppress_predicate&.call(line)
        target.print line
        target.flush
      else
        buffer += char
      end
    end
    
    # Handle remaining buffer
    unless buffer.empty?
      unless suppress_predicate&.call(buffer)
        target.print buffer
        target.flush
      end
    end
  end
end

def main(argv = ARGV, env = ENV)
  if argv.empty?
    STDERR.puts 'usage: ruby run-vitest.rb <vitest args...>'
    exit 1
  end

  spawn_params = resolve_vitest_spawn_params(env)
  
  vitest_node_args = resolve_vitest_node_args(env)
  vitest_cli_entry = resolve_vitest_cli_entry
  
  pnpm_args = ['exec', 'node'] + vitest_node_args + [vitest_cli_entry] + argv
  
  child_pid, child_stdin, child_stdout, child_stderr = spawn_pnpm_runner(
    pnpm_args: pnpm_args,
    **spawn_params
  )
  
  teardown_child_cleanup = install_vitest_process_group_cleanup(child_pid: child_pid)
  
  forward_vitest_output(child_stdout, STDOUT)
  forward_vitest_output(child_stderr, STDERR, ->(line) { should_suppress_vitest_stderr_line(line) })
  
  begin
    Process.wait(child_pid)
    exit_status = $?.exitstatus
    teardown_child_cleanup.call
    exit exit_status
  rescue => e
    teardown_child_cleanup.call
    STDERR.puts e.message
    exit 1
  end
end

if __FILE__ == $0
  main
end
