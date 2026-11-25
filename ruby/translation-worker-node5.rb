#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "7b028485e4f08d184a7d5fdf506e9dedbd2a822f2e2836ec1028eccc83770b3d", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "ruby"}
# translation-worker-node5.ps1 — portiert nach ruby
# Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Parameter validation
action = ARGV[0]
if action.nil? || (action != 'prepare' && action != 'run')
  STDERR.puts "Error: Invalid action. Must be 'prepare' or 'run'"
  exit 1
end

# Windows does not use chmod. The Python worker and Python 3 must already be
# installed locally; no credentials are copied or placed on a command line.

# Build worker path using USERPROFILE environment variable
user_profile = ENV['USERPROFILE']
worker = File.join(user_profile, '.openclaw', 'workers', 'translation_worker.py')

expected = '9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b'

# Check if worker file exists
unless File.file?(worker)
  STDERR.puts "Worker missing: #{worker}"
  exit 1
end

# Check if it's a symlink (reparse point equivalent)
if File.symlink?(worker)
  STDERR.puts 'Worker link rejected'
  exit 1
end

# Calculate SHA256 hash of the worker file
require 'digest'
actual_hash = Digest::SHA256.file(worker).hexdigest

# Compare with expected hash
if actual_hash != expected
  STDERR.puts 'Worker checksum mismatch'
  exit 1
end

# Find python executable
python_exe = `where python.exe`.split("\n").first.strip
if python_exe.nil? || python_exe.empty?
  STDERR.puts "Python executable not found"
  exit 1
end

if action == 'prepare'
  puts "Worker verified: #{worker}"
  exit 0
end

# Execute the worker script
exec(python_exe, worker)
