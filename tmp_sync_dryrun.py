import sys
from pathlib import Path
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git, sync_to_clawhub, log, validate_skill
CLAWHUB_DIR = Path('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Path('/home/openclaw/.openclaw/workspace/git/skills')

def dry_run_skill(skill_name):
    claw_path = CLAWHUB_DIR / skill_name
    git_path = GIT_DIR / skill_name
    if claw_path.exists() and not git_path.exists():
        sync_to_git(skill_name, dry_run=True)
    elif git_path.exists() and not claw_path.exists():
        sync_to_clawhub(skill_name, dry_run=True)
    else:
        # Both exist: just report potential diff via sync_to_git dry-run (which will compare files)
        sync_to_git(skill_name, dry_run=True)
        sync_to_clawhub(skill_name, dry_run=True)

all_skills = set(d.name for d in CLAWHUB_DIR.iterdir() if d.is_dir()) | set(d.name for d in GIT_DIR.iterdir() if d.is_dir())
for s in sorted(all_skills):
    try:
        dry_run_skill(s)
    except Exception as e:
        log(f'DRY-RUN ERROR for {s}: {e}', 'ERROR')
