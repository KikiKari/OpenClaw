#!/usr/bin/env python3
"""Sync die aktiven Skill-Repositories zu ClawHub."""

import sys
import os
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_clawhub, log

# Nur aktive Skill-Repositories synchronisieren.
git_repos = [
    "sub-agents-utils",
    "multi-nodes-utils",
]

# Check if in git/
git_path = "/home/openclaw/.openclaw/workspace/git"
for repo in git_repos:
    if os.path.exists(f"{git_path}/{repo}"):
        log(f"Syncing {repo} from Git to ClawHub...")
        sync_to_clawhub(repo, dry_run=False)
        log(f"✅ {repo} synced to ClawHub")
