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
        header = f"""# OpenClaw Workspace Tree\n# Generiert: {datetime.now().isoformat()}\n# Befehl: tree -a -L 8 {WORKSPACE}\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"""
        
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
            
            if path not in state['file_hashes']:
                changes.append(f"NEW: {path}")
            elif state['file_hashes'][path] != doc['hash']:
                changes.append(f"CHANGED: {path}")
        
        # Prüfe auf gelöschte Dateien
        for old_path in state['file_hashes']:
            if old_path not in current_hashes:
                changes.append(f"DELETED: {old_path}")
        
        return changes, current_hashes
    
    def update_databases(self):
        """Führt DB-Update-Scripts aus"""
        try:
            # Update docs.db
            result = subprocess.run(
                ['python3', str(WORKSPACE / 'scripts' / 'update_docs_db.py')],
                capture_output=True, text=True, timeout=60
            )
            
            if result.returncode == 0:
                self.logger.info("docs.db aktualisiert")
                return True
            else:
                self.logger.error(f"DB-Update fehlgeschlagen: {result.stderr}")
                return False
                
        except Exception as e:
            self.logger.error(f"DB-Update Exception: {e}")
            return False
    
    def update_tree_db_v2(self):
        """Führt tree_indexer_v2.py aus"""
        try:
            result = subprocess.run(
                ['python3', str(WORKSPACE / 'scripts' / 'tree_indexer_v2.py')],
                capture_output=True, text=True, timeout=120
            )
            
            if result.returncode == 0:
                self.logger.info("tree.db v2 aktualisiert")
                return True
            else:
                self.logger.error(f"Tree-DB v2 fehlgeschlagen: {result.stderr}")
                return False
                
        except Exception as e:
            self.logger.error(f"Tree-DB v2 Exception: {e}")
            return False
    
    def create_backup(self):
        """Erstellt Backup beider Datenbanken"""
        timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M')
        
        for db_name in ['docs.db', 'tree.db']:
            source = DB_DIR / db_name
            if source.exists():
                backup_name = f"{timestamp}_{db_name}.bak"
                backup_path = BACKUP_DIR / backup_name
                copy2(source, backup_path)
                self.logger.info(f"Backup erstellt: {backup_name}")
        
        return timestamp
    
    def cleanup_old_backups(self):
        """Löscht Backups älter als 3 Tage"""
        cutoff = datetime.now() - timedelta(days=self.retention_days)
        deleted = 0
        
        for db_name in ['docs.db', 'tree.db']:
            backups = list(BACKUP_DIR.glob(f"*_{db_name}.bak"))
            
            for backup in backups:
                try:
                    date_str = backup.name.split('_')[0]
                    time_str = backup.name.split('_')[1]
                    backup_time = datetime.strptime(f"{date_str}_{time_str}", '%Y-%m-%d_%H-%M')
                    
                    if backup_time < cutoff:
                        backup.unlink()
                        deleted +=