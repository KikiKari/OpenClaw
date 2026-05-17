#!/usr/bin/env python3
"""
Sync Status - Zeigt Status aller Skills
"""

import os
import sys
import json
from pathlib import Path
from datetime import datetime

# Import sync functions
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import get_file_hash

CLAWHUB_DIR = Path("/home/openclaw/.openclaw/workspace/skills")
GIT_DIR = Path("/home/openclaw/.openclaw/workspace/git/skills")
STATE_FILE = Path("/home/openclaw/.openclaw/workspace/db/sync_state.json")

def check_skill_status(skill_name: str) -> dict:
    """Prüft Status eines Skills"""
    clawhub_path = CLAWHUB_DIR / skill_name
    git_path = GIT_DIR / skill_name
    
    status = {
        "name": skill_name,
        "in_clawhub": clawhub_path.exists(),
        "in_git": git_path.exists(),
        "has_git_repo": (git_path / ".git").exists() if git_path.exists() else False,
        "status": "unknown",
        "last_modified": {}
    }
    
    # Status bestimmen
    if status["in_clawhub"] and not status["in_git"]:
        status["status"] = "only_clawhub"
    elif status["in_git"] and not status["in_clawhub"]:
        status["status"] = "only_git"
    elif status["in_clawhub"] and status["in_git"]:
        # Timestamps vergleichen
        try:
            clawhub_mtime = max(p.stat().st_mtime for p in clawhub_path.rglob('*') if p.is_file())
            git_mtime = max(p.stat().st_mtime for p in git_path.rglob('*') if p.is_file() and '.git' not in str(p))
            
            status["last_modified"]["clawhub"] = datetime.fromtimestamp(clawhub_mtime).strftime('%Y-%m-%d %H:%M:%S')
            status["last_modified"]["git"] = datetime.fromtimestamp(git_mtime).strftime('%Y-%m-%d %H:%M:%S')
            
            if abs(clawhub_mtime - git_mtime) < 60:
                status["status"] = "synced"
            elif clawhub_mtime > git_mtime:
                status["status"] = "clawhub_newer"
            else:
                status["status"] = "git_newer"
        except:
            status["status"] = "error"
    
    return status

def main():
    """Hauptfunktion"""
    print("=" * 80)
    print("ClawHub ↔ Git Sync Status")
    print("=" * 80)
    print(f"Zeitpunkt: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Alle Skills finden
    all_skills = set()
    if CLAWHUB_DIR.exists():
        all_skills.update(d.name for d in CLAWHUB_DIR.iterdir() if d.is_dir() and not d.name.startswith('.'))
    if GIT_DIR.exists():
        all_skills.update(d.name for d in GIT_DIR.iterdir() if d.is_dir() and not d.name.startswith('.'))
    
    # Status-Kategorien
    categories = {
        "synced": [],
        "clawhub_newer": [],
        "git_newer": [],
        "only_clawhub": [],
        "only_git": [],
        "error": []
    }
    
    # Status für jeden Skill prüfen
    for skill in sorted(all_skills):
        status = check_skill_status(skill)
        categories[status["status"]].append(status)
    
    # Ausgabe
    print(f"📊 Gesamt: {len(all_skills)} Skills\n")
    
    # Synchronisiert
    if categories["synced"]:
        print(f"✅ Synchronisiert ({len(categories['synced'])})")
        for s in categories["synced"]:
            print(f"   - {s['name']}")
        print()
    
    # ClawHub neuer
    if categories["clawhub_newer"]:
        print(f"🔄 ClawHub neuer ({len(categories['clawhub_newer'])})")
        for s in categories["clawhub_newer"]:
            print(f"   - {s['name']} (ClawHub: {s['last_modified']['clawhub']})")
        print()
    
    # Git neuer
    if categories["git_newer"]:
        print(f"🔄 Git neuer ({len(categories['git_newer'])})")
        for s in categories["git_newer"]:
            print(f"   - {s['name']} (Git: {s['last_modified']['git']})")
        print()
    
    # Nur in ClawHub
    if categories["only_clawhub"]:
        print(f"📦 Nur in ClawHub ({len(categories['only_clawhub'])})")
        for s in categories["only_clawhub"]:
            print(f"   - {s['name']}")
        print()
    
    # Nur in Git
    if categories["only_git"]:
        print(f"📁 Nur in Git ({len(categories['only_git'])})")
        for s in categories["only_git"]:
            print(f"   - {s['name']}")
        print()
    
    # Fehler
    if categories["error"]:
        print(f"❌ Fehler ({len(categories['error'])})")
        for s in categories["error"]:
            print(f"   - {s['name']}")
        print()
    
    # State-File Info
    if STATE_FILE.exists():
        with open(STATE_FILE, 'r') as f:
            state = json.load(f)
        last_runs = list(state.get("last_sync", {}).keys())
        if last_runs:
            print(f"📅 Letzter automatischer Sync: {last_runs[-1]}")
    
    print("=" * 80)

if __name__ == "__main__":
    main()