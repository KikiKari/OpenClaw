#!/usr/bin/env python3
"""
ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync
"""
import sys
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git, sync_to_clawhub, log, validate_skill
from pathlib import Path
from datetime import datetime
import os
import json
import shutil

CLAWHUB_DIR = Path('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Path('/home/openclaw/.openclaw/workspace/git/skills')
LOG_FILE = Path('/home/openclaw/.openclaw/workspace/logs/sync-agent.log')

def file_mtime(path):
    try:
        files = [p for p in path.rglob('*') if p.is_file() and '.git' not in str(p)]
        return max(p.stat().st_mtime for p in files) if files else 0
    except:
        return 0

def write_to_log(message, level="INFO"):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    entry = f"[{timestamp}] [{level}] {message}"
    print(entry)
    with open(LOG_FILE, 'a') as f:
        f.write(entry + '\n')

# Hauptlog-Funktion überschreiben
import sync_clawhub_git
sync_clawhub_git.log = write_to_log

write_to_log("="*70)
write_to_log("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF")
write_to_log(f"Zeitstempel: {datetime.now().isoformat()}")
write_to_log("="*70)

clawhub_skills = {d.name for d in CLAWHUB_DIR.iterdir() if d.is_dir() and not d.name.startswith('.')}
git_skills = {d.name for d in GIT_DIR.iterdir() if d.is_dir() and not d.name.startswith('.')}

# DRY-RUN: Erkenne Änderungen
write_to_log("\n[DRY-RUN] Analysiere Änderungen...")

changes_detected = {
    "new_in_clawhub": [],
    "new_in_git": [],
    "clawhub_newer": [],
    "git_newer": [],
    "synced": []
}

# 1. Neue Skills
new_in_clawhub = sorted(clawhub_skills - git_skills)
new_in_git = sorted(git_skills - clawhub_skills)
changes_detected["new_in_clawhub"] = new_in_clawhub
changes_detected["new_in_git"] = new_in_git

# 2. Existierende prüfen
in_both = sorted(clawhub_skills & git_skills)
for skill in in_both:
    c_mtime = file_mtime(CLAWHUB_DIR / skill)
    g_mtime = file_mtime(GIT_DIR / skill)
    diff = c_mtime - g_mtime
    
    if abs(diff) > 60:
        if diff > 0:
            changes_detected["clawhub_newer"].append((skill, diff))
        else:
            changes_detected["git_newer"].append((skill, abs(diff)))
    else:
        changes_detected["synced"].append(skill)

# Report
total_changes = len(new_in_clawhub) + len(new_in_git) + len(changes_detected["clawhub_newer"]) + len(changes_detected["git_newer"])
write_to_log(f"Neu in ClawHub: {len(new_in_clawhub)}")
write_to_log(f"Neu in Git: {len(new_in_git)}")
write_to_log(f"ClawHub neuer: {len(changes_detected['clawhub_newer'])}")
write_to_log(f"Git neuer: {len(changes_detected['git_newer'])}")
write_to_log(f"Synchron: {len(changes_detected['synced'])}")

if total_changes == 0:
    write_to_log("\n✅ Keine Änderungen erkannt. Sync nicht nötig.")
    write_to_log("="*70)
    sys.exit(0)

write_to_log(f"\n🔄 {total_changes} Änderungen erkannt - starte Synchronisation...")

# ECHTE SYNCHRONISATION
results = {"synced_to_git": [], "synced_to_clawhub": [], "up_to_date": [], "errors": []}

# 1. NEU in ClawHub → zu Git
for skill in new_in_clawhub:
    try:
        if validate_skill(CLAWHUB_DIR / skill):
            write_to_log(f"→ Synchronisiere {skill} zu Git...")
            if sync_to_git(skill, dry_run=False):
                git_path = GIT_DIR / skill
                os.chdir(git_path)
                os.system('git init -q 2>/dev/null')
                os.system('git add . -f 2>/dev/null')
                os.system(f'git commit -m "Initial: {skill}" -q 2>/dev/null')
                results["synced_to_git"].append(skill)
                write_to_log(f"  ✓ {skill} synchronisiert")
        else:
            results["errors"].append(f"{skill} (invalid)")
    except Exception as e:
        write_to_log(f"  ✗ ERROR: {skill} - {e}", "ERROR")
        results["errors"].append(f"{skill}")

# 2. NEU in Git → zu ClawHub
for skill in new_in_git:
    try:
        if validate_skill(GIT_DIR / skill):
            write_to_log(f"→ Synchronisiere {skill} zu ClawHub...")
            if sync_to_clawhub(skill, dry_run=False):
                results["synced_to_clawhub"].append(skill)
                write_to_log(f"  ✓ {skill} synchronisiert")
        else:
            results["errors"].append(f"{skill} (invalid)")
    except Exception as e:
        write_to_log(f"  ✗ ERROR: {skill} - {e}", "ERROR")
        results["errors"].append(f"{skill}")

# 3. Updates
for skill, diff in changes_detected["clawhub_newer"]:
    try:
        write_to_log(f"→ Update {skill} (ClawHub +{diff:.0f}s neuer)...")
        if sync_to_git(skill, dry_run=False):
            git_path = GIT_DIR / skill
            os.chdir(git_path)
            os.system('git add . -f 2>/dev/null')
            dt = datetime.now().strftime("%Y-%m-%d %H:%M")
            os.system(f'git commit -m "Sync from ClawHub: {dt}" -q 2>/dev/null')
            results["synced_to_git"].append(skill)
            write_to_log(f"  ✓ {skill} aktualisiert")
    except Exception as e:
        write_to_log(f"  ✗ ERROR: {skill} - {e}", "ERROR")
        results["errors"].append(f"{skill}")

for skill, diff in changes_detected["git_newer"]:
    try:
        write_to_log(f"→ Update {skill} (Git +{diff:.0f}s neuer)...")
        if sync_to_clawhub(skill, dry_run=False):
            results["synced_to_clawhub"].append(skill)
            write_to_log(f"  ✓ {skill} aktualisiert")
    except Exception as e:
        write_to_log(f"  ✗ ERROR: {skill} - {e}", "ERROR")
        results["errors"].append(f"{skill}")

results["up_to_date"] = changes_detected["synced"]

# ZUSAMMENFASSUNG
write_to_log("\n" + "="*70)
write_to_log("SYNCHRONISATION ABGESCHLOSSEN")
write_to_log("="*70)
write_to_log(f"Zu Git synchronisiert:     {len(results['synced_to_git'])}")
write_to_log(f"Zu ClawHub synchronisiert: {len(results['synced_to_clawhub'])}")
write_to_log(f"Bereits aktuell:           {len(results['up_to_date'])}")
write_to_log(f"Fehler:                    {len(results['errors'])}")
if results['errors']:
    write_to_log(f"  Fehlerhafte: {', '.join(results['errors'])}")
write_to_log("="*70)

# State speichern
STATE_FILE = Path("/home/openclaw/.openclaw/workspace/db/sync_state.json")
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
state = {
    "last_run": datetime.now().isoformat(),
    "results": results,
    "changes_detected": {k: len(v) if isinstance(v, list) else v for k, v in changes_detected.items()}
}
with open(STATE_FILE, 'w') as f:
    json.dump(state, f, indent=2)
write_to_log(f"State gespeichert: {STATE_FILE}")
