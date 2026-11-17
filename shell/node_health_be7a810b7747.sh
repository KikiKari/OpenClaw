#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "36da9b7c62855661005c2fe59fc237535ee2914bfb52d3cffda963dc34ddc851", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "shell"}
# node_health.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node Health Monitor - Multi-Node Gesundheitsüberwachung

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly HEALTH_DB="${WORKSPACE}/db/health.db"
readonly LOG_FILE="${WORKSPACE}/logs/node-health.log"

# Logging Funktion
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

# Prüft Erreichbarkeit
check_ping() {
    local host="$1"
    local timeout="${2:-5}"
    
    if ping -c 1 -W "${timeout}" "${host}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Prüft SSH-Verbindung
check_ssh() {
    local host="$1"
    local user="$2"
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "${user}@${host}" echo "OK" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Holt Metriken via SSH
get_node_metrics() {
    local host="$1"
    local user="$2"
    local node_name="$3"
    
    local cmd="
        # CPU
        echo \"CPU:\$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1)\"
        
        # RAM
        echo \"RAM:\$(free | grep Mem | awk '{print (\$3/\$2) * 100.0}')\"
        
        # Disk
        echo \"DISK:\$(df -h / | tail -1 | awk '{print \$5}' | tr -d '%')\"
        
        # Load
        echo \"LOAD:\$(uptime | awk -F'load average:' '{print \$2}' | awk '{print \$1}' | tr -d ',')\"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo \"GATEWAY:inactive\"
        fi
    "
    
    local output
    if output=$(ssh -o ConnectTimeout=10 "${user}@${host}" "${cmd}" 2>/dev/null); then
        echo "available:true"
        echo "${output}"
    else
        echo "available:false"
    fi
}

# Prüft Schwellwerte und generiert Alerts
check_alerts() {
    local node_id="$1"
    local node_name="$2"
    local node_host="$3"
    local is_critical="$4"
    local is_optional="$5"
    local disk_warning="${6:-85}"
    local metrics_file="$7"
    
    local available
    available=$(grep "^available:" "${metrics_file}" | cut -d':' -f2)
    
    # Verfügbarkeit
    if [[ "${available}" != "true" ]]; then
        if [[ "${is_optional}" != "true" ]]; then
            echo "CRITICAL:Node ${node_name} nicht erreichbar!"
            return
        fi
    else
        # CPU
        local cpu
        cpu=$(grep "^CPU:" "${metrics_file}" | cut -d':' -f2)
        if [[ -n "${cpu}" && "$(echo "${cpu} > 90" | bc -l 2>/dev/null || echo 0)" -eq 1 ]]; then
            echo "WARNING:Node ${node_name}: CPU bei ${cpu}%"
        fi
        
        # RAM
        local ram
        ram=$(grep "^RAM:" "${metrics_file}" | cut -d':' -f2)
        if [[ -n "${ram}" && "$(echo "${ram} > 90" | bc -l 2>/dev/null || echo 0)" -eq 1 ]]; then
            echo "WARNING:Node ${node_name}: RAM bei ${ram}%"
        fi
        
        # Disk
        local disk
        disk=$(grep "^DISK:" "${metrics_file}" | cut -d':' -f2)
        if [[ -n "${disk}" && "${disk}" -gt "${disk_warning}" ]]; then
            if [[ "${disk}" -gt 95 ]]; then
                echo "CRITICAL:Node ${node_name}: Disk bei ${disk}%"
            else
                echo "WARNING:Node ${node_name}: Disk bei ${disk}%"
            fi
        fi
        
        # Gateway
        local gateway_status
        gateway_status=$(grep "^GATEWAY:" "${metrics_file}" | cut -d':' -f2)
        if [[ "${is_critical}" == "true" && "${gateway_status}" == "inactive" ]]; then
            echo "CRITICAL:Node ${node_name}: OpenClaw Gateway nicht aktiv!"
        fi
    fi
}

# Sendet Alert via channel-status-agent
send_alert() {
    local alert_message="$1"
    local level
    level=$(echo "${alert_message}" | cut -d':' -f1)
    local message
    message=$(echo "${alert_message}" | cut -d':' -f2- | sed 's/^ *//')
    
    if python3 "${WORKSPACE}/skills/channel-status-agent/scripts/channel_status.py" \
        --type alert \
        --message "${level}: ${message}" >/dev/null 2>&1; then
        log "Alert sent: ${message}"
    else
        log "Failed to send alert: ${message}" "ERROR"
    fi
}

# Hauptfunktion
main() {
    local target_node="all"
    local check_type="all"
    local send_alerts=false
    
    # Kommandozeilenargumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --node)
                target_node="$2"
                shift 2
                ;;
            --check)
                check_type="$2"
                shift 2
                ;;
            --alert)
                send_alerts=true
                shift
                ;;
            *)
                echo "Unbekanntes Argument: $1" >&2
                exit 1
                ;;
        esac
    done
    
    # Node-Konfiguration (simuliert als assoziatives Array)
    declare -A NODES=(
        ["node1:name"]="Gateway"
        ["node1:host"]="localhost"
        ["node1:user"]="openclaw"
        ["node1:critical"]="true"
        
        ["node2:name"]="Worker"
        ["node2:host"]="100.92.155.34"
        ["node2:user"]="root"
        ["node2:ssh_key"]="~/.ssh/id_rsa"
        
        ["node3:name"]="Relay"
        ["node3:host"]="185.242.xxx.xxx"
        ["node3:user"]="root"
        ["node3:disk_warning"]="85"
        
        ["node5:name"]="Redmi"
        ["node5:host"]="192.168.1.x"
        ["node5:user"]="openclaw"
        ["node5:optional"]="true"
    )
    
    # Nodes bestimmen
    local nodes_to_check=()
    if [[ "${target_node}" == "all" ]]; then
        nodes_to_check=("node1" "node2" "node3" "node5")
    else
        if [[ -n "${NODES[${target_node}:name]:-}" ]]; then
            nodes_to_check=("${target_node}")
        else
            log "Unknown node: ${target_node}" "ERROR"
            exit 1
        fi
    fi
    
    # Temporäres Verzeichnis für Metriken erstellen
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' EXIT
    
    # Health-Checks durchführen
    local all_alerts=()
    
    for node_id in "${nodes_to_check[@]}"; do
        local node_name="${NODES[${node_id}:name]:-}"
        local node_host="${NODES[${node_id}:host]:-}"
        local node_user="${NODES[${node_id}:user]:-root}"
        local is_critical="${NODES[${node_id}:critical]:-false}"
        local is_optional="${NODES[${node_id}:optional]:-false}"
        local disk_warning="${NODES[${node_id}:disk_warning]:-85}"
        
        if [[ -z "${node_name}" ]]; then
            continue
        fi
        
        log "Checking ${node_name} (${node_id})"
        
        # Ping
        if [[ "${check_type}" == "ping" || "${check_type}" == "all" ]]; then
            if [[ "${node_host}" != "localhost" ]]; then
                if check_ping "${node_host}"; then
                    log "  Ping: OK"
                else
                    log "  Ping: FAILED"
                fi
            fi
        fi
        
        # SSH
        if [[ "${check_type}" == "ssh" || "${check_type}" == "all" ]]; then
            if check_ssh "${node_host}" "${node_user}"; then
                log "  SSH: OK"
            else
                log "  SSH: FAILED"
            fi
        fi
        
        # Metriken
        if [[ "${check_type}" == "metrics" || "${check_type}" == "all" ]]; then
            local metrics_file="${temp_dir}/${node_id}_metrics.txt"
            get_node_metrics "${node_host}" "${node_user}" "${node_name}" > "${metrics_file}"
            
            local available
            available=$(grep "^available:" "${metrics_file}" | cut -d':' -f2)
            
            if [[ "${available}" == "true" ]]; then
                local cpu ram disk load
                cpu=$(grep "^CPU:" "${metrics_file}" | cut -d':' -f2)
                ram=$(grep "^RAM:" "${metrics_file}" | cut -d':' -f2)
                disk=$(grep "^DISK:" "${metrics_file}" | cut -d':' -f2)
                load=$(grep "^LOAD:" "${metrics_file}" | cut -d':' -f2)
                
                log "  CPU: ${cpu:-N/A}"
                log "  RAM: ${ram:-N/A}"
                log "  Disk: ${disk:-N/A}"
                log "  Load: ${load:-N/A}"
            else
                log "  Metrics: UNAVAILABLE"
            fi
            
            # Alerts prüfen
            local alerts
            alerts=$(check_alerts "${node_id}" "${node_name}" "${node_host}" "${is_critical}" "${is_optional}" "${disk_warning}" "${metrics_file}")
            if [[ -n "${alerts}" ]]; then
                while IFS= read -r alert; do
                    if [[ -n "${alert}" ]]; then
                        all_alerts+=("${alert}")
                    fi
                done <<< "${alerts}"
            fi
        fi
    done
    
    # Alerts senden
    if [[ "${send_alerts}" == true && ${#all_alerts[@]} -gt 0 ]]; then
        log "Sending ${#all_alerts[@]} alerts..."
        for alert in "${all_alerts[@]}"; do
            send_alert "${alert}"
        done
    elif [[ ${#all_alerts[@]} -gt 0 ]]; then
        log "${#all_alerts[@]} alerts found (use --alert to send)"
    else
        log "All nodes healthy!"
    fi
}

# Skript ausführen
main "$@"
