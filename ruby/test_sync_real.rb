#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "97a7bdec8fd9d756621f56ccb3af3a82e1c59b3cafc8315e69240f75d17e5312", "source_sha256": "f8c56b5aecfa8cd091cc5fe50697c5613148d19f0d4e0eb311bf6d129c600018", "target_language": "ruby"}
# test_sync_real.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
# auch in: OpenClaw@gateway2:scripts/test_sync_real.py
# auch in: workspace@local:scripts/test_sync_real.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Test echte Synchronisation

$LOAD_PATH << '/home/openclaw/.openclaw/workspace/scripts'
require_relative 'sync_clawhub_git'

# Test: db-maintainer ClawHub → Git (ECHT)
puts "=== TEST: db-maintainer sync (REAL) ==="
skill = "db-maintainer"
result = sync_to_git(skill, dry_run: false)
puts "Result: #{result ? 'SUCCESS' : 'FAILED'}"

# Prüfe Ergebnis
target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer"
if File.exist?(target)
  puts "\n✅ Git-Repo erstellt: #{target}"
  Dir.glob("#{target}/**/*", File::FNM_DOTMATCH).sort.each do |path|
    next if File.basename(path) == '.' || File.basename(path) == '..'
    relative_path = path.sub(target, '')
    level = relative_path.count('/')
    indent = ' ' * 2 * (level - 1)
    if File.directory?(path)
      puts "#{indent}#{File.basename(path)}/"
    else
      subindent = ' ' * 2 * level
      puts "#{subindent}#{File.basename(path)}"
    end
  end
end
