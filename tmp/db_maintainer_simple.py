#!/usr/bin/env python3
"""
Simplified DB Maintainer Script
Runs a minimal maintenance routine:
- Generates a simple directory tree snapshot and writes to important/openclaw-tree.txt
- Creates backups of existing docs.db and tree.db (if present)
- Removes backups older than 3 days
"""

import json
import os
import shutil
from datetime import datetime, timedelta
from pathlib import Path

WORKSPACE = Path('/workspace')
DB_DIR = WORKSPACE / 'db'
BACKUP_DIR = DB_DIR / 'backups'
LOG_DIR = WORKSPACE / 'logs' / 'db-maintainer'
IMPORTANT_DIR = WORKSPACE / 'important'

# Ensure directories exist
for d in [BACKUP_DIR, LOG_DIR, IMPORTANT_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# Simple logger writing to a daily log file
class Logger:
    def __init__(self):
        today = datetime.now().strftime('%Y-%m-%d')
        self.log_file = LOG_DIR / f'{today}.log'
    def _log(self, level, msg):
        ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        line = f'[{ts}] [{level}] {msg}'
        print(line)
        with open(self.log_file, 'a') as f:
            f.write(line + '\n')
    def info(self, msg): self._log('INFO', msg)
    def warn(self, msg): self._log('WARN', msg)
    def error(self, msg): self._log('ERROR', msg)

logger = Logger()

def generate_tree(depth=2, prefix=''):
    """Recursively generate a simple directory tree up to a given depth."""
    if depth < 0:
        return ''
    lines = []
    try:
        entries = sorted([e for e in os.listdir(WORKSPACE) if not e.startswith('.')])
    except Exception as e:
        logger.error(f'Failed to list workspace: {e}')
        return ''
    for name in entries:
        path = WORKSPACE / name
        lines.append(f'{prefix}{name}/')
        if path.is_dir():
            sub_prefix = prefix + '    '
            lines.append(generate_tree(depth-1, sub_prefix))
    return '\n'.join(lines)

def write_tree_file():
    tree_output = generate_tree()
    if not tree_output:
        logger.warn('No tree