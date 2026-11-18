#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "dd9685b832cc818c4cf1d9db8136911db8c88f0aeed3fb91697022778e574f1b", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "ruby"}
# pplx-status.sh — portiert nach ruby
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Quick status of the codespace Perplexity daemon session.
require 'json'
require 'fileutils'

cfg = ENV['PERPLEXITY_CONFIG_DIR'] || "#{ENV['HOME']}/.perplexity-mcp"
profile = ENV['PERPLEXITY_PROFILE'] || 'codespace'
stat = "#{cfg}/profiles/#{profile}/daemon-status.json"

if File.exist?(stat)
  puts JSON.pretty_generate(JSON.parse(File.read(stat)))
else
  puts "no daemon-status.json at #{stat}"
end

puts "--- recent auth lines ---"
begin
  log_file = "#{cfg}/daemon.log"
  if File.exist?(log_file)
    lines = File.readlines(log_file).select { |line| 
      line.match?(/Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in/i)
    }
    puts lines.last(6)
  end
rescue => e
  # ignore errors like grep -v would
end
