#!/usr/bin/env python3
"""
Bidirektionale ClawHub ↔ Git Synchronisation
"""

import os
import sys
import json
import shutil
import hashlib
from pathlib import Path
from datetime import datetime

# Konfiguration
CLAWHUB_DIR = Path("/home/openclaw/.openclaw/workspace/skills")
GIT_DIR = Path("/home/openclaw/.openclaw/workspace/git/skills")
BACKUP_DIR = Path("/home/openclaw/.openclaw/workspace/backups/sync")
LOG_FILE = Path("/home/openclaw/.openclaw/workspace/logs/sync-agent.log")
IGNORED_NAMES = {".git", ".clawhub", "node_modules", "__pycache__"}

# Erstelle Verzeichnisse
GIT_DIR.mkdir(parents=True, exist_ok=True)
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

# Logging
def log(message, level="INFO"):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    entry = f"[{timestamp}] [{level}] {message}"
    print(entry)
    with open(LOG_FILE, 'a') as f:
        f.write(entry + '\n')

# Validierung
def validate_skill(skill_dir: Path) -> bool:
    """Prüft Skill-Struktur - SKILL.md required, scripts/ optional"""
    if not (skill_dir / "SKILL.md").exists():
        log(f"Validation failed: {skill_dir.name} missing SKILL.md", "ERROR")
        return False
    return True

def _is_ignored_path(path: Path) -> bool:
    return any(part in IGNORED_NAMES for part in path.parts) or path.suffix == ".pyc"

def iter_sync_files(root: Path):
    """Yield files that should participate in sync comparisons."""
    for current_root, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORED_NAMES and not d.startswith("__pycache__")]
        rel_root = Path(current_root).relative_to(root)
        if _is_ignored_path(rel_root):
            continue
        for file in files:
            if file in IGNORED_NAMES or file.endswith(".pyc"):
                continue
            file_path = Path(current_root) / file
            rel_path = file_path.relative_to(root)
            if _is_ignored_path(rel_path):
                continue
            if not file_path.is_file():
                continue
            yield file_path, rel_path

def _copy_ignore(_path, names):
    return [name for name in names if name in IGNORED_NAMES or name.endswith(".pyc")]

# Backup
def create_backup(source: Path, skill_name: str):
    """Erstellt Backup eines Skills"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = BACKUP_DIR / f"{skill_name}_{timestamp}"
    
    # Backup verzeichnis löschen falls es existiert
    if backup_path.exists():
        try:
            shutil.rmtree(backup_path)
            log(f"Removed existing backup: {backup_path}")
        except Exception as e:
            log(f"Failed to remove existing backup {backup_path}: {e}", "ERROR")
            return False
            
    try:
        shutil.copytree(source, backup_path, ignore=_copy_ignore)
        log(f"Backup created: {backup_path}")
        return True
    except Exception as e:
        log(f"Backup failed: {e}", "ERROR")
        return False

# Hash-Vergleich
def get_file_hash(file_path: Path) -> str:
    """SHA256-Hash einer Datei"""
    # Ensure the path points to a regular file.
    if not file_path.is_file():
        return ""
    hasher = hashlib.sha256()
    try:
        with open(file_path, 'rb') as f:
            while chunk := f.read(4096):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception as e:
        log(f"Failed to hash {file_path}: {e}", "ERROR")
        return ""

# Sync Richtung ClawHub → Git
def sync_to_git(skill_name: str, dry_run: bool = True):
    """Synchronisiert ClawHub Skill zu Git"""
    source = CLAWHUB_DIR / skill_name
    target = GIT_DIR / skill_name
    
    if not validate_skill(source):
        return False
    
    # Backup vor Änderungen (nur wenn target existiert)
    if not dry_run and target.exists():
        create_backup(target, skill_name)
    
    # Änderungen erkennen
    changes = []
    for src_file, rel_path in iter_sync_files(source):
        tgt_file = target / rel_path
        if not tgt_file.exists():
            changes.append(f"ADD {rel_path}")
        elif get_file_hash(src_file) != get_file_hash(tgt_file):
            changes.append(f"UPDATE {rel_path}")
    
    # Dry-Run Report
    if dry_run:
        log(f"DRY-RUN: {skill_name} - {len(changes)} changes")
        for change in changes:
            log(f"  {change}")
        return True
    
    # Echte Synchronisation
    log(f"SYNC: {skill_name} - Applying {len(changes)} changes")
    if target.exists():
        shutil.copytree(source, target, dirs_exist_ok=True, ignore=_copy_ignore)
    else:
        shutil.copytree(source, target, ignore=_copy_ignore)
    log(f"SYNC: {skill_name} - Complete")
    return True

# Sync Richtung Git → ClawHub
def sync_to_clawhub(skill_name: str, dry_run: bool = True):
    """Synchronisiert Git Skill zu ClawHub"""
    source = GIT_DIR / skill_name
    target = CLAWHUB_DIR / skill_name
    
    if not validate_skill(source):
        return False
    
    # Backup vor Änderungen (nur wenn target existiert)
    if not dry_run and target.exists():
        create_backup(target, skill_name)

    # Änderungen erkennen (gleiche Logik wie oben)
    changes = []
    for src_file, rel_path in iter_sync_files(source):
        tgt_file = target / rel_path
        if not tgt_file.exists():
            changes.append(f"ADD {rel_path}")
        elif get_file_hash(src_file) != get_file_hash(tgt_file):
            changes.append(f"UPDATE {rel_path}")

    # Dry-Run Report
    if dry_run:
        log(f"DRY-RUN: {skill_name} - {len(changes)} changes")
        for change in changes:
            log(f"  {change}")
        return True

    # Echte Synchronisation
    log(f"SYNC: {skill_name} - Applying {len(changes)} changes")
    if target.exists():
        shutil.copytree(source, target, dirs_exist_ok=True, ignore=_copy_ignore)
    else:
        shutil.copytree(source, target, ignore=_copy_ignore)
    log(f"SYNC: {skill_name} - Complete")
    return True

# Hauptfunktion
def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Bidirektionaler Sync ClawHub ↔ Git')
    parser.add_argument('--skill', required=True, help='Skill name')
    parser.add_argument('--direction', choices=['to-git', 'to-clawhub'], required=True)
    parser.add_argument('--dry-run', action='store_true', help='Nur Änderungen anzeigen')
    parser.add_argument('--force', action='store_true', help='Ohne Backup')
    
    args = parser.parse_args()
    
    log(f"Starting sync: {args.skill} ({args.direction})")
    
    if args.direction == 'to-git':
        success = sync_to_git(args.skill, args.dry_run)
    else:
        success = sync_to_clawhub(args.skill, args.dry_run)
    
    if not success:
        log("Sync failed", "ERROR")
        sys.exit(1)
    
    log("Sync completed")

if __name__ == "__main__":
    main()
