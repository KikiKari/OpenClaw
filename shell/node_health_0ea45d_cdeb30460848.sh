#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "941bf821dfa15313ab641484bcfb0a1622be912d3745553938ea71e262d8cbbc", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "shell"}
# node_health.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node Health Monitor - Multi-Node Gesundheitsüberwachung

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly HEALTH_DB="${WORKSPACE}/db/health.db"
readonly LOG_FILE="${WORKSPACE}/logs/node-health.log"

# Node-Definitionen
declare -A NODES=(
    ["node1_name"]="Node 1"
    ["node1_host"]="localhost"
    ["node1_user"]="openclaw"
    ["node1_critical"]="true"
    
    ["node2_name"]="Node 2"
    ["node2_host"]="10.10.0.2"
    ["node2_user"]="root"
    ["node2_ssh_key"]="~/.ssh/id_rsa"
    ["node2_ssh_opts"]="-o ConnectTimeout=10 -o BatchMode=yes"
    
    ["node3_name"]="Node 3"
    ["node3_host"]="localhost"
    ["node3_user"]="root"
    ["node3_port"]="18794"
    ["node3_ssh_opts"]="-p 18794 -o ConnectTimeout=10 -o BatchMode=yes"
    ["node3_disk_warning"]="85"
    
    ["node5_name"]="Redmi"
    ["node5_host"]="192.168.1.x"
    ["node5_user"]="openclaw"
    ["node5_optional"]="true"
)

log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[${timestamp}] [${level}] ${message}"
    echo "${entry}"
    
    # Stelle sicher, dass das Log-Verzeichnis existiert
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo "${entry}" >> "${LOG_FILE}"
}

check_ping() {
    local host="$1"
    local timeout="${2:-10}"
    
    if ping -c 1 -W "${timeout}" "${host}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_ssh() {
    local node_prefix="$1"
    local host="${NODES[${node_prefix}_host]}"
    local user="${NODES[${node_prefix}_user]:-root}"
    local ssh_opts="${NODES[${node_prefix}_ssh_opts]:-}"
    local port="${NODES[${node_prefix}_port]:-}"
    
    local cmd=("ssh")
    
    if [[ -n "${ssh_opts}" ]]; then
        IFS=' ' read -ra OPTS <<< "${ssh_opts}"
        cmd+=("${OPTS[@]}")
    fi
    
    if [[ -n "${port}" ]]; then
        cmd+=("-p" "${port}")
    fi
    
    cmd+=("-o" "ConnectTimeout=10" "-o" "BatchMode=yes")
    cmd+=("${user}@${host}" "echo" '"OK"')
    
    if output=$( "${cmd[@]}" 2>/dev/null ) && [[ "${output}" == *"OK"* ]]; then
        return 0
    else
        return 1
    fi
}

get_node_metrics() {
    local node_prefix="$1"
    local host="${NODES[${node_prefix}_host]}"
    local user="${NODES[${node_prefix}_user]:-root}"
    local metrics_file
    metrics_file=$(mktemp)
    
    # SSH-Command für alle Metriken
    local cmd
    cmd=$(cat <<EOF
ssh -o ConnectTimeout=10 ${user}@${host} '
    # CPU
    echo "CPU:\$(top -bn1 | grep "Cpu(s)" | awk "{print \\\$2}" | cut -d"%" -f1)"
    
    # RAM
    echo "RAM:\$(free | grep Mem | awk "{print (\\\$3/\\\$2) * 100.0}")"
    
    # Disk
    echo "DISK:\$(df -h / | tail -1 | awk "{print \\\$5}" | tr -d "%")"
    
    # Load
    echo "LOAD:\$(uptime | awk -F"load average:" "{print \\\$2}" | awk "{print \\\$1}" | tr -d ",")"
    
    # Gateway Status
    if command -v openclaw >/dev/null 2>&1; then
        systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
    fi
'
EOF
)
    
    if output=$(eval "${cmd}" 2>/dev/null); then
        echo "available:true" > "${metrics_file}"
        while IFS= read -r line; do
            if [[ "${line}" == *":"* ]]; then
                echo "${line}" >> "${metrics_file}"
            fi
        done <<< "${output}"
    else
        echo "available:false" > "${metrics_file}"
    fi
    
    echo "${metrics_file}"
}

parse_metrics() {
    local metrics_file="$1"
    local key="$2"
    local default_value="${3:-}"
    
    if [[ -f "${metrics_file}" ]]; then
        local value
        value=$(grep "^${key}:" "${metrics_file}" | cut -d':' -f2)
        if [[ -n "${value}" ]]; then
            echo "${value}"
            return 0
        fi
    fi
    echo "${default_value}"
}

check_alerts() {
    local node_prefix="$1"
    local node_name="${NODES[${node_prefix}_name]}"
    local metrics_file="$2"
    
    local alerts_file
    alerts_file=$(mktemp)
    
    local available
    available=$(parse_metrics "${metrics_file}" "available" "false")
    
    # Verfügbarkeit
    if [[ "${available}" != "true" ]]; then
        local optional="${NODES[${node_prefix}_optional]:-false}"
        if [[ "${optional}" != "true" ]]; then
            echo "CRITICAL|Node ${node_name} nicht erreichbar!" >> "${alerts_file}"
        fi
    else
        # CPU
        local cpu
        cpu=$(parse_metrics "${metrics_file}" "CPU")
        if [[ -n "${cpu}" ]] && (( $(echo "${cpu} > 90" | bc -l) )); then
            echo "WARNING|Node ${node_name}: CPU bei ${cpu}%" >> "${alerts_file}"
        fi
        
        # RAM
        local ram
        ram=$(parse_metrics "${metrics_file}" "RAM")
        if [[ -n "${ram}" ]] && (( $(echo "${ram} > 90" | bc -l) )); then
            echo "WARNING|Node ${node_name}: RAM bei ${ram}%" >> "${alerts_file}"
        fi
        
        # Disk
        local disk
        disk=$(parse_metrics "${metrics_file}" "DISK")
        local disk_threshold="${NODES[${node_prefix}_disk_warning]:-85}"
        if [[ -n "${disk}" ]] && (( disk > disk_threshold )); then
            local level="WARNING"
            if (( disk > 95 )); then
                level="CRITICAL"
            fi
            echo "${level}|Node ${node_name}: Disk bei ${disk}%" >> "${alerts_file}"
        fi
        
        # Gateway
        local critical="${NODES[${node_prefix}_critical]:-false}"
        local gateway_status
        gateway_status=$(parse_metrics "${metrics_file}" "GATEWAY")
        if [[ "${critical}" == "true" ]] && [[ "${gateway_status}" == "inactive" ]]; then
            echo "CRITICAL|Node ${node_name}: OpenClaw Gateway nicht aktiv!" >> "${alerts_file}"
        fi
    fi
    
    echo "${alerts_file}"
}

send_alert() {
    local alert_line="$1"
    local level
    local message
    level=$(echo "${alert_line}" | cut -d'|' -f1)
    message=$(echo "${alert_line}" | cut -d'|' -f2)
    
    if command -v python3 >/dev/null 2>&1; then
        local script="${WORKSPACE}/skills/channel-status-agent/scripts/channel_status.py"
        if [[ -f "${script}" ]]; then
            python3 "${script}" --type alert --message "${level}: ${message}" 2>/dev/null || true
            log "Alert sent: ${message}"
        else
            log "Alert script not found: ${script}" "ERROR"
        fi
    else
        log "Python3 not available for sending alert" "ERROR"
    fi
}

main() {
    local node="all"
    local check="all"
    local alert_flag=""
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --node)
                node="$2"
                shift 2
                ;;
            --check)
                check="$2"
                shift 2
                ;;
            --alert)
                alert_flag="true"
                shift
                ;;
            *)
                log "Unbekannte Option: $1" "ERROR"
                exit 1
                ;;
        esac
    done
    
    # Nodes bestimmen
    local nodes_to_check=()
    if [[ "${node}" == "all" ]]; then
        nodes_to_check=("node1" "node2" "node3" "node5")
    else
        case "${node}" in
            node1|node2|node3|node5)
                nodes_to_check=("${node}")
                ;;
            *)
                log "Unknown node: ${node}" "ERROR"
                exit 1
                ;;
        esac
    fi
    
    # Health-Checks durchführen
    local all_alerts_file
    all_alerts_file=$(mktemp)
    
    for node_prefix in "${nodes_to_check[@]}"; do
        if [[ ! -v NODES["${node_prefix}_name"] ]]; then
            continue
        fi
        
        local node_name="${NODES[${node_prefix}_name]}"
        log "Checking ${node_name} (${node_prefix})"
        
        # Ping
        if [[ "${check}" == "ping" ]] || [[ "${check}" == "all" ]]; then
            local host="${NODES[${node_prefix}_host]}"
            if [[ "${host}" != "localhost" ]]; then
                if check_ping "${host}"; then
                    log "  Ping: OK"
                else
                    log "  Ping: FAILED"
                fi
            fi
        fi
        
        # SSH
        if [[ "${check}" == "ssh" ]] || [[ "${check}" == "all" ]]; then
            if check_ssh "${node_prefix}"; then
                log "  SSH: OK"
            else
                log "  SSH: FAILED"
            fi
        fi
        
        # Metriken
        if [[ "${check}" == "metrics" ]] || [[ "${check}" == "all" ]]; then
            local metrics_file
            metrics_file=$(get_node_metrics "${node_prefix}")
            
            local available
            available=$(parse_metrics "${metrics_file}" "available" "false")
            
            if [[ "${available}" == "true" ]]; then
                local cpu ram disk load
                cpu=$(parse_metrics "${metrics_file}" "CPU")
                ram=$(parse_metrics "${metrics_file}" "RAM")
                disk=$(parse_metrics "${metrics_file}" "DISK")
                load=$(parse_metrics "${metrics_file}" "LOAD")
                
                log "  CPU: ${cpu:-N/A}"
                log "  RAM: ${ram:-N/A}"
                log "  Disk: ${disk:-N/A}"
                log "  Load: ${load:-N/A}"
            else
                log "  Metrics: UNAVAILABLE"
            fi
            
            # Alerts prüfen
            local node_alerts_file
            node_alerts_file=$(check_alerts "${node_prefix}" "${metrics_file}")
            if [[ -s "${node_alerts_file}" ]]; then
                cat "${node_alerts_file}" >> "${all_alerts_file}"
            fi
            
            # Temporäre Dateien aufräumen
            rm -f "${metrics_file}" "${node_alerts_file}"
        fi
    done
    
    # Alerts senden
    if [[ -n "${alert_flag}" ]] && [[ -s "${all_alerts_file}" ]]; then
        local count
        count=$(wc -l < "${all_alerts_file}" | tr -d ' ')
        log "\nSending ${count} alerts..."
        while IFS= read -r alert; do
            send_alert "${alert}"
        done < "${all_alerts_file}"
    elif [[ -s "${all_alerts_file}" ]]; then
        local count
        count=$(wc -l < "${all_alerts_file}" | tr -d ' ')
        log "\n${count} alerts found (use --alert to send)"
    else
        log "\nAll nodes healthy!"
    fi
    
    # Temporäre Datei aufräumen
    rm -f "${all_alerts_file}"
}

# Skript ausführen
main "$@"
