#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "15f77006d6bb218fe3cab20403f041fe3ca5cd9c1d3ae69b2b317c4786fca2f0", "source_sha256": "f0a06da41ce49899ff38006fbb000208dc616b2b3aa7114e02d1872712549a43", "target_language": "ruby"}
# run_sync_agent.py — portiert nach ruby
# Quelle: python, gateway-workspace
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# The downstream sync agent is Python; preserve its source path and arguments.
launcher = <<~PYTHON
  import sys
  src = "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py"
  sys.path.insert(0, "/workspace/scripts")
  with open(src) as stream:
      code = stream.read().replace("/home/openclaw/.openclaw/workspace", "/workspace")
  sys.argv = [src] + sys.argv[1:]
  exec(compile(code, src, "exec"), {"__name__": "__main__", "__file__": src})
PYTHON

exec('python3', '-c', launcher, *ARGV)
