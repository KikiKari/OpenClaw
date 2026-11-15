#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "d6efb8090e7fb5af429f45c4df9c1ca10d0fc0c10aa154f5bbf8f52066528595", "source_sha256": "f0a06da41ce49899ff38006fbb000208dc616b2b3aa7114e02d1872712549a43", "target_language": "shell"}
# run_sync_agent.py — portiert nach shell
# Quelle: python, gateway-workspace
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# Shell launcher for the Python sync agent in its container workspace.
exec python3 -c '
import sys

src = "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py"
sys.path.insert(0, "/workspace/scripts")
with open(src) as stream:
    code = stream.read().replace("/home/openclaw/.openclaw/workspace", "/workspace")
sys.argv = [src] + sys.argv[1:]
exec(compile(code, src, "exec"), {"__name__": "__main__", "__file__": src})
' "$@"
