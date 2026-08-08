#!/usr/bin/env python3
"""
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt
"""

import os
import sqlite3
import hashlib
import json
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from shutil import copy2
import sys

WORKSPACE = Path(os.environ.get("OPENCLAW_WORKSPACE", Path(__file__).resolve().parents[1]))
DB_DIR = WORKSPACE
BACKUP_DIR = WORKSPACE / "db" / "backups"
LOG_DIR = WORKSPACE / "logs" / "db-maintainer"
IMPORTANT_DIR = WORKSPACE / "important"

# Verzeichnisse erstellen
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
IMPORTANT_DIR.mkdir(parents=True, exist_ok=True)


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
    
    def _python_tree_fallback(self, max_depth=8):
        """Reiner Python-Fallback, falls das 'tree'-Binary fehlt (z.B. Sandbox)."""
        root = WORKSPACE
        lines = [str(root)]

        def walk(dirpath, prefix, depth):
            if depth > max_depth:
                return
            try:
                entries = sorted(dirpath.iterdir(), key=lambda p: (not p.is_dir(), p.name))
            except (PermissionError, OSError):
                return
            for i, entry in enumerate(entries):
                connector = '└── ' if i == len(entries) - 1 else '├── '
                lines.append(prefix + connector + entry.name)
                if entry.is_dir() and not entry.is_symlink():
                    extension = '    ' if i == len(entries) - 1 else '│   '
                    walk(entry, prefix + extension, depth + 1)

        walk(root, '', 1)
        return '\n'.join(lines) + '\n'

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
                self.logger.warn(f"tree command fehlgeschlagen: {result.stderr.strip()} – nutze Python-Fallback")
                return self._python_tree_fallback()
        except FileNotFoundError:
            self.logger.warn("tree-Binary nicht installiert – nutze Python-Fallback")
            return self._python_tree_fallback()
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
                # Extrahiere Datum aus Filename (Format: YYYY-MM-DD_HH-MM)
                try:
                    date_str = backup.name.split('_')[0]
                    time_str = backup.name.split('_')[1]
                    backup_time = datetime.strptime(f"{date_str}_{time_str}", '%Y-%m-%d_%H-%M')
                    
                    if backup_time < cutoff:
                        backup.unlink()
                        deleted += 1
                        self.logger.info(f"Altes Backup gelöscht: {backup.name}")
                except:
                    self.logger.warn(f"Konnte Backup-Datum nicht parsen: {backup.name}")
        
        if deleted == 0:
            self.logger.info("Keine alten Backups zum Löschen")
        else:
            self.logger.info(f"{deleted} alte Backups gelöscht (< 3 Tage)")
    
    def run_cycle(self):
        """Ein kompletter Wartungszyklus"""
        self.logger.info("="*60)
        self.logger.info("DB MAINTAINER CYCLE START")
        self.logger.info("="*60)
        
        state = self.load_state()
        
        # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        self.logger.info("Führe tree -a -L 8 aus...")
        tree_output = self.run_tree_command()
        if tree_output:
            self.update_tree_file(tree_output)
            state['last_tree_update'] = datetime.now().isoformat()
        
        # 2. tree.db aktualisieren (intern v2)
        self.logger.info("Aktualisiere tree.db v2...")
        self.update_tree_db_v2()
        
        # 3. Änderungen prüfen
        self.logger.info("Prüfe auf Dokumentations-Änderungen...")
        changes, current_hashes = self.check_for_changes()
        
        if changes:
            self.logger.info(f"{len(changes)} Änderungen gefunden:")
            for change in changes[:10]:
                self.logger.info(f"  - {change}")
            if len(changes) > 10:
                self.logger.info(f"  ... und {len(changes)-10} weitere")
            
            # 4. docs.db aktualisieren
            self.logger.info("Aktualisiere docs.db...")
            if self.update_databases():
                state['last_check'] = datetime.now().isoformat()
                state['file_hashes'] = current_hashes
        else:
            self.logger.info("Keine Dokumentations-Änderungen gefunden")
        
        # 5. Prüfe ob Backup fällig (stündlich)
        last_backup = state.get('last_backup')
        
        if last_backup:
            last_backup_time = datetime.fromisoformat(last_backup)
            do_backup = datetime.now() - last_backup_time >= timedelta(hours=1)
        else:
            do_backup = True
        
        if do_backup:
            self.logger.info("Erstelle stündliches Backup...")
            timestamp = self.create_backup()
            state['last_backup'] = datetime.now().isoformat()
            
            # 6. Alte Backups aufräumen (3 Tage Retention)
            self.logger.info("Räume alte Backups auf (3 Tage Retention)...")
            self.cleanup_old_backups()
        else:
            self.logger.info("Backup nicht nötig (letztes < 1h)")
        
        self.save_state(state)
        
        self.logger.info("="*60)
        self.logger.info("DB MAINTAINER CYCLE END")
        self.logger.info("="*60)


def main():
    """Hauptfunktion"""
    maintainer = DatabaseMaintainer()
    
    try:
        maintainer.run_cycle()
    except Exception as e:
        maintainer.logger.error(f"CRITICAL ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
