#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "8a3d72a217be8ac388dbe8135b9519875df400a61fe8a6499640f1ffa9f2cb62", "source_sha256": "705cb2cc5900c507db1038d107f06e2f8452a95c37d0611cd27dfe2ed61dd498", "target_language": "shell"}
# channel_status.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
# auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Channel Status Agent - Automatische Status-Updates

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly LOGS_DB="${WORKSPACE}/db/logs.db"
readonly CONFIG_FILE="${WORKSPACE}/config/channel-status.json"
readonly LOG_FILE="${WORKSPACE}/logs/channel-status.log"

log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[${timestamp}] [${level}] ${message}"
    echo "${entry}"
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo "${entry}" >> "${LOG_FILE}"
}

get_system_status() {
    # Sammelt System-Status und gibt JSON-ähnlichen String zurück
    local timestamp
    timestamp=$(date -Iseconds)
    
    cat <<EOF
{
  "timestamp": "${timestamp}",
  "nodes": {
    "node1": {"name": "Gateway", "status": "online"},
    "node2": {"name": "Worker", "status": "online"},
    "node3": {"name": "Relay", "status": "offline", "reason": "disk full"},
    "node5": {"name": "Redmi", "status": "intermittent"},
    "node7": {"name": "Docker", "status": "planned"}
  },
  "agents": {},
  "system": {}
}
EOF
}

add_agent_status() {
    local status_json="$1"
    # Agent-Status aus Cron
    local active_crons
    active_crons="unknown"
    if active_crons_count=$(crontab -l 2>/dev/null | grep -v '^#' | wc -l); then
        active_crons="${active_crons_count}"
    fi
    
    # Füge active_crons zum JSON hinzu
    echo "${status_json}" | sed "/\"agents\": {}/c\\
  \"agents\": {\"active_crons\": \"${active_crons}\"},
"
}

add_system_metrics() {
    local status_json="$1"
    # System-Metriken
    local disk_used=""
    local ram_total=""
    local ram_used=""
    
    # Disk usage
    if command -v df >/dev/null; then
        disk_used=$(df -h / | awk 'NR==2 {print $5}')
    fi
    
    # RAM usage
    if command -v free >/dev/null; then
        read -r ram_total ram_used < <(free -h | awk '/^Mem:/ {print $2, $3}')
    fi
    
    # Füge Systemmetriken hinzu
    local system_section=""
    if [[ -n "${disk_used}" ]]; then
        system_section+="\"disk_used\": \"${disk_used}\""
    fi
    if [[ -n "${ram_total}" && -n "${ram_used}" ]]; then
        if [[ -n "${system_section}" ]]; then
            system_section+=", "
        fi
        system_section+="\"ram_total\": \"${ram_total}\", \"ram_used\": \"${ram_used}\""
    fi
    
    if [[ -n "${system_section}" ]]; then
        echo "${status_json}" | sed "/\"system\": {}/c\\
  \"system\": {${system_section}},
"
    else
        echo "${status_json}"
    fi
}

format_daily_status() {
    local status_json="$1"
    local date_str
    date_str=$(date '+%Y-%m-%d %H:%M')
    
    # Extrahiere Knoteninformationen mit jq-ähnlicher Logik über sed/awk
    local nodes_section=""
    nodes_section=$(echo "${status_json}" | sed -n '/"nodes": {/,/},/p' | head -n -1 | tail -n +2)
    
    # Zähle Online-Knoten
    local online_count=0
    local node_entries=()
    while IFS= read -r line; do
        if [[ $line =~ \"node[0-9]+\" ]]; then
            local node_line="$line"
            local node_name=""
            local node_status=""
            local node_reason=""
            
            # Extrahiere Name
            if [[ $node_line =~ \"name\":\ \"([^\"]+)\" ]]; then
                node_name="${BASH_REMATCH[1]}"
            fi
            
            # Extrahiere Status
            if [[ $node_line =~ \"status\":\ \"([^\"]+)\" ]]; then
                node_status="${BASH_REMATCH[1]}"
            fi
            
            # Extrahiere Grund (falls vorhanden)
            if [[ $node_line =~ \"reason\":\ \"([^\"]+)\" ]]; then
                node_reason="${BASH_REMATCH[1]}"
            fi
            
            local emoji=""
            case "${node_status}" in
                "online") 
                    emoji="🟢"
                    ((online_count++))
                    ;;
                "offline") 
                    emoji="🔴"
                    ;;
                *) 
                    emoji="🟡"
                    ;;
            esac
            
            local entry="${emoji} ${node_name}: ${node_status}"
            if [[ -n "${node_reason}" ]]; then
                entry+=" (${node_reason})"
            fi
            node_entries+=("${entry}")
        fi
    done < <(echo "${nodes_section}")

    local message=""
    message+=$'📊 **Täglicher Status-Report**\n'
    message+=$'🗓️ '"${date_str}"$'\n\n'
    message+=$'**🖥️ Nodes ('"${online_count}"$'/5 online):**\n'

    for entry in "${node_entries[@]}"; do
        message+="${entry}"$'\n'
    done

    # Agents
    message+=$'\n**🤖 Agents:**\n'
    local active_crons_val
    active_crons_val=$(echo "${status_json}" | sed -n 's/.*"active_crons": "\([^"]*\)".*/\1/p')
    message+="Aktive Cron-Jobs: ${active_crons_val}"$'\n'

    # System
    if echo "${status_json}" | grep -q '"disk_used"'; then
        message+=$'\n**💾 System:**\n'
        local disk_used_val
        disk_used_val=$(echo "${status_json}" | sed -n 's/.*"disk_used": "\([^"]*\)".*/\1/p')
        message+="Disk: ${disk_used_val} belegt"$'\n'
        
        local ram_used_val ram_total_val
        ram_used_val=$(echo "${status_json}" | sed -n 's/.*"ram_used": "\([^"]*\)".*/\1/p')
        ram_total_val=$(echo "${status_json}" | sed -n 's/.*"ram_total": "\([^"]*\)".*/\1/p')
        message+="RAM: ${ram_used_val} / ${ram_total_val}"$'\n'
    fi

    echo -e "${message}"
}

format_weekly_status() {
    local week_num
    week_num=$(date '+%V')
    local year
    year=$(date '+%Y')
    
    cat <<EOF
📈 **Wöchentlicher Report**
📅 Woche ${week_num} - ${year}

**Zusammenfassung:**
- 5 aktive Sub-Agents
- 11 Skills synchronisiert
- 3 neue Features implementiert

**Top-Ereignisse:**
1. ClawHub-Git Sync implementiert ✅
2. Node 3 Disk voll (95%) ⚠️
3. Channel-Status-Agent aktiviert 🆕

**Geplante Wartungen:**
- Node 3: Disk-Cleanup erforderlich
- Node 7: Docker-Setup ausstehend
EOF
}

send_to_channel() {
    local message="$1"
    local channel_type="${2:-telegram}"
    local channel_id="${3:--1002381931352}"
    
    if [[ "${channel_type}" == "telegram" ]]; then
        # Nutze OpenClaw message tool
        if command -v openclaw >/dev/null; then
            if echo "${message}" | openclaw message send --target "${channel_id}" --message /dev/stdin; then
                log "Message sent to ${channel_type} ${channel_id}"
                return 0
            else
                log "Failed to send message" "ERROR"
                return 1
            fi
        else
            log "openclaw command not found" "ERROR"
            return 1
        fi
    else
        log "Channel type ${channel_type} not implemented" "WARN"
        return 1
    fi
}

main() {
    local type=""
    local message=""
    local channel="-1002381931352"
    local dry_run=false
    
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
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    if [[ -z "${type}" ]]; then
        echo "Error: --type is required" >&2
        exit 1
    fi
    
    log "Starting ${type} status update"
    
    # Status sammeln
    local status
    status=$(get_system_status)
    status=$(add_agent_status "${status}")
    status=$(add_system_metrics "${status}")
    
    # Message formatieren
    local formatted_message=""
    case "${type}" in
        daily)
            formatted_message=$(format_daily_status "${status}")
            ;;
        weekly)
            formatted_message=$(format_weekly_status)
            ;;
        alert)
            formatted_message=$'🚨 **ALERT**\n'"${message:-Manual alert}"
            ;;
        *)
            echo "Invalid type: ${type}" >&2
            exit 1
            ;;
    esac
    
    # Senden oder Dry-Run
    if [[ "${dry_run}" == true ]]; then
        echo
        echo "--- DRY RUN ---"
        echo "${formatted_message}"
        echo "--- END ---"
        echo
    else
        send_to_channel "${formatted_message}" "telegram" "${channel}"
    fi
    
    log "Status update completed"
}

main "$@"
