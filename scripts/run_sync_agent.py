#!/usr/bin/env python3
"""Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace."""
import sys
from pathlib import Path

sys.path.insert(0, "/workspace/scripts")
sys.path.insert(0, "/workspace/skills/clawhub-git-sync-agent/scripts")

import sync_agent

WS = Path("/workspace")
sync_agent.CLAWHUB_DIR = WS / "skills"
sync_agent.GIT_DIR = WS / "git" / "skills"
sync_agent.STATE_FILE = WS / "db" / "sync_state.json"

if __name__ == "__main__":
    sync_agent.main()
