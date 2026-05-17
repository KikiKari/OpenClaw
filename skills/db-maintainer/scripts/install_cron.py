#!/usr/bin/env python3
"""
Installiert den DB-Maintainer als Cron-Job
"""

import json
from pathlib import Path

CRON_JOB = """
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
""".strip()

def install():
    workspace = Path("/home/openclaw/.openclaw/workspace")
    cron_file = workspace / "crons" / "db-maintainer.cron"
    
    cron_file.parent.mkdir(exist_ok=True)
    
    with open(cron_file, 'w') as f:
        f.write(CRON_JOB)
    
    print(f"✅ Cron-Job installiert: {cron_file}")
    print("   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron")
    
    # Auch in OpenClaw cron registrieren
    jobs_json = workspace / ".openclaw" / "cron" / "jobs.json"
    if jobs_json.exists():
        with open(jobs_json, 'r') as f:
            jobs = json.load(f)
        
        jobs['db-maintainer'] = {
            'schedule': '*/30 * * * *',
            'command': 'python3 skills/db-maintainer/scripts/db_maintainer.py',
            'enabled': True
        }
        
        with open(jobs_json, 'w') as f:
            json.dump(jobs, f, indent=2)
        
        print("✅ In OpenClaw cron registriert")

if __name__ == "__main__":
    install()
