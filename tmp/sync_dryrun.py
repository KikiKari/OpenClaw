#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git, sync_to_clawhub

CLAWHUB_DIR = Path('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Path('/home/openclaw/.openclaw/workspace/git/skills')

def get_all_skills():
    clawhub = {d.name for d in CLAWHUB_DIR.iterdir() if d.is_dir() and not d.name.startswith('.')}
    git = {d.name for d in GIT_DIR.iterdir() if d.is_dir() and not d.name.startswith('.')}
    return clawhub.union(git)

for skill in sorted(get_all_skills()):
    sync_to_git(skill, dry_run=True)
    sync_to_clawhub(skill, dry_run=True)
