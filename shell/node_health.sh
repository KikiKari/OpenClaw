#!/bin/bash
# node_health.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node Health Monitor - Multi-Node Gesundheitsüberwachung

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly HEALTH_DB="${WORKSPACE}/db/health.db"
readonly LOG_FILE="${WORKSPACE}/logs/node-health.log"

# Node-Definitionen
declare -A NODES=(
    ["node1"]="Gateway|localhost|openclaw|critical"
    ["node2"]="Worker|100.92.155.34|root|ssh_key:~/.ssh/id_rsa"
    ["node3"]="Relay|185.242.xxx.xxx|root|disk_warning:85"
    ["node5"]="Redmi|192.168.1.x|openclaw|optional"
)

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

check_ping() {
    local host="$1"
    local timeout="${2:-5}"
    
    if ping -c 1 -W "${timeout}" "${host}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_ssh() {
    local host="$1"
    local user="$2"
    
    local cmd=(ssh -o ConnectTimeout=10 -o BatchMode=yes "${user}@${host}" echo "OK")
    
    if output=$("${cmd[@]}" 2>/dev/null) && [[ "${output}" == *"OK"* ]]; then
        return 0
    else
        return 1
    fi
}

get_node_metrics() {
    local host="$1"
    local user="$2"
    local node_name="$3"
    
    # Default Werte
    local cpu=""
    local ram=""
    local disk=""
    local load=""
    local gateway_status=""
    local available=false
    
    # SSH-Command für alle Metriken
    local cmd
    cmd=$(cat <<EOF
ssh -o ConnectTimeout=10 ${user}@${host} '
    # CPU
    echo "CPU:\$(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%" -f1)"
    
    # RAM
    echo "RAM:\$(free | grep Mem | awk "{print (\$3/\$2) * 100.0}")"
    
    # Disk
    echo "DISK:\$(df -h / | tail -1 | awk "{print \$5}" | tr -d "%")"
    
    # Load
    echo "LOAD:\$(uptime | awk -F"load average:" "{print \$2}" | awk "{print \$1}" | tr -d ",")"
    
    # Gateway Status
    if command -v openclaw >/dev/null 2>&1; then
        systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
    fi
'
EOF
)
    
    local result
    if result=$(timeout 15 bash -c "${cmd}" 2>/dev/null); then
        available=true
        
        while IFS= read -r line; do
            if [[ "${line}" == *":"* ]]; then
                local key="${line%%:*}"
                local value="${line#*:}"
                
                case "${key}" in
                    "CPU") cpu="${value}" ;;
                    "RAM") ram="${value}" ;;
                    "DISK") disk="${value}" ;;
                    "LOAD") load="${value}" ;;
                    "GATEWAY") gateway_status="${value}" ;;
                esac
            fi
        done <<< "${result}"
    else
        log "SSH timeout for ${node_name}" "WARN"
    fi
    
    # Ergebnis als JSON-ähnlichen String zurückgeben
    echo "available:${available}|cpu:${cpu}|ram:${ram}|disk:${disk}|load:${load}|gateway_status:${gateway_status}"
}

check_alerts() {
    local node_id="$1"
    local node_name="$2"
    local node_config="$3"
    local metrics_str="$4"
    
    # Metriken parsen
    local available=false
    local cpu=""
    local ram=""
    local disk=""
    local load=""
    local gateway_status=""
    
    IFS='|' read -ra METRICS <<< "${metrics_str}"
    for metric in "${METRICS[@]}"; do
        IFS=':' read -r key value <<< "${metric}"
        case "${key}" in
            "available") available="${value}" ;;
            "cpu") cpu="${value}" ;;
            "ram") ram="${value}" ;;
            "disk") disk="${value}" ;;
            "load") load="${value}" ;;
            "gateway_status") gateway_status="${value}" ;;
        esac
    done
    
    local alerts=()
    
    # Verfügbarkeit
    if [[ "${available}" != "true" ]]; then
        if [[ "${node_config}" != *"optional"* ]]; then
            alerts+=("CRITICAL:Node ${node_name} nicht erreichbar!")
        fi
    else
        # CPU
        if [[ -n "${cpu}" ]] && (( $(echo "${cpu} > 90" | bc -l) )); then
            alerts+=("WARNING:Node ${node_name}: CPU bei ${cpu}%")
        fi
        
        # RAM
        if [[ -n "${ram}" ]] && (( $(echo "${ram} > 90" | bc -l) )); then
            alerts+=("WARNING:Node ${node_name}: RAM bei ${ram}%")
        fi
        
        # Disk
        local disk_threshold=85
        if [[ "${node_config}" == *"disk_warning:"* ]]; then
            disk_threshold=$(echo "${node_config}" | grep -o "disk_warning:[0-9]*" | cut -d':' -f2)
        fi
        
        if [[ -n "${disk}" ]] && (( disk > disk_threshold )); then
            local level="WARNING"
            if (( disk > 95 )); then
                level="CRITICAL"
            fi
            alerts+=("${level}:Node ${node_name}: Disk bei ${disk}%")
        fi
        
        # Gateway
        if [[ "${node_config}" == *"critical"* ]] && [[ "${gateway_status}" == "inactive" ]]; then
            alerts+=("CRITICAL:Node ${node_name}: OpenClaw Gateway nicht aktiv!")
        fi
    fi
    
    # Alerts als Array zurückgeben
    printf '%s\n' "${alerts[@]}"
}

send_alert() {
    local alert_msg="$1"
    
    local level="${alert_msg%%:*}"
    local message="${alert_msg#*:}"
    
    local cmd=(
        python3
        "${WORKSPACE}/skills/channel-status-agent/scripts/channel_status.py"
        --type alert
        --message "${level}: ${message}"
    )
    
    if "${cmd[@]}" >/dev/null 2>&1; then
        log "Alert sent: ${message}"
    else
        log "Failed to send alert: ${message}" "ERROR"
    fi
}

main() {
    local node_arg="all"
    local check_arg="all"
    local alert_flag=false
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --node)
                node_arg="$2"
                shift 2
                ;;
            --check)
                check_arg="$2"
                shift 2
                ;;
            --alert)
                alert_flag=true
                shift
                ;;
            *)
                echo "Unbekanntes Argument: $1" >&2
                exit 1
                ;;
        esac
    done
    
    # Nodes bestimmen
    local nodes_to_check=()
    if [[ "${node_arg}" == "all" ]]; then
        for node_id in "${!NODES[@]}"; do
            nodes_to_check+=("${node_id}")
        done
    else
        if [[ -n "${NODES[${node_arg}]+isset}" ]]; then
            nodes_to_check+=("${node_arg}")
        else
            log "Unknown node: ${node_arg}" "ERROR"
            exit 1
        fi
    fi
    
    # Health-Checks durchführen
    local all_alerts=()
    
    for node_id in "${nodes_to_check[@]}"; do
        IFS='|' read -r node_name host user node_config <<< "${NODES[${node_id}]}"
        log "Checking ${node_name} (${node_id})"
        
        # Ping
        if [[ "${check_arg}" == "ping" || "${check_arg}" == "all" ]]; then
            if [[ "${host}" != "localhost" ]]; then
                if check_ping "${host}"; then
                    log "  Ping: OK"
                else
                    log "  Ping: FAILED"
                fi
            fi
        fi
        
        # SSH
        if [[ "${check_arg}" == "ssh" || "${check_arg}" == "all" ]]; then
            if check_ssh "${host}" "${user}"; then
                log "  SSH: OK"
            else
                log "  SSH: FAILED"
            fi
        fi
        
        # Metriken
        if [[ "${check_arg}" == "metrics" || "${check_arg}" == "all" ]]; then
            local metrics
            metrics=$(get_node_metrics "${host}" "${user}" "${node_name}")
            
            # Metriken parsen für Logging
            local available=false
            local cpu=""
            local ram=""
            local disk=""
            local load=""
            
            IFS='|' read -ra METRIC_ARRAY <<< "${metrics}"
            for metric in "${METRIC_ARRAY[@]}"; do
                IFS=':' read -r key value <<< "${metric}"
                case "${key}" in
                    "available") available="${value}" ;;
                    "cpu") cpu="${value}" ;;
                    "ram") ram="${value}" ;;
                    "disk") disk="${value}" ;;
                    "load") load="${value}" ;;
                esac
            done
            
            if [[ "${available}" == "true" ]]; then
                if [[ -n "${cpu}" ]]; then
                    log "  CPU: ${cpu}%"
                else
                    log "  CPU: N/A"
                fi
                
                if [[ -n "${ram}" ]]; then
                    log "  RAM: ${ram}%"
                else
                    log "  RAM: N/A"
                fi
                
                if [[ -n "${disk}" ]]; then
                    log "  Disk: ${disk}%"
                else
                    log "  Disk: N/A"
                fi
                
                if [[ -n "${load}" ]]; then
                    log "  Load: ${load}"
                else
                    log "  Load: N/A"
                fi
            else
                log "  Metrics: UNAVAILABLE"
            fi
            
            # Alerts prüfen
            local node_alerts
            mapfile -t node_alerts < <(check_alerts "${node_id}" "${node_name}" "${node_config}" "${metrics}")
            all_alerts+=("${node_alerts[@]}")
        fi
    done
    
    # Alerts senden
    if [[ "${alert_flag}" == true ]] && [[ ${#all_alerts[@]} -gt 0 ]]; then
        log $'\n'"Sending ${#all_alerts[@]} alerts..."
        for alert in "${all_alerts[@]}"; do
            send_alert "${alert}"
        done
    elif [[ ${#all_alerts[@]} -gt 0 ]]; then
        log $'\n'"${#all_alerts[@]} alerts found (use --alert to send)"
    else
        log $'\n'"All nodes healthy!"
    fi
}

main "$@"
