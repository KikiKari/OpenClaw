#!/usr/bin/env python3
"""
Database Maintainer Sub-Agent (Sandbox Edition)
Geklont/modifiziert für Sandbox-Ausführung mit find-fallback.
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
        """Fuehrt find-basierte Baumansicht aus (tree nicht installiert)"""
        try:
            # Versuche zuerst tree
            result = subprocess.run(
                ['tree', '-a', '-L', '6', str(WORKSPACE)],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                self.logger.info("tree -a -L 6 erfolgreich")
                return result.stdout
        except FileNotFoundError:
            pass
        except Exception:
            pass
        
        # Fallback: find
        self.logger.info("tree nicht verfuegbar, verwende find-fallback")
        try:
            result = subprocess.run(
                ['find', str(WORKSPACE), '-maxdepth', '6',
                 '-not', '-path', '*/node_modules/*',
                 '-not', '-path', '*/.git/*',
                 '-not', '-path', '*/db/backups/*'],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                lines = []
                for line in sorted(result.stdout.strip().split('\n')):
                    rel = line.replace(str(WORKSPACE) + '/', '')
                    if not rel:
                        continue
                    depth = rel.count('/')
                    indent = '    ' * depth
                    name = rel.split('/')[-1]
                    prefix = '├── ' if depth > 0 else ''
                    lines.append(f"{indent}{prefix}{name}")
                return '\n'.join(lines)
            return None
        except Exception as e:
            self.logger.error(f"find-fallback Exception: {e}")
            return None
    
    def update_tree_file(self, tree_output):
        if not tree_output:
            return False
        tree_file = IMPORTANT_DIR / "openclaw-tree.txt"
        header = f"""# OpenClaw Workspace Tree
# Generiert: {datetime.now().isoformat()}
# Befehl: tree -a -L 6 {WORKSPACE} (find-fallback)
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
        docs = []
        for pattern in ['*.md', '**/*.md']:
            for md_file in WORKSPACE.glob(pattern):
                if md_file.is_file() and not md_file.is_symlink():
                    s = str(md_file)
                    if 'db/backups' not in s and 'node_modules' not in s and '.openclaw/sandbox-skills' not in s:
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
                changes.append(f"NEW: {path}")
            elif state['file_hashes'][path] != doc['hash']:
                changes.append(f"CHANGED: {path}")
        for old_path in state['file_hashes']:
            if old_path not in current_hashes:
                changes.append(f"DELETED: {old_path}")
        return changes, current_hashes
    
    def update_databases(self):
        try:
            update_script = WORKSPACE / 'scripts' / 'update_docs_db.py'
            if not update_script.exists():
                self.logger.warn(f"update_docs_db.py nicht gefunden: {update_script}")
                return False
            result = subprocess.run(
                ['python3', str(update_script)],
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
        try:
            tree_script = WORKSPACE / 'scripts' / 'tree_indexer_v2.py'
            if not tree_script.exists():
                self.logger.warn(f"tree_indexer_v2.py nicht gefunden: {tree_script}")
                return False
            result = subprocess.run(
                ['python3', str(tree_script)],
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
                        deleted += 1
                        self.logger.info(f"Altes Backup geloescht: {backup.name}")
                except:
                    self.logger.warn(f"Konnte Backup-Datum nicht parsen: {backup.name}")
        if deleted == 0:
            self.logger.info("Keine alten Backups zum Loeschen")
        else:
            self.logger.info(f"{deleted} alte Backups geloescht (< 3 Tage)")
    
    def run_cycle(self):
        self.logger.info("="*60)
        self.logger.info("DB MAINTAINER CYCLE START")
        self.logger.info("="*60)
        
        state = self.load_state()
        
        # 1. Tree
        self.logger.info("Fuehre tree/find aus...")
        tree_output = self.run_tree_command()
        if tree_output:
            self.update_tree_file(tree_output)
            state['last_tree_update'] = datetime.now().isoformat()
        
        # 2. tree.db
        self.logger.info("Aktualisiere tree.db v2...")
        self.update_tree_db_v2()
        
        # 3. Changes
        self.logger.info("Pruefe auf Dokumentations-Aenderungen...")
        changes, current_hashes = self.check_for_changes()
        if changes:
            self.logger.info(f"{len(changes)} Aenderungen gefunden:")
            for change in changes[:10]:
                self.logger.info(f"  - {change}")
            if len(changes) > 10:
                self.logger.info(f"  ... und {len(changes)-10} weitere")
            self.logger.info("Aktualisiere docs.db...")
            if self.update_databases():
                state['last_check'] = datetime.now().isoformat()
                state['file_hashes'] = current_hashes
        else:
            self.logger.info("Keine Dokumentations-Aenderungen gefunden")
        
        # 4. Backup
        last_backup = state.get('last_backup')
        if last_backup:
            last_backup_time = datetime.fromisoformat(last_backup)
            do_backup = datetime.now() - last_backup_time >= timedelta(hours=1)
        else:
            do_backup = True
        
        if do_backup:
            self.logger.info("Erstelle stuendliches Backup...")
            self.create_backup()
            state['last_backup'] = datetime.now().isoformat()
            self.logger.info("Raeume alte Backups auf (3 Tage Retention)...")
            self.cleanup_old_backups()
        else:
            self.logger.info("Backup nicht noetig (letztes < 1h)")
        
        self.save_state(state)
        
        self.logger.info("="*60)
        self.logger.info("DB MAINTAINER CYCLE END")
        self.logger.info("="*60)


def main():
    maintainer = DatabaseMaintainer()
    try:
        maintainer.run_cycle()
    except Exception as e:
        maintainer.logger.error(f"CRITICAL ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
