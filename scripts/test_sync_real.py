#!/usr/bin/env python3
"""Test echte Synchronisation"""

import sys
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git, log

# Test: db-maintainer ClawHub → Git (ECHT)
print("=== TEST: db-maintainer sync (REAL) ===")
skill = "db-maintainer"
result = sync_to_git(skill, dry_run=False)
print(f"Result: {'SUCCESS' if result else 'FAILED'}")

# Prüfe Ergebnis
import os
target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer"
if os.path.exists(target):
    print(f"\n✅ Git-Repo erstellt: {target}")
    for root, dirs, files in os.walk(target):
        level = root.replace(target, '').count(os.sep)
        indent = ' ' * 2 * level
        print(f"{indent}{os.path.basename(root)}/")
        subindent = ' ' * 2 * (level + 1)
        for file in files:
            print(f"{subindent}{file}")