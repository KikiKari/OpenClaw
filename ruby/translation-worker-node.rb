#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a58e92db0807d70c9b2602cb46af71d291ce8de0e94b0c61ea0aa225f1e5c652", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "ruby"}
# translation-worker-node.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Run on the selected node after transferring its native worker. JSON stdin is
# forwarded unchanged to the worker in run mode.
require 'digest'
require 'json'

def usage
  $stderr.puts 'Usage: translation-worker-node.rb node2|node3|node4|node6 prepare|health|run'
  exit 2
end

usage unless ARGV.length == 2

node = ARGV[0]
action = ARGV[1]

case node
when 'node2'
  worker = '/home/node/.openclaw/workers/translation-worker'
  expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286'
when 'node3'
  worker = '/home/openclaw/.openclaw/workers/translation-worker'
  expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de'
when 'node4'
  worker = '/root/.openclaw/workers/translation-worker'
  expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286'
when 'node6'
  worker = '/home/node/.openclaw/workers/translation-worker'
  expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de'
else
  $stderr.puts 'Unknown or non-POSIX node'
  exit 2
end

unless ['prepare', 'health', 'run'].include?(action)
  $stderr.puts 'Unknown action'
  exit 2
end

unless File.file?(worker) && !File.symlink?(worker)
  $stderr.puts "Missing worker or symlink rejected: #{worker}"
  exit 1
end

actual = Digest::SHA256.file(worker).hexdigest
unless actual == expected
  $stderr.puts "Worker checksum mismatch: #{worker}"
  exit 1
end

File.chmod(0755, worker)

case action
when 'prepare'
  puts "Worker verified and executable: #{worker}"
when 'health'
  exec(worker, '--health')
when 'run'
  exec(worker)
end
