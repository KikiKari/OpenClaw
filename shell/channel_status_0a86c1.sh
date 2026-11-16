#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "2968fb73192ff3f8cfd1600efc83449a47e64900471cfb88ec4052e7484c0d8a", "source_sha256": "0a86c190e36a7131252f54b73542b2e9f42f2b23547cdb5530f47c8477226123", "target_language": "shell"}
# channel_status.py — portiert nach shell
# Quelle: python, workspace@local:skills/channel-status-agent/scripts/channel_status.py
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

declare -A NODE_NAMES=(
    ["node2"]="openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122"
    ["node3"]="openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125"
    ["node4"]="openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39"
    ["node5"]="openclaw-node5"
    ["node6"]="openclaw-node6"
)

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

    if ! result=$(timeout 10 openclaw nodes status --json 2>/dev/null); then
        echo "null"
        return
    fi

    if ! payload=$(echo "${result}" | jq -r 'if type=="object" and (.nodes|type=="array") then . else empty end' 2>/dev/null); then
        echo "null"
        return
    fi

    if [[ -z "${payload}" ]]; then
        echo "null"
        return
    fi

    declare -A states
    for node in "${!NODE_NAMES[@]}"; do
        states["${node}"]=false
    done

    while IFS= read -r item; do
        if [[ $(echo "${item}" | jq -r 'type') != "object" ]]; then
            continue
        fi

        displayName=$(echo "${item}" | jq -r '.displayName // ""' 2>/dev/null)
        nodeId=$(echo "${item}" | jq -r '.nodeId // ""' 2>/dev/null)
        remoteIp=$(echo "${item}" | jq -r '.remoteIp // ""' 2>/dev/null)
        connected=$(echo "${item}" | jq -r '.connected // false' 2>/dev/null)

        names=("${displayName,,}" "${nodeId,,}" "${remoteIp,,}")

        for node in "${!NODE_NAMES[@]}"; do
            IFS=' ' read -ra aliases <<< "${NODE_NAMES[${node}]}"
            for alias in "${aliases[@]}"; do
                for name in "${names[@]}"; do
                    if [[ "${name}" == "${alias}" ]] && [[ "${connected}" == "true" ]]; then
                        states["${node}"]=true
                        break 2
                    fi
                done
            done
        done
    done < <(echo "${payload}" | jq -c '.nodes[]' 2>/dev/null)

    states["node1"]=true  # successful Gateway status request
    for node in "${!states[@]}"; do
        echo "${node}:${states[${node}]}"
    done
}

get_system_status() {
    local timestamp
    local nodes_json
    local agents_json
    local system_json
    local states
    local names
    local node
    local name
    local status
    local cron_lines
    local df_output
    local disk_used
    local free_output
    local ram_total
    local ram_used

    timestamp=$(date -Iseconds)

    # Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    states=$(fetch_node_status)
    declare -A names=(
        ["node1"]="Gateway"
        ["node2"]="Node2"
        ["node3"]="Node3"
        ["node4"]="Redmi"
        ["node5"]="Lenovo"
        ["node6"]="Lenovo (Docker)"
    )

    nodes_json="{"
    local first=true
    for node in "${!names[@]}"; do
        name="${names[${node}]}"
        if [[ "${states}" == "null" ]]; then
            status="unknown"
        else
            status="offline"
            while IFS=':' read -r state_node state_value; do
                if [[ "${state_node}" == "${node}" ]] && [[ "${state_value}" == "true" ]]; then
                    status="online"
                    break
                fi
            done <<< "${states}"
        fi

        if [[ "${first}" == true ]]; then
            first=false
        else
            nodes_json+=","
        fi
        nodes_json+="\"${node}\":{\"name\":\"${name}\",\"status\":\"${status}\"}"
    done
    nodes_json+="}"

    # Agent-Status aus Cron
    if cron_lines=$(crontab -l 2>/dev/null | grep -v '^#' | wc -l); then
        agents_json="{\"active_crons\":${cron_lines}}"
    else
        agents_json="{\"active_crons\":\"unknown\"}"
    fi

    # System-Metriken
    system_json="{}"
    if df_output=$(df -h / 2>/dev/null); then
        while IFS= read -r line; do
            if [[ "${line}" == */* ]] && [[ "${line}" == *%* ]]; then
                disk_used=$(echo "${line}" | awk '{print $5}')
                break
            fi
        done <<< "${df_output}"
    fi

    if free_output=$(free -h 2>/dev/null); then
        while IFS= read -r line; do
            if [[ "${line}" == *"Mem:"* ]]; then
                ram_total=$(echo "${line}" | awk '{print $2}')
                ram_used=$(echo "${line}" | awk '{print $3}')
                break
            fi
        done <<< "${free_output}"
    fi

    if [[ -n "${disk_used:-}" ]] && [[ -n "${ram_total:-}" ]] && [[ -n "${ram_used:-}" ]]; then
        system_json="{\"disk_used\":\"${disk_used}\",\"ram_total\":\"${ram_total}\",\"ram_used\":\"${ram_used}\"}"
    elif [[ -n "${disk_used:-}" ]]; then
        system_json="{\"disk_used\":\"${disk_used}\"}"
    fi

    echo "{\"timestamp\":\"${timestamp}\",\"nodes\":${nodes_json},\"agents\":${agents_json},\"system\":${system_json}}"
}

format_daily_status() {
    local status="$1"
    local nodes
    local online_count
    local total_count
    local message
    local node_id
    local info_name
    local info_status
    local emoji
    local timestamp

    nodes=$(echo "${status}" | jq -r '.nodes')
    online_count=$(echo "${nodes}" | jq -r '[.[] | select(.status == "online")] | length')
    total_count=$(echo "${nodes}" | jq -r 'length')
    timestamp=$(date '+%Y-%m-%d %H:%M')

    message="📊 **Täglicher Status-Report**
🗓️ ${timestamp}

**🖥️ Nodes (${online_count}/${total_count} online):**
"

    while IFS= read -r node_id; do
        info_name=$(echo "${nodes}" | jq -r ".\"${node_id}\".name")
        info_status=$(echo "${nodes}" | jq -r ".\"${node_id}\".status")
        case "${info_status}" in
            "online") emoji="🟢" ;;
            "offline") emoji="🔴" ;;
            *) emoji="🟡" ;;
        esac
        message+="${emoji} ${info_name}: ${info_status}"
        if echo "${nodes}" | jq -r ".\"${node_id}\".reason" >/dev/null 2>&1; then
            local reason
            reason=$(echo "${nodes}" | jq -r ".\"${node_id}\".reason")
            message+=" (${reason})"
        fi
        message+=$'\n'
    done < <(echo "${nodes}" | jq -r 'keys[]')

    message+="
**🤖 Agents:**
Aktive Cron-Jobs: $(echo "${status}" | jq -r '.agents.active_crons')

"

    if echo "${status}" | jq -r '.system.disk_used' >/dev/null 2>&1; then
        message+="**💾 System:**
Disk: $(echo "${status}" | jq -r '.system.disk_used') belegt
RAM: $(echo "${status}" | jq -r '.system.ram_used') / $(echo "${status}" | jq -r '.system.ram_total')
"
    fi

    echo "${message}"
}

format_weekly_status() {
    local status="$1"
    local week_number
    local year
    local message
    local node_id
    local info_name
    local info_status

    week_number=$(date '+%V')
    year=$(date '+%Y')

    message="📈 **Wöchentlicher Report**
📅 Woche ${week_number} - ${year}

**Nodes:**"

    while IFS= read -r node_id; do
        info_name=$(echo "${status}" | jq -r ".nodes.\"${node_id}\".name")
        info_status=$(echo "${status}" | jq -r ".nodes.\"${node_id}\".status")
        message+="
- ${info_name}: ${info_status}"
    done < <(echo "${status}" | jq -r '.nodes | keys[]')

    message+=$'\n'
    echo "${message}"
}

send_to_channel() {
    local message="$1"
    local channel_type="${2:-telegram}"
    local channel_id="${3:--1002381931352}"
    local cmd
    local result

    if [[ "${channel_type}" == "telegram" ]]; then
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

    mkdir -p "$(dirname "${LOG_FILE}")"

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
            formatted_message="🚨 **ALERT**
${message:-Manual alert}"
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
