#!/usr/bin/env python3
"""
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
executes tree command and updates important/openclaw-tree.txt
"""

import sqlite3
import hashlib
import json
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from shutil import copy2
import sys

# Adjusted workspace path for sandbox environment
WORKSPACE = Path("/workspace")
DB_DIR = WORKSPACE / "db"
BACKUP_DIR = DB_DIR / "backups"
LOG_DIR = WORKSPACE / "logs" / "db-maintainer"
IMPORTANT_DIR = WORKSPACE / "important"

# Ensure directories exist
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
IMPORTANT_DIR.mkdir(parents=True, exist_ok=True)

class Logger:
    """Simple logger that writes to a daily log file and prints to stdout"""
    def __init__(self):
        today = datetime.now().strftime('%Y-%m-%d')
        self.log_file = LOG_DIR / f"{today}.log"
    def log(self, level, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        line = f"[{timestamp}] [{level}] {message}"
        print(line)
        with open(self.log_file, 'a') as f:
            f.write(line + '\n')
    def info(self, msg): self.log('INFO', msg)
    def warn(self, msg): self.log('WARN', msg)
    def error(self, msg): self.log('ERROR', msg)

class DatabaseMaintainer:
    def __init__(self):
        self.logger = Logger()
        self.state_file = DB_DIR / "maintainer_state.json"
        self.retention_days = 3
    def load_state(self):
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                return json.load(f)
        return {'last_check': None, 'last_backup': None, 'last_tree_update': None, 'file_hashes': {}}
    def save_state(self, state):
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)
    def get_file_hash(self, filepath):
        try:
            with open(filepath, 'rb') as f:
                return hashlib.md5(f.read()).hexdigest()
        except Exception:
            return None
    def run_tree_command(self):
        try:
            result = subprocess.run(
                ['tree', '-a', '-L', '8', str(WORKSPACE)],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                self.logger.info('tree -a -L 8 executed successfully')
                return result.stdout
            else:
                self.logger.error(f'tree command failed: {result.stderr}')
                return None
        except Exception as e:
            self.logger.error(f'tree command exception: {e}')
            return None
    def update_tree_file(self, tree_output):
        if not tree_output:
            return False
        tree_file = IMPORTANT_DIR / "openclaw-tree.txt"
        header = f"# OpenClaw Workspace Tree\n# Generated: {datetime.now().isoformat()}\n# Command: tree -a -L 8 {WORKSPACE}\n\n"
        try:
            with open(tree_file, 'w') as f:
                f.write(header)
                f.write(tree_output)
            self.logger.info(f'openclaw-tree.txt updated: {tree_file}')
            return True
        except Exception as e:
            self.logger.error(f'Error writing openclaw-tree.txt: {e}')
            return False
    def scan_documentations(self):
        docs = []
        for pattern in ['*.md', '**/*.md']:
            for md_file in WORKSPACE.glob(pattern):
                if md_file.is_file() and not md_file.is_symlink():
                    if 'db/backups' not in str(md_file) and 'node_modules' not in str(md_file):
                        docs.append({
                            'path': str(md_file.relative_to(WORKSPACE)),
                            'hash': self.get_file_hash(md_file),
                            'mtime': md_file.stat().st_mtime
                        })
        return docs
    def check_for_changes(self):
        state = self.load_state()
        current_docs = self.scan_documentations()
        changes = []
        current_hashes = {}
        for doc in current_docs:
            path = doc['path']
            current_hashes[path] = doc['hash']
            if path not in state['file_hashes']:
                changes.append(f'NEW: {path}')
            elif state['file_hashes'][path] != doc['hash']:
                changes.append(f'CHANGED: {path}')
        for old_path in state['file_hashes']:
            if old_path not in current_hashes:
                changes.append(f'DELETED: {old_path}')
        return changes, current_hashes
    def update_databases(self):
        try:
            result = subprocess.run(
                ['python3', str(WORKSPACE / 'scripts' / 'update_docs_db.py')],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                self.logger.info('docs.db updated')
                return True
            else:
                self.logger.error(f'DB update failed: {result.stderr}')
                return False
        except Exception as e:
            self.logger.error(f'DB update exception: {e}')
            return False
    def update_tree_db_v2(self):
        try:
            result = subprocess.run(
                ['python3', str(WORKSPACE / 'scripts' / 'tree_indexer_v2.py')],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode == 0:
                self.logger.info('tree.db v2 updated')
                return True
            else:
                self.logger.error(f'Tree DB v2 failed: {result.stderr}')
                return False
        except Exception as e:
            self.logger.error(f'Tree DB v2 exception: {e}')
            return False
    def create_backup(self):
        timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M')
        for db_name in ['docs.db', 'tree.db']:
            source = DB_DIR / db_name
            if source.exists():
                backup_name = f"{timestamp}_{db_name}.bak"
                backup_path = BACKUP_DIR / backup_name
                copy2(source, backup_path)
                self.logger.info(f'Backup created: {backup_name}')
        return timestamp
    def cleanup_old_backups(self):
        cutoff = datetime.now() - timedelta(days=self.retention_days)
        deleted = 0
        for db_name in ['docs.db', 'tree.db']:
            for backup in BACKUP_DIR.glob(f"*_{db_name}.bak"):
                try:
                    date_part = backup.name.split('_')[0]
                    time_part = backup.name.split('_')[1]
                    backup_time = datetime.strptime(f"{date_part}_{time_part}", '%Y-%m-%d_%H-%M')
                    if backup_time < cutoff:
                        backup.unlink()
                        deleted += 1
                        self.logger.info(f'Old backup deleted: {backup.name}')
                except Exception:
                    self.logger.warn(f'Could not parse backup date: {backup.name}')
        if deleted == 0:
            self.logger.info('No old backups to delete')
        else:
            self.logger.info(f'{deleted} old backups deleted (< {self.retention_days} days)')
    def run_cycle(self):
        self.logger.info('='*60)
        self.logger.info('DB MAINTAINER CYCLE START')
        self.logger.info('='*60)
        state = self.load_state()
        # Tree command & file update
        self.logger.info('Running tree -a -L 8...')
        tree_output = self.run_tree_command()
        if tree_output:
            self.update_tree_file(tree_output)
            state['last_tree_update'] = datetime.now().isoformat()
        # Update tree.db (v2)
        self.logger.info('Updating tree.db v2...')
        self.update_tree_db_v2()
        # Check documentation changes
        self.logger.info('Checking documentation changes...')
        changes, current_hashes = self.check_for_changes()
        if changes:
            self.logger.info(f'{len(changes)} changes detected')
            for change in changes[:10]:
                self.logger.info(f'  - {change}')
            if len(changes) > 10:
                self.logger.info(f'  ... and {len(changes)-10} more')
            self.logger.info('Updating docs.db...')
            if self.update_databases():
                state['last_check'] = datetime.now().isoformat()
                state['file_hashes'] = current_hashes
        else:
            self.logger.info('No documentation changes found')
        # Hourly backup check
        do_backup = False
        if state.get('last_backup'):
            last_backup_time = datetime.fromisoformat(state['last_backup'])
            if datetime.now() - last_backup_time >= timedelta(hours=1):
                do_backup = True
        else:
            do_backup = True
        if do_backup:
            self.logger.info('Creating hourly backup...')
            self.create_backup()
            state['last_backup'] = datetime.now().isoformat()
            self.logger.info('Cleaning old backups...')
            self.cleanup_old_backups()
        else:
            self.logger.info('Backup not needed (last < 1h)')
        self.save_state(state)
        self.logger.info('='*60)
        self.logger.info('DB MAINTAINER CYCLE END')
        self.logger.info('='*60)

def main():
    maintainer = DatabaseMaintainer()
    try:
        maintainer.run_cycle()
    except Exception as e:
        maintainer.logger.error(f'CRITICAL ERROR: {e}')
        sys.exit(1)

if __name__ == '__main__':
    main()
