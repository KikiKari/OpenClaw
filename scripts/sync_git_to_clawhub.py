#!/usr/bin/env python3
"""Sync die 4 Git-Repos zu ClawHub"""

import sys
import os
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_clawhub, log

# Die 4 Git-Repos die zu ClawHub müssen
git_repos = [
    "abstractions-utils",
    "sub-agents-utils", 
    "multi-nodes-utils",
    "Abstraktionen"
]

# Check if in git/
git_path = "/home/openclaw/.openclaw/workspace/git"
for repo in git_repos:
    if os.path.exists(f"{git_path}/{repo}"):
        log(f"Syncing {repo} from Git to ClawHub...")
        # Rename für sync function
        if repo == "Abstraktionen":
            continue  # Skip - ist kein Skill
        sync_to_clawhub(repo, dry_run=False)
        log(f"✅ {repo} synced to ClawHub")