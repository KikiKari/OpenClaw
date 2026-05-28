#!/usr/bin/env python3
"""
Permanenter ClawHub ↔ Git Sync Agent
Multi-Node fähig, stündliche Ausführung
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime

# Import sync functions
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git, sync_to_clawhub, log, validate_skill, get_file_hash, iter_sync_files

CLAWHUB_DIR = Path("/home/openclaw/.openclaw/workspace/skills")
GIT_DIR = Path("/home/openclaw/.openclaw/workspace/git/skills")
STATE_FILE = Path("/home/openclaw/.openclaw/workspace/db/sync_state.json")

def load_state():
    """Lädt den Sync-State"""
    if STATE_FILE.exists():
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    return {"sync_history": [], "pending": []}

def save_state(state):
    """Speichert den Sync-State"""
    # Ensure the parent directory exists (handle symlink to existing directory)
    if not STATE_FILE.parent.is_dir():
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)

def get_all_skills():
    """Findet alle Skills in beiden Verzeichnissen"""
    clawhub_skills = {
        d.name
        for d in CLAWHUB_DIR.iterdir()
        if d.is_dir() and not d.name.startswith('.') and (d / "SKILL.md").exists()
    }
    git_skills = {
        d.name
        for d in GIT_DIR.iterdir()
        if d.is_dir() and not d.name.startswith('.') and (d / "SKILL.md").exists()
    }
    return clawhub_skills.union(git_skills)

def init_git_repo(skill_path: Path, skill_name: str):
    """Initialisiert Git-Repo wenn nötig"""
    git_dir = skill_path / ".git"
    if not git_dir.exists():
        os.chdir(skill_path)
        subprocess.run(["git", "init"], capture_output=True)
        subprocess.run(["git", "add", "."], capture_output=True)
        subprocess.run(["git", "commit", "-m", f"Initial commit: {skill_name} skill"], capture_output=True)
        log(f"Git initialized for {skill_name}")

def sync_skill_bidirectional(skill_name: str):
    """Bidirektionale Synchronisation eines Skills"""
    clawhub_path = CLAWHUB_DIR / skill_name
    git_path = GIT_DIR / skill_name
    
    # Fall 1: Nur in ClawHub → zu Git
    if clawhub_path.exists() and not git_path.exists():
        log(f"NEW in ClawHub: {skill_name} → syncing to Git")
        if sync_to_git(skill_name, dry_run=False):
            init_git_repo(git_path, skill_name)
            return "synced_to_git"
    
    # Fall 2: Nur in Git → zu ClawHub
    elif git_path.exists() and not clawhub_path.exists():
        log(f"NEW in Git: {skill_name} → syncing to ClawHub")
        if sync_to_clawhub(skill_name, dry_run=False):
            return "synced_to_clawhub"
    
    # Fall 3: In beiden vorhanden
    elif clawhub_path.exists() and git_path.exists():
        if not validate_skill(clawhub_path):
            log(f"Validation failed for ClawHub skill: {skill_name}", "ERROR")
            return "error"
        if not validate_skill(git_path):
            log(f"Validation failed for Git skill: {skill_name}", "ERROR")
            return "error"

        clawhub_changes = preview_changes(clawhub_path, git_path)
        git_changes = preview_changes(git_path, clawhub_path)

        if not clawhub_changes and not git_changes:
            log(f"Content is identical for: {skill_name}")
            return "no_change"

        if clawhub_changes and not git_changes:
            log(f"Content difference detected for: {skill_name}")
            log(f"UPDATE: {skill_name} ClawHub content is newer or different → syncing to Git")
            if sync_to_git(skill_name, dry_run=False):
                os.chdir(git_path)
                subprocess.run(["git", "add", "."], capture_output=True)
                subprocess.run(["git", "commit", "-m", f"Sync from ClawHub content diff: {datetime.now().strftime('%Y-%m-%d %H:%M')}"], capture_output=True)
                return "updated_git"
            log(f"Failed to sync {skill_name} to Git after content diff", "ERROR")
            return "error"

        if git_changes and not clawhub_changes:
            log(f"Content difference detected for: {skill_name}")
            log(f"UPDATE: {skill_name} Git content is newer or different → syncing to ClawHub")
            if sync_to_clawhub(skill_name, dry_run=False):
                return "updated_clawhub"
            log(f"Failed to sync {skill_name} to ClawHub after content diff", "ERROR")
            return "error"

        log(f"Content difference detected for: {skill_name}")
        if newest_mtime(clawhub_path) >= newest_mtime(git_path):
            log(f"UPDATE: {skill_name} ClawHub content is newer or different → syncing to Git")
            if sync_to_git(skill_name, dry_run=False):
                os.chdir(git_path)
                subprocess.run(["git", "add", "."], capture_output=True)
                subprocess.run(["git", "commit", "-m", f"Sync from ClawHub content diff: {datetime.now().strftime('%Y-%m-%d %H:%M')}"], capture_output=True)
                return "updated_git"
        else:
            log(f"UPDATE: {skill_name} Git content is newer or different → syncing to ClawHub")
            if sync_to_clawhub(skill_name, dry_run=False):
                return "updated_clawhub"

        log(f"Failed to resolve content diff for {skill_name}", "ERROR")
        return "error"
    
    return "no_change"

# --- Hinzufügen dieser Hilfsfunktion ---
def get_hashes(skill_dir: Path):
    """Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner."""
    hashes = {}
    for file_path, rel_path in iter_sync_files(skill_dir):
        hashes[str(rel_path)] = get_file_hash(file_path)
    return hashes

def preview_changes(source_dir: Path, target_dir: Path):
    """Berechnet Sync-Änderungen in einer Richtung, ohne zu schreiben."""
    changes = []
    for src_file, rel_path in iter_sync_files(source_dir):
        tgt_file = target_dir / rel_path
        if not tgt_file.exists():
            changes.append(f"ADD {rel_path}")
        elif get_file_hash(src_file) != get_file_hash(tgt_file):
            changes.append(f"UPDATE {rel_path}")
    return changes

def newest_mtime(skill_dir: Path) -> float:
    """Ermittelt die neueste mtime über alle relevanten Dateien."""
    mtimes = [file_path.stat().st_mtime for file_path, _ in iter_sync_files(skill_dir)]
    return max(mtimes) if mtimes else 0.0

def main():
    """Hauptfunktion des Sync-Agents mit Dry-Run Phase"""
    log("=== ClawHub ↔ Git Sync Agent gestartet ===")
    
    # Load previous state
    state = load_state()
    all_skills = get_all_skills()
    log(f"Gefundene Skills: {len(all_skills)}")
    
    # Dry-Run Phase: only report changes, no actual modifications
    log("--- Dry-Run Phase Start ---")
    for skill in sorted(all_skills):
        # Perform dry-run sync in both directions to capture potential changes
        sync_to_git(skill, dry_run=True)
        sync_to_clawhub(skill, dry_run=True)
    log("--- Dry-Run Phase End ---")
    
    results = {
        "synced_to_git": [],
        "synced_to_clawhub": [],
        "updated_git": [],
        "updated_clawhub": [],
        "no_change": [],
        "errors": []
    }
    
    # Actual Sync Phase
    for skill in sorted(all_skills):
        try:
            result = sync_skill_bidirectional(skill)
            results[result].append(skill)
        except Exception as e:
            log(f"ERROR syncing {skill}: {e}", "ERROR")
            results["errors"].append(skill)
    
    # Zusammenfassung
    log("\n=== SYNC ZUSAMMENFASSUNG ===")
    log(f"Neu in Git: {len(results['synced_to_git'])} - {results['synced_to_git']}")
    log(f"Neu in ClawHub: {len(results['synced_to_clawhub'])} - {results['synced_to_clawhub']}")
    log(f"Git aktualisiert: {len(results['updated_git'])} - {results['updated_git']}")
    log(f"ClawHub aktualisiert: {len(results['updated_clawhub'])} - {results['updated_clawhub']}")
    log(f"Keine Änderung: {len(results['no_change'])}")
    log(f"Fehler: {len(results['errors'])} - {results['errors']}")
    
    # State speichern
    if "sync_history" not in state:
        state["sync_history"] = []
    state["sync_history"].append({
        "timestamp": datetime.now().isoformat(),
        "results": results
    })
    # Nur letzte 100 Einträge behalten
    state["sync_history"] = state["sync_history"][-100:]
    save_state(state)
    
    log("=== Sync Agent beendet ===\n")

if __name__ == "__main__":
    main()
