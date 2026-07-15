#!/usr/bin/env python3
"""Backup docs.db and tree.db with timestamp into /workspace/db/backups"""
import os, shutil, datetime
workspace = os.getenv('OPENCLAW_WORKSPACE', '/workspace')
backup_dir = os.path.join(workspace, 'db', 'backups')
# Ensure backup_dir exists
os.makedirs(backup_dir, exist_ok=True)
timestamp = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M')
for db_name in ['docs.db', 'tree.db']:
    src = os.path.join(workspace, db_name)
    if os.path.isfile(src):
        dest = os.path.join(backup_dir, f"{timestamp}_{db_name}.bak")
        shutil.copy2(src, dest)
        print(f"Backup created: {dest}")
    else:
        print(f"Source db not found: {src}")
