#!/usr/bin/env python3
"""Test für Sync-Script"""

import sys
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git, log

# Test: db-maintainer ClawHub → Git (DRY-RUN)
print("=== TEST: db-maintainer sync (DRY-RUN) ===")
skill = "db-maintainer"
result = sync_to_git(skill, dry_run=True)
print(f"Result: {'SUCCESS' if result else 'FAILED'}")
print("\n=== LOG-Inhalt ===")
with open("/home/openclaw/.openclaw/workspace/logs/sync.log", "r") as f:
    print(f.read())