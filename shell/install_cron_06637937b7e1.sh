#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "48590bfe8100d97f7cef812be065b2c69a66d6bdac254593e65f3e24c7a6ff04", "source_sha256": "77eca70a7a8f9c0ff8dc240b14d8c37999854c241e031b8167e1fcd650cbd334", "target_language": "shell"}
# install_cron.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
# auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Installiert den DB-Maintainer als Cron-Job

readonly CRON_JOB='*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1'

install() {
    local workspace="/home/openclaw/.openclaw/workspace"
    local cron_file="${workspace}/crons/db-maintainer.cron"
    local jobs_json="${workspace}/.openclaw/cron/jobs.json"
    
    # Erstelle das Cron-Verzeichnis falls es nicht existiert
    mkdir -p "$(dirname "${cron_file}")"
    
    # Schreibe den Cron-Job in die Datei
    echo "# DB Maintainer - Alle 30 Minuten" > "${cron_file}"
    echo "${CRON_JOB}" >> "${cron_file}"
    
    echo "✅ Cron-Job installiert: ${cron_file}"
    echo "   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron"
    
    # Auch in OpenClaw cron registrieren
    if [[ -f "${jobs_json}" ]]; then
        # Lese die bestehende JSON-Datei und füge den neuen Job hinzu
        local temp_jobs
        temp_jobs=$(mktemp)
        
        # Verwende jq um den JSON-Eintrag hinzuzufügen
        if command -v jq >/dev/null 2>&1; then
            jq '.["db-maintainer"] = {
                "schedule": "*/30 * * * *",
                "command": "python3 skills/db-maintainer/scripts/db_maintainer.py",
                "enabled": true
            }' "${jobs_json}" > "${temp_jobs}"
            
            # Verschiebe die aktualisierte Datei zurück
            mv "${temp_jobs}" "${jobs_json}"
        else
            # Fallback ohne jq - überschreibe mit festem JSON
            cat > "${jobs_json}" <<EOF
{
  "db-maintainer": {
    "schedule": "*/30 * * * *",
    "command": "python3 skills/db-maintainer/scripts/db_maintainer.py",
    "enabled": true
  }
}
EOF
        fi
        
        echo "✅ In OpenClaw cron registriert"
    fi
}

install "$@"
