#!/bin/bash
# node_health.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node Health Monitor - Multi-Node Gesundheitsüberwachung

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly HEALTH_DB="${WORKSPACE}/db/health.db"
readonly LOG_FILE="${WORKSPACE}/logs/node-health.log"

# Node-Definitionen
declare -A NODES=(
    ["node1,name"]="Node 1"
    ["node1,host"]="localhost"
    ["node1,user"]="openclaw"
    ["node1,critical"]="true"
    
    ["node2,name"]="Node 2"
    ["node2,host"]="10.10.0.2"
    ["node2,user"]="root"
    ["node2,ssh_key"]="~/.ssh/id_rsa"
    ["node2,ssh_opts"]="-o ConnectTimeout=10 -o BatchMode=yes"
    
    ["node3,name"]="Node 3"
    ["node3,host"]="localhost"
    ["node3,user"]="root"
    ["node3,port"]="18794"
    ["node3,ssh_opts"]="-p 18794 -o ConnectTimeout=10 -o BatchMode=yes"
    ["node3,disk_warning"]="85"
    
    ["node5,name"]="Redmi"
    ["node5,host"]="192.168.1.x"
    ["node5,user"]="openclaw"
    ["node5,optional"]="true"
)

# Funktion zum Extrahieren von Node-Konfigurationswerten
get_node_config() {
    local node_id="$1"
    local config_key="$2"
    echo "${NODES[${node_id},${config_key}]:-}"
}

# Logging
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

# Prüft Erreichbarkeit (Timeout seconds)
check_ping() {
    local host="$1"
    local timeout="${2:-10}"
    
    if ping -c 1 -W "${timeout}" "${host}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Prüft SSH-Verbindung
check_ssh() {
    local node_id="$1"
    local host
    host=$(get_node_config "${node_id}" "host")
    local user
    user=$(get_node_config "${node_id}" "user")
    local ssh_opts
    ssh_opts=$(get_node_config "${node_id}" "ssh_opts")
    local port
    port=$(get_node_config "${node_id}" "port")
    
    local cmd=("ssh")
    
    if [[ -n "${ssh_opts}" ]]; then
        IFS=' ' read -ra OPTS <<< "${ssh_opts}"
        cmd+=("${OPTS[@]}")
    fi
    
    if [[ -n "${port}" ]]; then
        cmd+=("-p" "${port}")
    fi
    
    cmd+=("-o" "ConnectTimeout=10" "-o" "BatchMode=yes" "${user}@${host}" "echo" "\"OK\"")
    
    if output=$("${cmd[@]}" 2>/dev/null) && [[ "${output}" == *"OK"* ]]; then
        return 0
    else
        return 1
    fi
}

# Holt Metriken via SSH
get_node_metrics() {
    local node_id="$1"
    local host
    host=$(get_node_config "${node_id}" "host")
    local user
    user=$(get_node_config "${node_id}" "user")
    
    # Initialisiere Metrikvariablen
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
    
    # Führe den Befehl aus und verarbeite die Ausgabe
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
    fi
    
    # Gebe die Metriken als JSON-ähnlichen String zurück
    echo "available:${available},cpu:${cpu},ram:${ram},disk:${disk},load:${load},gateway_status:${gateway_status}"
}

# Prüft Schwellwerte und generiert Alerts
check_alerts() {
    local node_id="$1"
    local metrics_str="$2"
    
    # Parse metrics string
    local available=false
    local cpu=""
    local ram=""
    local disk=""
    local load=""
    local gateway_status=""
    
    IFS=',' read -ra METRICS <<< "${metrics_str}"
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
        local optional
        optional=$(get_node_config "${node_id}" "optional")
        if [[ "${optional}" != "true" ]]; then
            local name
            name=$(get_node_config "${node_id}" "name")
            alerts+=("CRITICAL:Node ${name} nicht erreichbar!")
        fi
    else
        # CPU
        if [[ -n "${cpu}" ]] && (( $(echo "${cpu} > 90" | bc -l) )); then
            local name
            name=$(get_node_config "${node_id}" "name")
            alerts+=("WARNING:Node ${name}: CPU bei ${cpu}%")
        fi
        
        # RAM
        if [[ -n "${ram}" ]] && (( $(echo "${ram} > 90" | bc -l) )); then
            local name
            name=$(get_node_config "${node_id}" "name")
            alerts+=("WARNING:Node ${name}: RAM bei ${ram}%")
        fi
        
        # Disk
        local disk_warning
        disk_warning=$(get_node_config "${node_id}" "disk_warning")
        disk_warning=${disk_warning:-85}
        
        if [[ -n "${disk}" ]] && (( disk > disk_warning )); then
            local name
            name=$(get_node_config "${node_id}" "name")
            local level="WARNING"
            if (( disk > 95 )); then
                level="CRITICAL"
            fi
            alerts+=("${level}:Node ${name}: Disk bei ${disk}%")
        fi
        
        # Gateway
        local critical
        critical=$(get_node_config "${node_id}" "critical")
        if [[ "${critical}" == "true" ]] && [[ "${gateway_status}" == "inactive" ]]; then
            local name
            name=$(get_node_config "${node_id}" "name")
            alerts+=("CRITICAL:Node ${name}: OpenClaw Gateway nicht aktiv!")
        fi
    fi
    
    # Gebe Alerts zeilenweise aus
    printf '%s\n' "${alerts[@]}"
}

# Sendet Alert via channel-status-agent
send_alert() {
    local alert_msg="$1"
    local level
    level=$(echo "${alert_msg}" | cut -d':' -f1)
    local message
    message=$(echo "${alert_msg}" | cut -d':' -f2-)
    
    if command -v python3 >/dev/null 2>&1; then
        local script_path="${WORKSPACE}/skills/channel-status-agent/scripts/channel_status.py"
        if [[ -f "${script_path}" ]]; then
            python3 "${script_path}" --type alert --message "${level}: ${message}" >/dev/null 2>&1 || true
            log "Alert sent: ${message}"
        else
            log "Channel status script not found: ${script_path}" "ERROR"
        fi
    else
        log "Python3 not available to send alert" "ERROR"
    fi
}

# Hauptfunktion
main() {
    local node="all"
    local check="all"
    local alert=false
    
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
                alert=true
                shift
                ;;
            *)
                echo "Unbekannte Option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    # Bestimme zu prüfende Nodes
    local nodes_to_check=()
    
    if [[ "${node}" == "all" ]]; then
        # Sammle alle einzigartigen Node-IDs
        for key in "${!NODES[@]}"; do
            if [[ "${key}" == *",name" ]]; then
                local node_id="${key%,name}"
                nodes_to_check+=("${node_id}")
            fi
        done
    else
        # Prüfe ob Node existiert
        if [[ -n "$(get_node_config "${node}" "name")" ]]; then
            nodes_to_check=("${node}")
        else
            log "Unknown node: ${node}" "ERROR"
            exit 1
        fi
    fi
    
    # Health-Checks durchführen
    local all_alerts=()
    
    for node_id in "${nodes_to_check[@]}"; do
        local name
        name=$(get_node_config "${node_id}" "name")
        log "Checking ${name} (${node_id})"
        
        # Ping
        if [[ "${check}" == "ping" ]] || [[ "${check}" == "all" ]]; then
            local host
            host=$(get_node_config "${node_id}" "host")
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
            if check_ssh "${node_id}"; then
                log "  SSH: OK"
            else
                log "  SSH: FAILED"
            fi
        fi
        
        # Metriken
        if [[ "${check}" == "metrics" ]] || [[ "${check}" == "all" ]]; then
            local metrics
            metrics=$(get_node_metrics "${node_id}")
            
            # Parse metrics für Anzeige
            local available=false
            local cpu=""
            local ram=""
            local disk=""
            local load=""
            
            IFS=',' read -ra METRIC_ARRAY <<< "${metrics}"
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
            node_alerts=$(check_alerts "${node_id}" "${metrics}")
            if [[ -n "${node_alerts}" ]]; then
                while IFS= read -r alert_line; do
                    if [[ -n "${alert_line}" ]]; then
                        all_alerts+=("${alert_line}")
                    fi
                done <<< "${node_alerts}"
            fi
        fi
    done
    
    # Alerts senden
    if [[ "${alert}" == true ]] && [[ ${#all_alerts[@]} -gt 0 ]]; then
        log $'\n'"Sending ${#all_alerts[@]} alerts..."
        for alert_msg in "${all_alerts[@]}"; do
            send_alert "${alert_msg}"
        done
    elif [[ ${#all_alerts[@]} -gt 0 ]]; then
        log $'\n'"${#all_alerts[@]} alerts found (use --alert to send)"
    else
        log $'\n'"All nodes healthy!"
    fi
}

# Skript starten
main "$@"
