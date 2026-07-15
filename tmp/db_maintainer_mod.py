#!/usr/bin/env python3
"""
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt
"""

import sqlite3
import hashlib
import json
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from shutil import copy2
import sys

WORKSPACE = Path("/workspace")
DB_DIR = WORKSPACE / "db"
BACKUP_DIR = DB_DIR / "backups"
LOG_DIR = WORKSPACE / "logs" / "db-maintainer"
IMPORTANT_DIR = WORKSPACE / "important"

# Verzeichnisse erstellen
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)


class Logger:
    """Einfacher Logger mit Datei-Ausgabe"""
    
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
        self.retention_days = 3  # 3 Tage Backup-Aufbewahrung
        
    def load_state(self):
        """Lädt letzten Check-Zustand"""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                return json.load(f)
        return {'last_check': None, 'last_backup': None, 'last_tree_update': None, 'file_hashes': {}}
    
    def save_state(self, state):
        """Speichert aktuellen Zustand"""
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
    def get_file_hash(self, filepath):
        """Berechnet MD5-Hash einer Datei"""
        try:
            with open(filepath, 'rb') as f:
                return hashlib.md5(f.read()).hexdigest()
        except:
            return None
    
    def run_tree_command(self):
        """Führt tree -a -L 8 auf workspace aus und gibt Ergebnis zurück"""
        try:
            result = subprocess.run(
                ['tree', '-a', '-L', '8', str(WORKSPACE)],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                self.logger.info("tree -a -L 8 erfolgreich ausgeführt")
                return result.stdout
            else:
                self.logger.error(f"tree command fehlgeschlagen: {result.stderr}")
                return None
        except Exception as e:
            self.logger.error(f"tree command Exception: {e}")
            return None
    
    def update_tree_file(self, tree_output):
        """Schreibt tree-output in important/openclaw-tree.txt"""
        if not tree_output:
            return False
        
        tree_file = IMPORTANT_DIR / "openclaw-tree.txt"
        
        # Header mit Timestamp
        header = f"""# OpenClaw Workspace Tree
# Generiert: {datetime.now().isoformat()}
# Befehl: tree -a -L 8 {WORKSPACE}
# Diese Datei wird automatisch von db-maintainer aktualisiert

"""
        
        try:
            with open(tree_file, 'w') as f:
                f.write(header)
                f.write(tree_output)
            self.logger.info(f"openclaw-tree.txt aktualisiert: {tree_file}")
            return True
        except Exception as e:
            self.logger.error(f"Fehler beim Schreiben von openclaw-tree.txt: {e}")
            return False
    
    def scan_documentations(self):
        """Scannt alle .md Dateien auf Änderungen"""
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
        """Prüft auf Änderungen seit letztem Lauf"""
        state = self.load_state()
        current_docs = self.scan_documentations()
        
        changes = []
        current_hashes = {}
        
        for doc in current_docs:
            path = doc['path']
            current_hashes[path] = doc['hash']
            if path not in state['file_hashes']