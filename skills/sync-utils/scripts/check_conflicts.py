#!/usr/bin/env python3
"""
Check Conflicts - Erkennt Sync-Konflikte
"""

import sys
from pathlib import Path
from datetime import datetime

# Import sync functions
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import get_file_hash

CLAWHUB_DIR = Path("/home/openclaw/.openclaw/workspace/skills")
GIT_DIR = Path("/home/openclaw/.openclaw/workspace/git/skills")

def check_conflicts():
    """Prüft auf Konflikte zwischen ClawHub und Git"""
    conflicts = []
    
    # Alle Skills die in beiden Orten existieren
    common_skills = []
    if CLAWHUB_DIR.exists() and GIT_DIR.exists():
        clawhub_skills = {d.name for d in CLAWHUB_DIR.iterdir() if d.is_dir()}
        git_skills = {d.name for d in GIT_DIR.iterdir() if d.is_dir()}
        common_skills = clawhub_skills.intersection(git_skills)
    
    print(f"Prüfe {len(common_skills)} Skills auf Konflikte...\n")
    
    for skill in sorted(common_skills):
        clawhub_path = CLAWHUB_DIR / skill
        git_path = GIT_DIR / skill
        
        # Alle Dateien vergleichen
        skill_conflicts = []
        
        # ClawHub Dateien
        clawhub_files = {}
        for f in clawhub_path.rglob('*'):
            if f.is_file() and '.git' not in str(f):
                rel_path = f.relative_to(clawhub_path)
                clawhub_files[str(rel_path)] = f
        
        # Git Dateien
        git_files = {}
        for f in git_path.rglob('*'):
            if f.is_file() and '.git' not in str(f):
                rel_path = f.relative_to(git_path)
                git_files[str(rel_path)] = f
        
        # Vergleiche gemeinsame Dateien
        for rel_path in set(clawhub_files.keys()).intersection(git_files.keys()):
            clawhub_file = clawhub_files[rel_path]
            git_file = git_files[rel_path]
            
            if get_file_hash(clawhub_file) != get_file_hash(git_file):
                clawhub_mtime = datetime.fromtimestamp(clawhub_file.stat().st_mtime)
                git_mtime = datetime.fromtimestamp(git_file.stat().st_mtime)
                
                skill_conflicts.append({
                    "file": rel_path,
                    "clawhub_modified": clawhub_mtime.strftime('%Y-%m-%d %H:%M:%S'),
                    "git_modified": git_mtime.strftime('%Y-%m-%d %H:%M:%S'),
                    "newer": "clawhub" if clawhub_mtime > git_mtime else "git"
                })
        
        if skill_conflicts:
            conflicts.append({
                "skill": skill,
                "conflicts": skill_conflicts
            })
    
    # Ausgabe
    if conflicts:
        print("⚠️  KONFLIKTE GEFUNDEN:")
        print("=" * 80)
        
        for conflict in conflicts:
            print(f"\n📦 Skill: {conflict['skill']}")
            print("-" * 40)
            
            for file_conflict in conflict['conflicts']:
                print(f"  📄 {file_conflict['file']}")
                print(f"     ClawHub: {file_conflict['clawhub_modified']}")
                print(f"     Git:     {file_conflict['git_modified']}")
                print(f"     Neuer:   {file_conflict['newer'].upper()}")
                print()
        
        print("=" * 80)
        print(f"Gesamt: {len(conflicts)} Skills mit Konflikten")
        print("\nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen.")
    else:
        print("✅ Keine Konflikte gefunden!")
        print("Alle gemeinsamen Skills sind synchron.")

def main():
    """Hauptfunktion"""
    check_conflicts()

if __name__ == "__main__":
    main()