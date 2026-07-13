#!/usr/bin/env python3
"""
Database Maintainer Script (adapted for sandbox workspace).
Runs periodic maintenance: tree export, docs.db and tree.db updates, backups, cleanup.
"""

import os
import sys
import json
import hashlib
import sqlite3
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from shutil import copy2

# Define workspace base (sandbox path)
WORKSPACE = Path(os.getenv('OPENCLAW_WORKSPACE', '/workspace'))
DB_DIR = WORKSPACE / "db"
BACKUP_DIR = DB_DIR / "backups"
LOG_DIR = WORKSPACE / "logs" / "db-maintainer"
IMPORTANT_DIR = WORKSPACE / "important"

# Ensure directories exist
try:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
except Exception as e:
    print(f"[ERROR] Unable to create directories: {e}", file=sys.stderr)
    sys.exit(1)

class Logger:
    def __init__(self):
        today = datetime.now().strftime('%Y-%m-%d')
        self.log_file = LOG_DIR / f"{today}.log"
    def log(self, level, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        line = f"[{timestamp}] [{level}] {message}"
        print(line)
        try:
            with open(self.log_file, 'a') as f:
                f.write(line + '\n')
        except Exception:
            pass
    def info(self, msg): self.log('INFO', msg)
    def warn(self, msg): self.log('WARN', msg)
    def error(self, msg): self.log('ERROR', msg)

logger = Logger()

# Helper functions

def get_file_hash(filepath):
    try:
        with open(filepath, 'rb') as f:
            return hashlib.md5(f.read()).hexdigest()
    except Exception:
        return None

def run_tree_command():
    # Try to run 'tree' if available; otherwise fallback to 'find' limited depth.
    try:
        result = subprocess.run(['tree', '-a', '-L', '8', str(WORKSPACE)], capture_output=True, text=True, timeout=60)
        if result.returncode == 0:
            logger.info('tree command succeeded')
            return result.stdout
        else:
            logger.warn(f'tree command failed: {result.stderr.strip()}')
    except Exception as e:
        logger.warn(f'tree command exception: {e}')
    # Fallback using find (depth 8)
    try:
        result = subprocess.run(['find', str(WORKSPACE), '-maxdepth', '8', '-printf', "%p\n"], capture_output=True, text=True, timeout=60)
        if result.returncode == 0:
            logger.info('find fallback succeeded')
            return result.stdout
        else:
            logger.error(f'find fallback failed: {result.stderr.strip()}')
    except Exception as e:
        logger.error(f'find fallback exception: {e}')
    return None

def update_tree_file(tree_output):
    if not tree_output:
        return False
    tree_file = IMPORTANT_DIR / "openclaw-tree.txt"
    header = f"# OpenClaw Workspace Tree\n# Generated: {datetime.now().isoformat()}\n# Command: tree -a -L 8 {WORKSPACE}\n# Auto-updated by db maintainer\n\n"
    try:
        with open(tree_file, 'w') as f:
            f.write(header)
            f.write(tree_output)
        logger.info(f'Updated tree file at {tree_file}')
        return True
    except Exception as e:
        logger.error(f'Failed to write tree file: {e}')
        return False

def scan_documentations():
    docs = []
    for pattern in ['*.md', '**/*.md']:
        for md_file in WORKSPACE.glob(pattern):
            if md_file.is_file() and not md_file.is_symlink():
                if 'db/backups' in str(md_file) or 'node_modules' in str(md_file):
                    continue
                docs.append({
                    'path': str(md_file.relative_to(WORKSPACE)),
                    'hash': get_file_hash(md_file),
                    'mtime': md_file.stat().st_mtime
                })
    return docs

def load_state():
    state_file = DB_DIR / "maintainer_state.json"
    if state_file.exists():
        try:
            return json.load(open(state_file, 'r'))
        except Exception:
            return {}
    return {'last_check': None, 'last_backup': None, 'last_tree_update': None, 'file_hashes': {}}

def save_state(state):
    state_file = DB_DIR / "maintainer_state.json"
    try:
        with open(state_file, 'w') as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        logger.error(f'Could not save state: {e}')

def check_for_changes(state):
    current_docs = scan_documentations()
    changes = []
    current_hashes = {}
    for doc in current_docs:
        path = doc['path']
        current_hashes[path] = doc['hash']
        if path not in state.get('file_hashes', {}):
            changes.append(f"NEW: {path}")
        elif state['file_hashes'][path] != doc['hash']:
            changes.append(f"CHANGED: {path}")
    for old_path in state.get('file_hashes', {}):
        if old_path not in current_hashes:
            changes.append(f"DELETED: {old_path}")
    return changes, current_hashes

def run_update_docs_db():
    script_path = str(Path('/workspace/scripts/update_docs_db.py').resolve())
    try:
        result = subprocess.run(['python3', script_path], capture_output=True, text=True, timeout=120)
        if result.returncode == 0:
            logger.info('update_docs_db succeeded')
            return True
        else:
            logger.error(f'update_docs_db failed: {result.stderr.strip()}')
            return False
    except Exception as e:
        logger.error(f'Exception running update_docs_db: {e}')
        return False

def run_tree_indexer_v2():
    script_path = str(Path('/workspace/scripts/tree_indexer_v2.py').resolve())
    try:
        result = subprocess.run(['python3', script_path], capture_output=True, text=True, timeout=180)
        if result.returncode == 0:
            logger.info('tree_indexer_v2 succeeded')
            return True
        else:
            logger.error(f'tree_indexer_v2 failed: {result.stderr.strip()}')
            return False
    except Exception as e:
        logger.error(f'Exception running tree_indexer_v2: {e}')
        return False

def create_backup():
    timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M')
    for db_name in ['docs.db', 'tree.db']:
        src = DB_DIR / db_name
        if src.exists():
            bak_name = f"{timestamp}_{db_name}.bak"
            dst = BACKUP_DIR / bak_name
            try:
                copy2(src, dst)
                logger.info(f'Backup created: {bak_name}')
            except Exception as e:
                logger.error(f'Failed to backup {db_name}: {e}')
    return timestamp

def cleanup_old_backups():
    cutoff = datetime.now() - timedelta(days=3)
    deleted = 0
    for db_name in ['docs.db', 'tree.db']:
        for backup in BACKUP_DIR.glob(f"*_{{db_name}}.bak"):
            # backup name format: YYYY-MM-DD_HH-MM_<db>.bak
            try:
                parts = backup.name.split('_')
                date_part = parts[0]
                time_part = parts[1]
                dt = datetime.strptime(f"{date_part}_{time_part}", "%Y-%m-%d_%H-%M")
                if dt < cutoff:
                    backup.unlink()
                    deleted += 1
                    logger.info(f'Deleted old backup {backup.name}')
            except Exception:
                logger.warn(f'Could not parse backup name {backup.name}')
    if deleted == 0:
        logger.info('No old backups to delete')
    else:
        logger.info(f'Deleted {deleted} old backups')

def main():
    logger.info('=== DB MAINTAINER START ===')
    state = load_state()
    # Tree export
    tree_out = run_tree_command()
    if tree_out:
        update_tree_file(tree_out)
        state['last_tree_update'] = datetime.now().isoformat()
    # Update tree.db
    run_tree_indexer_v2()
    # Check doc changes
    changes, cur_hashes = check_for_changes(state)
    if changes:
        logger.info(f'Found {len(changes)} changes')
        for c in changes[:10]:
            logger.info(f'  - {c}')
        if len(changes) > 10:
            logger.info(f'  ... and {len(changes)-10} more')
        # Update docs.db
        if run_update_docs_db():
            state['last_check'] = datetime.now().isoformat()
            state['file_hashes'] = cur_hashes
    else:
        logger.info('No documentation changes detected')
    # Backup if needed (hourly)
    do_backup = True
    last_backup = state.get('last_backup')
    if last_backup:
        try:
            last_dt = datetime.fromisoformat(last_backup)
            if datetime.now() - last_dt < timedelta(hours=1):
                do_backup = False
        except Exception:
            pass
    if do_backup:
        logger.info('Creating hourly backup')
        create_backup()
        state['last_backup'] = datetime.now().isoformat()
        cleanup_old_backups()
    else:
        logger.info('Backup not required at this time')
    save_state(state)
    logger.info('=== DB MAINTAINER END ===')

if __name__ == '__main__':
    main()
