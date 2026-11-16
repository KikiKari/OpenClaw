#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ef8bca8e2348f37356298ac536cd770234e72a9b44ef37586fc2998f9b3f9bc7", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "ruby"}
# build-and-run-mac.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'

# Change to the correct directory
Dir.chdir(File.join(File.dirname(__FILE__), '../apps/macos'))

BUILD_PATH = '.build-local'
PRODUCT = 'OpenClaw'
BIN = File.join(BUILD_PATH, 'debug', PRODUCT)

puts "\n▶️  Building #{PRODUCT} (debug, build path: #{BUILD_PATH})"
system("swift build -c debug --product \"#{PRODUCT}\" --build-path \"#{BUILD_PATH}\"") or raise 'Build failed'

puts "\n⏹  Stopping existing #{PRODUCT}..."
system("killall -q \"#{PRODUCT}\" 2>/dev/null")

puts "\n🚀 Launching #{BIN} ..."
pid = Process.spawn("\"#{BIN}\"", out: '/tmp/openclaw.log', err: '/tmp/openclaw.log')
Process.detach(pid)
puts "Started #{PRODUCT} (PID #{pid}). Logs: /tmp/openclaw.log"
