#!/usr/bin/env python3
"""
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
and tree command execution for important/openclaw-tree.txt
"""

import sqlite3
import hashlib
import json
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from shutil import copy2
import sys

# Use the sandbox workspace path.
WORKSPACE = Path("/workspace")
DB_DIR = WORKSPACE / "db"
BACKUP_DIR = DB_DIR / "backups"
LOG_DIR = WORKSPACE / "logs" / "db-maintainer"
IMPORTANT_DIR = WORKSPACE / "important"

# Ensure necessary directories exist.
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
IMPORTANT_DIR.mkdir(parents=True, exist_ok=True)


class Logger:
    """Simple logger that writes to a file and prints to stdout."""
    
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
        self.retention_days = 3  # keep backups for 3 days
        
    def load_state(self):
        """Load the persisted state (or return defaults)."""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                return json.load(f)
        return {'last_check': None, 'last_backup': None, 'last_tree_update': None, 'file_hashes': {}}
    
    def save_state(self, state):
        """Persist the state to disk."""
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
    def get_file_hash(self, filepath):
        """Return MD5 hash of a file, or None on error."""
        try:
            with open(filepath, 'rb') as f:
                return hashlib.md5(f.read()).hexdigest()
        except Exception:
            return None
    
    def run_tree_command(self):
        """Execute `tree -a -L 8` on the workspace and return its output."""
        try:
            result = subprocess.run(
                ['tree', '-a', '-L', '8', str(WORKSPACE)],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                self.logger.info("tree -a -L 8 executed successfully")
                return result.stdout
            else:
                self.logger.error(f"tree command failed: {result.stderr}")
                return None
        except Exception as e:
            self.logger.error(f"tree command exception: {e}")
            return None
    
    def update_tree_file(self, tree_output):
        """Write the tree output to `important/openclaw-tree.txt`."""
        if not tree_output:
            return False
        
        tree_file = IMPORTANT_DIR / "openclaw-tree.txt"
        header = f"""# OpenClaw Workspace Tree\n# Generated: {datetime.now().isoformat()}\n# Command: tree -a -L 8 {WORKSPACE}\n# This file is automatically maintained by db-maintainer\n\n"""
        try:
            with open(tree_file, 'w') as f:
                f.write(header)
                f.write(tree_output)
            self.logger.info(f"openclaw-tree.txt updated at {tree_file}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to write openclaw-tree.txt: {e}")
            return False
    
    def scan_documentations(self):
        """Return a list of markdown files with their path and hash."""
        docs = []
        for pattern in ['*.md', '**/*.md']:
            for md_file in WORKSPACE.glob(pattern):
                if md_file.is_file() and not md_file.is_symlink():
                    # Skip backup and node_modules directories
                    if 'db/backups' in str(md_file) or 'node_modules' in str(md_file):
                        continue
                    docs.append({
                        'path': str(md_file.relative_to(WORKSPACE)),
                        'hash': self.get_file_hash(md_file),
                        'mtime': md_file.stat().st_mtime
                    })
        return docs
    
    def check_for_changes(self):
        """Detect any added, changed, or deleted markdown files since last run."""
        state = self.load_state()
        current_docs = self.scan_documentations()
        
        changes = []
        current_hashes = {}
        
        for doc in current_docs:
            path = doc['path']
            current_hashes[path] = doc['hash']
            if path not in state['file_hashes']:
                changes.append(f"NEW: {path}")
            elif state['file_hashes'][path] != doc['hash']:
                changes.append(f"CHANGED: {path}")
        
        # Detect deletions
        for old_path in state['file_hashes']:
            if old_path not in current_hashes:
                changes.append(f"DELETED: {old_path}")
        
        return changes, current_hashes
    
    def update_databases(self):
        """Run external scripts to update docs.db and related indexes."""
        try:
            result = subprocess.run(
                ['python3', str(WORKSPACE / 'scripts' / 'update_docs_db.py')],
                capture_output=True, text=True, timeout=120, env={'OPENCLAW_WORKSPACE': str(WORKSPACE)}
            )
            if result.returncode == 0:
                self.logger.info("docs.db updated successfully")
                return True
            else:
                self.logger.error(f"docs.db update failed: {result.stderr}")
                return False
        except Exception as e:
            self.logger.error(f"Exception during docs.db update: {e}")
            return False
    
    def update_tree_db_v2(self):
        """Run tree_indexer_v2.py to refresh tree.db with extended metadata."""
        try:
            result = subprocess.run(
                ['python3', str(WORKSPACE / 'scripts' / 'tree_indexer_v2.py')],
                capture_output=True, text=True, timeout=180, env={'OPENCLAW_WORKSPACE': str(WORKSPACE)}
            )
            if result.returncode == 0:
                self.logger.info("tree.db v2 updated successfully")
                return True
            else:
                self.logger.error(f"tree.db v2 update failed: {result.stderr}")
                return False
        except Exception as e:
            self.logger.error(f"Exception during tree.db v2 update: {e}")
            return False
    
    def create_backup(self):
        """Copy docs.db and tree.db into the backup directory with a timestamped name."""
        timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M')
        for db_name in ['docs.db', 'tree.db']:
            src = DB_DIR / db_name
            if src.exists():
                backup_name = f"{timestamp}_{db_name}.bak"
                dest = BACKUP_DIR / backup_name
                copy2(src, dest)
                self.logger.info(f"Backup created: {backup_name}")
        return timestamp
    
    def cleanup_old_backups(self):
        """Delete any backup files older