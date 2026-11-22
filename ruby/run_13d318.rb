#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "71d8b27909f4526b1ba3015b3b2ddf11a845fc2ebc198d5b1e7dcdbf2962b5c9", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "ruby"}
# run.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'open3'

Dir.chdir('/repo')

ENV['OPENCLAW_STATE_DIR'] = '/tmp/openclaw-test'
ENV['OPENCLAW_CONFIG_PATH'] = "#{ENV['OPENCLAW_STATE_DIR']}/openclaw.json"

puts '==> Build'
stdout, stderr, status = Open3.capture3('pnpm build')
unless status.success?
  puts stdout
  puts stderr
  exit 1
end

puts '==> Seed state'
FileUtils.mkdir_p("#{ENV['OPENCLAW_STATE_DIR']}/credentials")
FileUtils.mkdir_p("#{ENV['OPENCLAW_STATE_DIR']}/agents/main/sessions")
File.write(ENV['OPENCLAW_CONFIG_PATH'], '{}')
File.write("#{ENV['OPENCLAW_STATE_DIR']}/credentials/marker.txt", 'creds')
File.write("#{ENV['OPENCLAW_STATE_DIR']}/agents/main/sessions/sessions.json", 'session')

puts '==> Reset (config+creds+sessions)'
stdout, stderr, status = Open3.capture3('pnpm openclaw reset --scope config+creds+sessions --yes --non-interactive')
unless status.success?
  puts stdout
  puts stderr
  exit 1
end

raise "Config file still exists: #{ENV['OPENCLAW_CONFIG_PATH']}" if File.exist?(ENV['OPENCLAW_CONFIG_PATH'])
raise "Credentials directory still exists: #{ENV['OPENCLAW_STATE_DIR']}/credentials" if Dir.exist?("#{ENV['OPENCLAW_STATE_DIR']}/credentials")
raise "Sessions directory still exists: #{ENV['OPENCLAW_STATE_DIR']}/agents/main/sessions" if Dir.exist?("#{ENV['OPENCLAW_STATE_DIR']}/agents/main/sessions")

puts '==> Recreate minimal config'
FileUtils.mkdir_p("#{ENV['OPENCLAW_STATE_DIR']}/credentials")
File.write(ENV['OPENCLAW_CONFIG_PATH'], '{}')

puts '==> Uninstall (state only)'
stdout, stderr, status = Open3.capture3('pnpm openclaw uninstall --state --yes --non-interactive')
unless status.success?
  puts stdout
  puts stderr
  exit 1
end

raise "State directory still exists: #{ENV['OPENCLAW_STATE_DIR']}" if Dir.exist?(ENV['OPENCLAW_STATE_DIR'])

puts 'OK'
