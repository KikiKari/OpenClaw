#!/bin/bash
# install_cron.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
# auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Installiert den DB-Maintainer als Cron-Job

readonly CRON_JOB='
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
'

install() {
    local workspace="/home/openclaw/.openclaw/workspace"
    local cron_file="${workspace}/crons/db-maintainer.cron"
    
    mkdir -p "$(dirname "$cron_file")"
    
    echo "$CRON_JOB" > "$cron_file"
    
    echo "✅ Cron-Job installiert: $cron_file"
    echo "   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron"
    
    # Auch in OpenClaw cron registrieren
    local jobs_json="${workspace}/.openclaw/cron/jobs.json"
    if [[ -f "$jobs_json" ]]; then
        # Temporäre Datei für JSON-Manipulation
        local temp_json
        temp_json=$(mktemp)
        
        # Erstelle aktualisiertes JSON
        jq '.["db-maintainer"] = {
            "schedule": "*/30 * * * *",
            "command": "python3 skills/db-maintainer/scripts/db_maintainer.py",
            "enabled": true
        }' "$jobs_json" > "$temp_json"
        
        # Verschiebe aktualisierte Version an Ort und Stelle
        mv "$temp_json" "$jobs_json"
        
        echo "✅ In OpenClaw cron registriert"
    fi
}

install "$@"
