#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "06316e9308f61f54dc38ea5238c8693bb8eab0114ba9325debbed3efeb5d4fb3", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "ruby"}
# pplx-setup.sh — portiert nach ruby
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.

require 'open3'
require 'fileutils'

def run_command(cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  unless status.success?
    raise "Command failed: #{cmd}\n#{stderr}"
  end
  stdout.strip
rescue StandardError => e
  nil
end

# Find the latest perplexity extension patchright directory
extpr_candidates = Dir.glob(File.join(ENV['HOME'], '.vscode-remote', 'extensions', 'nskha.perplexity-vscode-*', 'dist', 'node_modules', 'patchright'))
extpr = extpr_candidates.sort_by { |path| path.split('-').last.to_i }.last

unless extpr
  puts "[setup] extension patchright not found — is the Perplexity extension installed?"
  exit 0
end

# Get expected chromium executable path
exp = run_command("node -e \"const {chromium}=require('#{extpr}');console.log(chromium.executablePath())\"")

if exp && File.exist?(exp) && File.executable?(exp)
  puts "[setup] daemon browser already present: #{exp}"
  exit 0
end

puts "[setup] installing matching chromium for the extension daemon (expected: #{exp || 'unknown'})..."
system("node", "#{extpr}/cli.js", "install", "chromium")
puts "[setup] done."
