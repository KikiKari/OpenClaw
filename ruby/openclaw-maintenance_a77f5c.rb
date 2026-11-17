#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d23b2dd0a51715190c550633ed473cc3035a908c4ed13e453719840089105267", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "ruby"}
# openclaw-maintenance.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'fileutils'

OPENCLAW_BIN = ENV.fetch('OPENCLAW_BIN', File.join(Dir.home, '.local', 'bin', 'openclaw'))

unless File.executable?(OPENCLAW_BIN)
  STDERR.puts "ERROR: OpenClaw binary not found: #{OPENCLAW_BIN}"
  exit 1
end

def run_command(cmd)
  puts "Running: #{cmd.join(' ')}"
  system(*cmd)
  raise "Command failed: #{cmd.join(' ')}" unless $?.success?
end

begin
  # Show version
  puts "Using OpenClaw: #{`#{OPENCLAW_BIN} --version`.strip}"

  # === 1. Service-/Config-Drift ===
  run_command([OPENCLAW_BIN, 'doctor'])

  # === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
  run_command([OPENCLAW_BIN, 'plugins', 'registry', '--refresh'])
  
  if ENV.fetch('RUN_PLUGIN_UPDATE', '0') == '1'
    run_command([OPENCLAW_BIN, 'plugins', 'update', '--all'])
  else
    puts "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable."
  end

  # === 3. Tasks ===
  run_command([OPENCLAW_BIN, 'tasks', 'maintenance', '--apply'])

  # === 4. Sessions – alle Agents auf einmal ===
  run_command([OPENCLAW_BIN, 'sessions', 'cleanup', '--enforce', '--all-agents'])

  # === 5. Memory – status/index decken alle Agents ab ===
  run_command([OPENCLAW_BIN, 'memory', 'status', '--deep', '--fix'])
  run_command([OPENCLAW_BIN, 'memory', 'index', '--force'])

  # === 6. Memory promote – MUSS pro Agent ===
  %w[main knecht docs ops-hub cron].each do |agent|
    run_command([OPENCLAW_BIN, 'memory', 'promote', '--apply', '--agent', agent])
  end

  # === 7. Secrets ===
  run_command([OPENCLAW_BIN, 'secrets', 'reload'])

rescue => e
  STDERR.puts "Error: #{e.message}"
  exit 1
end
