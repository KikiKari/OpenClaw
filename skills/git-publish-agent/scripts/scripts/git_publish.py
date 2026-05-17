#!/usr/bin/env python3
"""Git Publish Agent - Automatisierte Skill-Veröffentlichung"""

import argparse
import subprocess
import json
from pathlib import Path
from datetime import datetime

SKILLS_DIR = Path.home() / ".openclaw" / "workspace" / "skills"

def git_commit(skill_path: Path, message: str = None):
    """Commit skill changes."""
    if not message:
        message = f"[skill] Auto-update {skill_path.name} - {datetime.now().isoformat()}"
    
    subprocess.run(["git", "add", str(skill_path)], cwd=SKILLS_DIR.parent)
    result = subprocess.run(
        ["git", "commit", "-m", message],
        cwd=SKILLS_DIR.parent,
        capture_output=True,
        text=True
    )
    return result.returncode == 0

def clawhub_publish(skill_name: str):
    """Publish to ClawHub."""
    skill_path = SKILLS_DIR / skill_name
    result = subprocess.run(
        ["clawhub", "publish", str(skill_path),
         "--slug", skill_name,
         "--version", "1.0.0"],
        capture_output=True,
        text=True
    )
    return result.returncode == 0, result.stdout

def batch_publish():
    """Publish all changed skills with rate limiting."""
    # Check git status
    result = subprocess.run(
        ["git", "status", "--short", str(SKILLS_DIR)],
        capture_output=True,
        text=True
    )
    
    changed = []
    for line in result.stdout.split("\n"):
        if line.strip() and "skills/" in line:
            skill = line.split("skills/")[-1].split("/")[0]
            if skill not in changed:
                changed.append(skill)
    
    print(f"Changed skills: {changed}")
    
    # Publish with delay
    for i, skill in enumerate(changed[:5]):  # Max 5 per batch
        if i > 0:
            print(f"Waiting 15min for rate limit...")
            # In real: time.sleep(900)
        
        print(f"Publishing {skill}...")
        commit_ok = git_commit(SKILLS_DIR / skill)
        if commit_ok:
            pub_ok, output = clawhub_publish(skill)
            print(f"  {'✓' if pub_ok else '✗'} {output}")

def main():
    parser = argparse.ArgumentParser(description="Git Publish Agent")
    parser.add_argument("--skill", help="Single skill to publish")
    parser.add_argument("--all", action="store_true", help="Publish all changed")
    parser.add_argument("--no-publish", action="store_true", help="Commit only")
    parser.add_argument("--message", help="Custom commit message")
    args = parser.parse_args()
    
    if args.skill:
        skill_path = SKILLS_DIR / args.skill
        if args.no_publish:
            git_commit(skill_path, args.message)
        else:
            git_commit(skill_path, args.message)
            clawhub_publish(args.skill)
    elif args.all:
        batch_publish()
    else:
        print("Use --skill <name> or --all")

if __name__ == "__main__":
    main()
