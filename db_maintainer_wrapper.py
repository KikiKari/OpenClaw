#!/usr/bin/env python3
"""
Database Maintainer Sub-Agent - Wrapper
Runs the original db maintainer with corrected workspace path.
"""

import sqlite3
import hashlib
import json
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from shutil import copy2
import sys

# Updated workspace path for sandbox environment
WORKSPACE = Path("/workspace")
DB_DIR = WORKSPACE / "db"
BACKUP_DIR = DB_DIR / "backups"
LOG_DIR = WORKSPACE / "logs" / "db-maintainer"
IMPORTANT_DIR = WORKSPACE / "important"

# Ensure directories exist
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

class Logger:
    """Simple logger that writes to a file and stdout"""
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
        except:
            return None
    def run_tree_command(self):
        try:
            result = subprocess.run(['tree', '-a', '-L', '8', str(WORKSPACE)], capture_output=True, text=True, timeout=60)
            if result.returncode == 0:
                self.logger.info("tree -a -L 8 erfolgreich ausgeführt")
                return result.stdout
            else:
                self.logger.error(f"tree command fehlgeschlagen: {result.stderr}")
                return None
        except Exception as e:
