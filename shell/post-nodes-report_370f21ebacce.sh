#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "7bf615ead4a4ebfa83e3e95406d902d6f6218178ae73cb46ef59ed9433ad3d9d", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "shell"}
# post-nodes-report.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Pfade
DASHBOARD_PATH="../dashboards/nodes-overview.md"
REPORT_LOG="../logs/nodes-report.log"

# Farbcodes
C_green='\033[32m'
C_yellow='\033[33m'
C_red='\033[31m'
C_reset='\033[0m'

function postReport() {
    local content
    if ! content=$(cat "$DASHBOARD_PATH" 2>&1); then
        echo -e "${C_red}❌ Fehler beim Lesen der Dashboard-Datei:${C_reset} $content" >&2
        return 1
    fi

    # Nachricht über OpenClaw message senden
    local escaped_content
    escaped_content=$(printf '%s' "$content" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    local message_cmd="openclaw message send --target=main --message \"$escaped_content\""

    if output=$(eval "$message_cmd" 2>&1); then
        echo -e "${C_green}✅ Report erfolgreich im 'main'-Channel gepostet.${C_reset}"
        printf "[%s] Report posted.\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$REPORT_LOG"
    else
        echo -e "${C_red}❌ Fehler beim Senden der Nachricht:${C_reset} $output" >&2
        printf "[%s] Failed to post: %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$output" >> "$REPORT_LOG"
        return 1
    fi
}

# Hauptausführung
echo -e "${C_yellow}📤 Sende Nodes-Übersicht in 'main'...${C_reset}"
postReport
