#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "bf9018cd05928a02a4e11471df4bab8d53993200ac2f9c96d38aaf03ec2f8b85", "source_sha256": "daf78be577ece366a1908ac16ff31d6e57298b1256bb88185a5bc1cf5294a804", "target_language": "ruby"}
# test_sync.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:scripts/test_sync.py
# auch in: OpenClaw@gateway2:scripts/test_sync.py
# auch in: workspace@local:scripts/test_sync.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Test für Sync-Script

$LOAD_PATH << '/home/openclaw/.openclaw/workspace/scripts'
require './sync_clawhub_git'

# Test: db-maintainer ClawHub → Git (DRY-RUN)
puts "=== TEST: db-maintainer sync (DRY-RUN) ==="
skill = "db-maintainer"
result = sync_to_git(skill, dry_run: true)
puts "Result: #{result ? 'SUCCESS' : 'FAILED'}"
puts "\n=== LOG-Inhalt ==="
File.open("/home/openclaw/.openclaw/workspace/logs/sync.log", "r") do |f|
  puts f.read
end
