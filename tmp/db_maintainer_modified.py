#!/usr/bin/env python3
"""
Modified DB Maintainer script for sandbox execution.
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

# Ensure directories exist
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
    def info(self,msg): self.log('INFO',msg)
    def warn(self,msg): self.log('WARN',msg)
    def error(self,msg): self.log('ERROR',msg)

class DatabaseMaintainer:
    def __init__(self):
        self.logger = Logger()
        self.state_file = DB_DIR / "maintainer_state.json"
        self.retention_days = 3
    def load_state(self):
        if self.state_file.exists():
            with open(self.state_file) as f:
                return json.load(f)
        return {'last_check':None,'last_backup':None,'last_tree_update':None,'file_hashes':{}}
    def save_state(self,state):
        with open(self.state_file,'w') as f:
            json.dump(state,f,indent=2)
    def get_file_hash(self,filepath):
        try:
            with open(filepath,'rb') as f:
                return hashlib.md5(f.read()).hexdigest()
        except:
            return None
    def run_tree_command(self):
        try:
            result = subprocess.run(['tree','-a','-L','8',str(WORKSPACE)],capture_output=True,text=True,timeout=60)
            if result.returncode==0:
                self.logger.info('tree command succeeded')
                return result.stdout
            else:
                self.logger.error(f'tree failed: {result.stderr}')
                return None
        except Exception as e:
            self.logger.error(f'tree exception: {e}')
            return None
    def update_tree_file(self,tree_output):
        if not tree_output:
            return False
        tree_file = IMPORTANT_DIR / 'openclaw-tree.txt'
        header = f"# OpenClaw Workspace Tree\n# Generated: {datetime.now().isoformat()}\n# Command: tree -a -L 8 {WORKSPACE}\n\n"
        try:
            with open(tree_file,'w') as f:
                f.write(header)
                f.write(tree_output)
            self.logger.info(f'Updated {tree_file}')
            return True
        except Exception as e:
            self.logger.error(f'Failed to write tree file: {e}')
            return False
    def scan_documentations(self):
        docs=[]
        for pattern in ['*.md','**/*.md']:
            for md in WORKSPACE.glob(pattern):
                if md.is_file() and not md.is_symlink():
                    if 'db/backups' not in str(md) and 'node_modules' not in str(md):
                        docs.append({'path':str(md.relative_to(WORKSPACE)),'hash':self.get_file_hash(md)})
        return docs
    def check_for_changes(self):
        state=self.load_state()
        current=self.scan_documentations()
        changes=[]
        cur_hashes={}
        for doc in current:
            p=doc['path']
            cur_hashes[p]=doc['hash']
            if p not in state['file_hashes']:
                changes.append(f'NEW: {p}')
            elif state['file_hashes'][p]!=doc['hash']:
                changes.append(f'CHANGED: {p}')
        for old in state['file_hashes']:
            if old not in cur_hashes:
                changes.append(f'DELETED: {old}')
        return changes,cur_hashes
    def update_databases(self):
        try:
            result = subprocess.run(['python3', str(WORKSPACE/'scripts'/'update_docs_db.py')],capture_output=True,text=True,timeout=60)
            if result.returncode==0:
                self.logger.info('docs.db updated')
                return True
            else:
                self.logger.error(f'docs update failed: {result.stderr}')
                return False
        except Exception as e:
            self.logger.error(f'exception updating docs.db: {e}')
            return False
    def update_tree_db_v2(self):
        try:
            result = subprocess.run(['python3', str(WORKSPACE/'scripts'/'tree_indexer_v2.py')],capture_output=True,text=True,timeout=120)
            if result.returncode==0:
                self.logger.info('tree.db updated')
                return True
            else:
                self.logger.error(f'tree db update failed: {result.stderr}')
                return False
        except Exception as e:
            self.logger.error(f'exception updating tree db: {e}')
            return False
    def create_backup(self):
        ts=datetime.now().strftime('%Y-%m-%d_%H-%M')
        for db in ['docs.db','tree.db']:
            src=DB_DIR/db
            if src.exists():
                backup=BACKUP_DIR/f"{ts}_{db}.bak"
                copy2(src,backup)
                self.logger.info(f'Backup created: {backup.name}')
        return ts
    def cleanup_old_backups(self):
        cutoff=datetime.now()-timedelta(days=self.retention_days)
        deleted=0
        for db in ['docs.db','tree.db']:
            for backup in BACKUP_DIR.glob(f'*_{db}.bak'):
                try:
                    parts=backup.name.split('_')
                    date_str=parts[0]
                    time_str=parts[1]
                    backup_time=datetime.strptime(f'{date_str}_{time_str}','%Y-%m-%d_%H-%M')
                    if backup_time<cutoff:
                        backup.unlink()
                        deleted+=1
                        self.logger.info(f'Deleted old backup: {backup.name}')
                except Exception:
                    self.logger.warn(f'Could not parse backup date: {backup.name}')
        if deleted==0:
            self.logger.info('No old backups to delete')
    def run_cycle(self):
        self.logger.info('=== Starting DB Maintainer Cycle ===')
        state=self.load_state()
        # tree command
        self.logger.info('Running tree command')
        tree_output=self.run_tree_command()
        if tree_output:
            self.update_tree_file(tree_output)
            state['last_tree_update']=datetime.now().isoformat()
        # tree db v2
        self.logger.info('Updating tree.db v2')
        self.update_tree_db_v2()
        # check changes
        self.logger.info('Checking documentation changes')
        changes,cur_hashes=self.check_for_changes()
        if changes:
            self.logger.info(f'Found {len(changes)} changes')
            for c in changes[:10]:
                self.logger.info(f'  {c}')
            if len(changes)>10:
                self.logger.info(f'  ... and {len(changes)-10} more')
            self.logger.info('Updating docs.db')
            if self.update_databases():
                state['last_check']=datetime.now().isoformat()
                state['file_hashes']=cur_hashes
        else:
            self.logger.info('No documentation changes')
        # backup
        do_backup=True
        last_backup=state.get('last_backup')
        if last_backup:
            try:
                last_time=datetime.fromisoformat(last_backup)
                if datetime.now()-last_time<timedelta(hours=1):
                    do_backup=False
            except Exception:
                pass
        if do_backup:
            self.logger.info('Creating hourly backup')
            self.create_backup()
            state['last_backup']=datetime.now().isoformat()
            self.logger.info('Cleaning old backups')
            self.cleanup_old_backups()
        else:
            self.logger.info('Backup not needed')
        self.save_state(state)
        self.logger.info('=== DB Maintainer Cycle Done ===')

def main():
    maintainer=DatabaseMaintainer()
    try:
        maintainer.run_cycle()
    except Exception as e:
        maintainer.logger.error(f'Critical error: {e}')
        sys.exit(1)

if __name__=='__main__':
    main()
