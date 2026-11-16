#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "09719448e114a87fd97aca47d9bea1f8c6e9e314565e136cb591ded735507695", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "shell"}
# channel_status.py — portiert nach shell
# Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
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
    echo "${entry}" >> "${LOG_FILE}"
}

declare -A NODE_NAMES
NODE_NAMES[node2]="openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122"
NODE_NAMES[node3]="openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125"
NODE_NAMES[node4]="openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39"
NODE_NAMES[node5]="openclaw-node5 lenovo-node7 lenovo-node7.taild25fea.ts.net 100.103.140.35"

fetch_node_status() {
    local result
    local payload
    local states
    local item
    local names
    local node
    local aliases
    local connected
    local displayName
    local nodeId
    local remoteIp
    local output
    local i
    local j
    
    if ! result=$(timeout 10 openclaw nodes status --json 2>/dev/null); then
        echo "null"
        return
    fi
    
    if ! payload=$(echo "${result}" | jq -r '.nodes'); then
        echo "null"
        return
    fi
    
    if [[ "$(echo "${payload}" | jq 'type')" != '"array"' ]]; then
        echo "null"
        return
    fi
    
    declare -A states
    for node in node2 node3 node4 node5; do
        states[${node}]=false
    done
    
    while IFS= read -r item; do
        if [[ "$(echo "${item}" | jq 'type')" != '"object"' ]]; then
            continue
        fi
        
        displayName=$(echo "${item}" | jq -r '.displayName // ""' 2>/dev/null || echo "")
        nodeId=$(echo "${item}" | jq -r '.nodeId // ""' 2>/dev/null || echo "")
        remoteIp=$(echo "${item}" | jq -r '.remoteIp // ""' 2>/dev/null || echo "")
        
        names=()
        names+=("${displayName,,}")
        names+=("${nodeId,,}")
        names+=("${remoteIp,,}")
        
        for node in node2 node3 node4 node5; do
            if [[ -n "${NODE_NAMES[${node}]}" ]]; then
                IFS=' ' read -ra aliases <<< "${NODE_NAMES[${node}]}"
                for alias in "${aliases[@]}"; do
                    for name in "${names[@]}"; do
                        if [[ "${alias}" == "${name}" ]]; then
                            connected=$(echo "${item}" | jq -r '.connected // false' 2>/dev/null || echo "false")
                            if [[ "${connected}" == "true" ]]; then
                                states[${node}]=true
                            fi
                            break 2
                        fi
                    done
                done
            fi
        done
    done < <(echo "${payload}" | jq -c '.[]')
    
    # node1 ist immer true wenn der Gateway-Status erfolgreich abgerufen wurde
    states[node1]=true
    
    # Ausgabe als JSON-ähnliches Format
    output="{"
    for node in node1 node2 node3 node4 node5; do
        output+="\"${node}\":${states[${node}]},"
    done
    output="${output%,}}}"
    echo "${output}"
}

get_system_status() {
    local timestamp
    local nodes_json
    local agents_json
    local system_json
    local cron_lines
    local disk_used
    local ram_total
    local ram_used
    local df_output
    local free_output
    local line
    local parts
    local node
    local name
    local status
    local states
    
    timestamp=$(date -Iseconds)
    
    # Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    states=$(fetch_node_status)
    
    # Nodes Status
    nodes_json="{"
    declare -A names
    names[node1]="Gateway"
    names[node2]="Node2"
    names[node3]="Node3"
    names[node4]="Redmi"
    names[node5]="Lenovo"
    
    for node in node1 node2 node3 node4 node5; do
        name="${names[${node}]}"
        if [[ "${states}" == "null" ]]; then
            status="unknown"
        else
            if [[ "$(echo "${states}" | jq -r ".${node}")" == "true" ]]; then
                status="online"
            else
                status="offline"
            fi
        fi
        nodes_json+="\"${node}\":{\"name\":\"${name}\",\"status\":\"${status}\"},"
    done
    nodes_json="${nodes_json%,}}"
    
    # Agent-Status aus Cron
    if cron_lines=$(crontab -l 2>/dev/null | grep -v '^#' | wc -l); then
        agents_json="{\"active_crons\":${cron_lines}}"
    else
        agents_json="{\"active_crons\":\"unknown\"}"
    fi
    
    # System-Metriken
    system_json="{"
    
    # Disk usage
    if df_output=$(df -h / 2>/dev/null); then
        while IFS= read -r line; do
            if [[ "${line}" == */* ]] && [[ "${line}" == *%* ]]; then
                read -ra parts <<< "${line}"
                disk_used="${parts[4]}"
                system_json+="\"disk_used\":\"${disk_used}\","
                break
            fi
        done <<< "${df_output}"
    fi
    
    # RAM usage
    if free_output=$(free -h 2>/dev/null); then
        while IFS= read -r line; do
            if [[ "${line}" == Mem:* ]]; then
                read -ra parts <<< "${line}"
                ram_total="${parts[1]}"
                ram_used="${parts[2]}"
                system_json+="\"ram_total\":\"${ram_total}\",\"ram_used\":\"${ram_used}\","
                break
            fi
        done <<< "${free_output}"
    fi
    
    system_json="${system_json%,}}"
    
    echo "{\"timestamp\":\"${timestamp}\",\"nodes\":${nodes_json},\"agents\":${agents_json},\"system\":${system_json}}"
}

format_daily_status() {
    local status="$1"
    local nodes
    local online_count=0
    local total_nodes=0
    local message=""
    local node_id
    local name
    local status_val
    local reason
    local emoji
    local active_crons
    local disk_used
    local ram_used
    local ram_total
    local date_str
    
    date_str=$(date '+%Y-%m-%d %H:%M')
    
    nodes=$(echo "${status}" | jq -r '.nodes | to_entries[] | .key + " " + .value.name + " " + .value.status' 2>/dev/null || echo "")
    
    while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            ((total_nodes++))
            read -ra parts <<< "${line}"
            status_val="${parts[2]}"
            if [[ "${status_val}" == "online" ]]; then
                ((online_count++))
            fi
        fi
    done <<< "${nodes}"
    
    message=$'📊 **Täglicher Status-Report**\n'
    message+=$'🗓️ '"${date_str}"$'\n\n'
    message+=$'**🖥️ Nodes ('"${online_count}/${total_nodes}"$' online):**\n'
    
    while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            read -ra parts <<< "${line}"
            node_id="${parts[0]}"
            name="${parts[1]}"
            status_val="${parts[2]}"
            
            case "${status_val}" in
                "online") emoji="🟢" ;;
                "offline") emoji="🔴" ;;
                *) emoji="🟡" ;;
            esac
            
            message+="${emoji} ${name}: ${status_val}"
            
            # Prüfe auf reason (wird hier nicht verwendet, aber für Konsistenz)
            reason=$(echo "${status}" | jq -r ".nodes.${node_id}.reason" 2>/dev/null || echo "")
            if [[ "${reason}" != "null" ]] && [[ -n "${reason}" ]]; then
                message+=" (${reason})"
            fi
            
            message+=$'\n'
        fi
    done <<< "${nodes}"
    
    message+=$'\n**🤖 Agents:**\n'
    active_crons=$(echo "${status}" | jq -r '.agents.active_crons' 2>/dev/null || echo "unknown")
    message+="Aktive Cron-Jobs: ${active_crons}"$'\n'
    
    disk_used=$(echo "${status}" | jq -r '.system.disk_used // empty' 2>/dev/null || echo "")
    if [[ -n "${disk_used}" ]]; then
        message+=$'\n**💾 System:**\n'
        message+="Disk: ${disk_used} belegt"$'\n'
        ram_used=$(echo "${status}" | jq -r '.system.ram_used // empty' 2>/dev/null || echo "")
        ram_total=$(echo "${status}" | jq -r '.system.ram_total // empty' 2>/dev/null || echo "")
        if [[ -n "${ram_used}" ]] && [[ -n "${ram_total}" ]]; then
            message+="RAM: ${ram_used} / ${ram_total}"$'\n'
        fi
    fi
    
    echo -n "${message}"
}

format_weekly_status() {
    local status="$1"
    local week_number
    local year
    local nodes
    local message=""
    local line
    local parts
    local name
    local status_val
    
    week_number=$(date '+%V')
    year=$(date '+%Y')
    
    message=$'📈 **Wöchentlicher Report**\n'
    message+="📅 Woche ${week_number} - ${year}"$'\n\n'
    message+=$'**Nodes:**\n'
    
    nodes=$(echo "${status}" | jq -r '.nodes | to_entries[] | .value.name + " " + .value.status' 2>/dev/null || echo "")
    
    while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            read -ra parts <<< "${line}"
            name="${parts[0]}"
            status_val="${parts[1]}"
            message+="- ${name}: ${status_val}"$'\n'
        fi
    done <<< "${nodes}"
    
    echo -n "${message}"
}

send_to_channel() {
    local message="$1"
    local channel_type="${2:-telegram}"
    local channel_id="${3:--1002381931352}"
    local cmd
    local result
    
    if [[ "${channel_type}" == "telegram" ]]; then
        # Nutze OpenClaw message tool
        cmd=(openclaw message send --target "${channel_id}" --message "${message}")
    else
        log "Channel type ${channel_type} not implemented" "WARN"
        return 1
    fi
    
    if result=$("${cmd[@]}" 2>&1); then
        log "Message sent to ${channel_type} ${channel_id}"
        return 0
    else
        log "Failed to send: ${result}" "ERROR"
        return 1
    fi
}

main() {
    local type=""
    local message=""
    local channel="-1002381931352"
    local dry_run=false
    local status
    local formatted_message
    
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
                echo "Unbekanntes Argument: $1" >&2
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
            echo "Ungültiger Typ: ${type}" >&2
            exit 1
            ;;
    esac
    
    log "Starting ${type} status update"
    
    # Status sammeln
    status=$(get_system_status)
    
    # Message formatieren
    case "${type}" in
        daily)
            formatted_message=$(format_daily_status "${status}")
            ;;
        weekly)
            formatted_message=$(format_weekly_status "${status}")
            ;;
        alert)
            formatted_message=$'🚨 **ALERT**\n'"${message:-Manual alert}"
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

# Sicherstellen, dass das Log-Verzeichnis existiert
mkdir -p "$(dirname "${LOG_FILE}")"

# Hauptfunktion aufrufen
main "$@"
