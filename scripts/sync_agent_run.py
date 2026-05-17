#!/usr/bin/env python3
"""
ClawHub ↔ Git Sync Agent - Produktionslauf
"""
import sys
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git, sync_to_clawhub, log, validate_skill
from pathlib import Path
from datetime import datetime
import os
import json

CLAWHUB_DIR = Path('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Path('/home/openclaw/.openclaw/workspace/git/skills')

def file_mtime(path):
    try:
        files = [p for p in path.rglob('*') if p.is_file() and '.git' not in str(p)]
        return max(p.stat().st_mtime for p in files) if files else 0
    except:
        return 0

log("="*70)
log("CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF")
log(f"Zeitstempel: {datetime.now().isoformat()}")
log("="*70)

clawhub_skills = {d.name for d in CLAWHUB_DIR.iterdir() if d.is_dir() and not d.name.startswith('.')}
git_skills = {d.name for d in GIT_DIR.iterdir() if d.is_dir() and not d.name.startswith('.')}

results = {
    "synced_to_git": [],
    "synced_to_clawhub": [],
    "up_to_date": [],
    "errors": []
}

# 1. NEU in ClawHub → zu Git syncen
log("\n[PHASE 1] ClawHub → Git Synchronisation")
log("-" * 40)

new_in_clawhub = sorted(clawhub_skills - git_skills)
for skill in new_in_clawhub:
    try:
        if validate_skill(CLAWHUB_DIR / skill):
            log(f"→ Synchronisiere {skill} zu Git...")
            if sync_to_git(skill, dry_run=False):
                # Git init
                git_path = GIT_DIR / skill
                os.chdir(git_path)
                os.system('git init -q 2>/dev/null')
                os.system('git add . -f 2>/dev/null')
                dt = datetime.now().strftime("%Y-%m-%d %H:%M")
                os.system(f'git commit -m "Initial: {skill}" -q 2>/dev/null')
                results["synced_to_git"].append(skill)
                log(f"  ✓ {skill} synchronisiert & Git initialisiert")
            else:
                results["errors"].append(f"{skill} (sync failed)")
        else:
            results["errors"].append(f"{skill} (invalid)")
    except Exception as e:
        log(f"  ✗ ERROR: {skill} - {e}", "ERROR")
        results["errors"].append(f"{skill} (exception)")

# 2. In beiden - prüfe Änderungen
log("\n[PHASE 2] Prüfe existierende Skills auf Änderungen")
log("-" * 40)

in_both = sorted(clawhub_skills & git_skills)
for skill in in_both:
    try:
        c_mtime = file_mtime(CLAWHUB_DIR / skill)
        g_mtime = file_mtime(GIT_DIR / skill)
        diff = c_mtime - g_mtime

        if abs(diff) > 60:
            if diff > 0:
                log(f"→ {skill}: ClawHub neuer (+{diff:.0f}s) → sync zu Git")
                if sync_to_git(skill, dry_run=False):
                    git_path = GIT_DIR / skill
                    os.chdir(git_path)
                    os.system('git add . -f 2>/dev/null')
                    dt = datetime.now().strftime("%Y-%m-%d %H:%M")
                    os.system(f'git commit -m "Sync from ClawHub: {dt}" -q 2>/dev/null')
                    results["synced_to_git"].append(skill)
                else:
                    results["errors"].append(f"{skill} (update failed)")
            else:
                log(f"→ {skill}: Git neuer (+{abs(diff):.0f}s) → sync zu ClawHub")
                if sync_to_clawhub(skill, dry_run=False):
                    results["synced_to_clawhub"].append(skill)
                else:
                    results["errors"].append(f"{skill} (update failed)")
        else:
            results["up_to_date"].append(skill)
    except Exception as e:
        log(f"  ✗ ERROR: {skill} - {e}", "ERROR")
        results["errors"].append(f"{skill} (exception)")

# ZUSAMMENFASSUNG
log("\n" + "="*70)
log("SYNCHRONISATION ABGESCHLOSSEN")
log("="*70)
log(f"Zu Git synchronisiert:     {len(results['synced_to_git'])}")
if results['synced_to_git']:
    log(f"  {', '.join(results['synced_to_git'])}")
log(f"Zu ClawHub synchronisiert: {len(results['synced_to_clawhub'])}")
if results['synced_to_clawhub']:
    log(f"  {', '.join(results['synced_to_clawhub'])}")
log(f"Bereits aktuell:           {len(results['up_to_date'])}")
log(f"Fehler:                    {len(results['errors'])}")
if results['errors']:
    log(f"  {', '.join(results['errors'])}")
log("="*70)

# Speichere State
STATE_FILE = Path("/home/openclaw/.openclaw/workspace/db/sync_state.json")
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
state = {"last_run": datetime.now().isoformat(), "results": results}
with open(STATE_FILE, 'w') as f:
    json.dump(state, f, indent=2)
log(f"State gespeichert: {STATE_FILE}")
