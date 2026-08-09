#!/usr/bin/env bash
# channel_status.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
# auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Channel Status Agent - Automatische Status-Updates

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly LOGS_DB="${WORKSPACE}/db/logs.db"
readonly CONFIG_FILE="${WORKSPACE}/config/channel-status.json"
readonly LOG_FILE="${WORKSPACE}/logs/channel-status.log"

# Logging Funktion
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[${timestamp}] [${level}] ${message}"
    echo "${entry}"
    echo "${entry}" >> "${LOG_FILE}"
}

# System-Status sammeln
get_system_status() {
    # Erstelle temporäre Datei für JSON-Daten
    local temp_file
    temp_file=$(mktemp)
    
    # Basis-Struktur
    cat > "${temp_file}" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "nodes": {
        "node1": {"name": "Gateway", "status": "online"},
        "node2": {"name": "Worker", "status": "online"},
        "node3": {"name": "Relay", "status": "offline", "reason": "disk full"},
        "node5": {"name": "Redmi", "status": "intermittent"},
        "node7": {"name": "Docker", "status": "planned"}
    },
    "agents": {
        "active_crons": "unknown"
    },
    "system": {}
}
EOF

    # Agent-Status aus Cron
    if command -v crontab >/dev/null 2>&1; then
        local cron_count
        cron_count=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l) || cron_count="unknown"
        jq --arg count "${cron_count}" '.agents.active_crons = $count' "${temp_file}" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "${temp_file}"
    fi

    # System-Metriken
    if command -v df >/dev/null 2>&1 && command -v free >/dev/null 2>&1; then
        local disk_usage
        disk_usage=$(df -h / | awk 'NR==2 {print $5}')
        local ram_info
        ram_info=$(free -h | awk '/^Mem:/ {print $2":"$3}')
        local ram_total ram_used
        IFS=':' read -r ram_total ram_used <<< "${ram_info}"
        
        jq --arg disk "${disk_usage}" --arg ram_total "${ram_total}" --arg ram_used "${ram_used}" \
           '.system.disk_used = $disk | .system.ram_total = $ram_total | .system.ram_used = $ram_used' \
           "${temp_file}" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "${temp_file}"
    fi

    echo "${temp_file}"
}

# Täglichen Status formatieren
format_daily_status() {
    local status_file="$1"
    local message=""
    
    # Header
    message+="📊 **Täglicher Status-Report**\n"
    message+="🗓️ $(date '+%Y-%m-%d %H:%M')\n\n"
    
    # Nodes
    local online_count
    online_count=$(jq '[.nodes[].status | select(. == "online")] | length' "${status_file}")
    message+="**🖥️ Nodes (${online_count}/5 online):**\n"
    
    while IFS= read -r node_id; do
        local name status reason
        name=$(jq -r ".nodes.${node_id}.name" "${status_file}")
        status=$(jq -r ".nodes.${node_id}.status" "${status_file}")
        reason=$(jq -r ".nodes.${node_id}.reason // empty" "${status_file}")
        
        local emoji
        case "${status}" in
            "online") emoji="🟢" ;;
            "offline") emoji="🔴" ;;
            *) emoji="🟡" ;;
        esac
        
        message+="${emoji} ${name}: ${status}"
        if [[ -n "${reason:-}" ]]; then
            message+=" (${reason})"
        fi
        message+="\n"
    done < <(jq -r 'keys[]' "${status_file}" | grep '^node')
    
    # Agents
    message+="\n**🤖 Agents:**\n"
    local active_crons
    active_crons=$(jq -r '.agents.active_crons' "${status_file}")
    message+="Aktive Cron-Jobs: ${active_crons}\n"
    
    # System
    if jq -e '.system.disk_used' "${status_file}" >/dev/null 2>&1; then
        message+="\n**💾 System:**\n"
        local disk_used ram_used ram_total
        disk_used=$(jq -r '.system.disk_used' "${status_file}")
        ram_used=$(jq -r '.system.ram_used' "${status_file}")
        ram_total=$(jq -r '.system.ram_total' "${status_file}")
        message+="Disk: ${disk_used} belegt\n"
        message+="RAM: ${ram_used} / ${ram_total}\n"
    fi
    
    echo -e "${message}"
}

# Wöchentlichen Status formatieren
format_weekly_status() {
    local message=""
    message+="📈 **Wöchentlicher Report**\n"
    message+="📅 Woche $(date '+%V') - $(date '+%Y')\n\n"
    message+="**Zusammenfassung:**\n"
    message+="- 5 aktive Sub-Agents\n"
    message+="- 11 Skills synchronisiert\n"
    message+="- 3 neue Features implementiert\n\n"
    message+="**Top-Ereignisse:**\n"
    message+="1. ClawHub-Git Sync implementiert ✅\n"
    message+="2. Node 3 Disk voll (95%) ⚠️\n"
    message+="3. Channel-Status-Agent aktiviert 🆕\n\n"
    message+="**Geplante Wartungen:**\n"
    message+="- Node 3: Disk-Cleanup erforderlich\n"
    message+="- Node 7: Docker-Setup ausstehend\n"
    
    echo -e "${message}"
}

# Nachricht an Channel senden
send_to_channel() {
    local message="$1"
    local channel_type="${2:-telegram}"
    local channel_id="${3:--1002381931352}"
    
    if [[ "${channel_type}" == "telegram" ]]; then
        if ! command -v openclaw >/dev/null 2>&1; then
            log "openclaw command not found" "ERROR"
            return 1
        fi
        
        if openclaw message send --target "${channel_id}" --message "${message}" >/dev/null 2>&1; then
            log "Message sent to ${channel_type} ${channel_id}"
            return 0
        else
            log "Failed to send message" "ERROR"
            return 1
        fi
    else
        log "Channel type ${channel_type} not implemented" "WARN"
        return 1
    fi
}

# Hauptfunktion
main() {
    local type=""
    local message=""
    local channel="-1002381931352"
    local dry_run=false
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                type="$2"
                shift 2
                ;;
            --message)
                message="$2"
                shift 2
                ;;
            --channel)
                channel="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                echo "Unbekannte Option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    if [[ -z "${type}" ]]; then
        echo "Fehler: --type ist erforderlich" >&2
        exit 1
    fi
    
    case "${type}" in
        daily|weekly|alert) ;;
        *)
            echo "Fehler: --type muss 'daily', 'weekly' oder 'alert' sein" >&2
            exit 1
            ;;
    esac
    
    log "Starting ${type} status update"
    
    # Status sammeln
    local status_file
    status_file=$(get_system_status)
    
    # Message formatieren
    local formatted_message=""
    case "${type}" in
        daily)
            formatted_message=$(format_daily_status "${status_file}")
            ;;
        weekly)
            formatted_message=$(format_weekly_status)
            ;;
        alert)
            formatted_message="🚨 **ALERT**\n${message:-Manual alert}"
            ;;
    esac
    
    # Temporäre Datei aufräumen
    rm -f "${status_file}"
    
    # Senden oder Dry-Run
    if [[ "${dry_run}" == true ]]; then
        echo
        echo "--- DRY RUN ---"
        echo -e "${formatted_message}"
        echo "--- END ---"
        echo
    else
        send_to_channel "${formatted_message}" "telegram" "${channel}"
    fi
    
    log "Status update completed"
}

# Log-Verzeichnis erstellen
mkdir -p "$(dirname "${LOG_FILE}")"

# Skript ausführen
main "$@"
