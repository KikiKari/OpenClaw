#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "140b55d201989e441ae3115d42cf76e175276fd6410e3044eaa49133a2acc66f", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "ruby"}
# run_sync_agent.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.
require 'pathname'

$LOAD_PATH.unshift("/workspace/scripts")
$LOAD_PATH.unshift("/workspace/skills/clawhub-git-sync-agent/scripts")

require 'sync_agent'

WS = Pathname.new("/workspace")
sync_agent::CLAWHUB_DIR = WS + "skills"
sync_agent::GIT_DIR = WS + "git" + "skills"
sync_agent::STATE_FILE = WS + "db" + "sync_state.json"

if __FILE__ == $0
  sync_agent.main()
end
