#!/usr/bin/env bash
# log_collector.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
# auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Log Collector Sub-Agent
# Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden

readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_PATH="${WORKSPACE}/db/logs.db"
readonly LOG_DIR="${WORKSPACE}/logs/log-collector"

mkdir -p "${LOG_DIR}"

# Globale Variablen für Logging
declare LOG_FILE

# Logger Funktionen
log() {
    local level="$1"
    local msg="$2"
    local ts
    ts=$(date --iso-8601=seconds)
    local line="[${ts}] [${level}] ${msg}"
    echo "${line}"
    echo "${line}" >> "${LOG_FILE}"
}

logger_info() {
    log "INFO" "$1"
}

logger_error() {
    log "ERROR" "$1"
}

# Initialisiert das Datenbankschema falls nötig
init_schema() {
    local conn="$1"
    if ! sqlite3 "${conn}" "SELECT name FROM sqlite_master WHERE type='table';" | grep -q .; then
        local schema_path="${WORKSPACE}/db/logs.db.schema.sql"
        if [[ -f "${schema_path}" ]]; then
            sqlite3 "${conn}" < "${schema_path}"
        fi
    fi
}

# Holt Liste aller Nodes aus der DB
get_nodes() {
    sqlite3 "${DB_PATH}" -json "SELECT * FROM nodes;"
}

# Prüft ob VPN-IP erreichbar ist
check_vpn() {
    local ip="$1"
    if ping -c 1 -W 3 "${ip}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Loggt SSH-Verbindungsversuch
log_ssh_connection() {
    local node_id="$1"
    local conn_type="$2"
    local success="$3"
    local error="$4"
    
    sqlite3 "${DB_PATH}" <<EOF
INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
VALUES ('${node_id}', '${conn_type}', ${success}, '${error}');
EOF
}

# Speichert Logs in der Datenbank
insert_logs() {
    local node_id="$1"
    local logs_json="$2"
    local count
    count=$(echo "${logs_json}" | jq length)
    
    for ((i=0; i<count; i++)); do
        local command
        local output
        command=$(echo "${logs_json}" | jq -r ".[${i}].command" | cut -c1-50)
        output=$(echo "${logs_json}" | jq -r ".[${i}].output" | head -c 10000)
        local timestamp
        timestamp=$(date --iso-8601=seconds)
        
        sqlite3 "${DB_PATH}" <<EOF
INSERT INTO logs (node_id, log_type, source, content, severity, collected_by, collection_method, retention_until)
VALUES ('${node_id}', 'system', '${command}', '${output}', 'info', 'node1', 'ssh', '$(date -d '+30 days' --iso-8601=seconds)');
EOF
    done
    
    logger_info "${node_id}: ${count} Log-Einträge gespeichert"
}

# Verbindet via SSH und sammelt Logs
ssh_connect_and_collect() {
    local node_json="$1"
    local node_id
    node_id=$(echo "${node_json}" | jq -r '.node_id')
    local vpn_ip
    vpn_ip=$(echo "${node_json}" | jq -r '.vpn_ip // .tailscale_ip // .wireguard_ip')
    
    if [[ -z "${vpn_ip}" || "${vpn_ip}" == "null" ]]; then
        logger_error "${node_id}: Keine VPN-IP konfiguriert"
        echo "null"
        return
    fi
    
    # 1. VPN-Check
    logger_info "${node_id}: Prüfe VPN ${vpn_ip}..."
    if ! check_vpn "${vpn_ip}"; then
        logger_error "${node_id}: VPN nicht erreichbar"
        log_ssh_connection "${node_id}" "tailscale" 0 "VPN unreachable"
        echo "null"
        return
    fi
    
    # 2. SSH-Verbindung
    logger_info "${node_id}: Verbinde via SSH..."
    
    local logs_collected="[]"
    
    # Logs abholen
    local log_commands=(
        "journalctl -n 500 --no-pager"
        "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'"
        "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"
    )
    
    for cmd in "${log_commands[@]}"; do
        if output=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "openclaw@${vpn_ip}" "${cmd}" 2>/dev/null); then
            local entry
            entry=$(jq -n --arg cmd "${cmd}" --arg out "${output}" --arg ts "$(date --iso-8601=seconds)" \
                '{command: $cmd, output: $out, timestamp: $ts}')
            logs_collected=$(echo "${logs_collected}" | jq ". += [${entry}]")
        fi
    done
    
    # Erfolg loggen
    log_ssh_connection "${node_id}" "ssh" 1 "null"
    
    # In DB speichern
    insert_logs "${node_id}" "${logs_collected}"
    
    echo "${logs_collected}" | jq length
}

# Löscht Logs älter 30 Tage
cleanup_retention() {
    local deleted
    deleted=$(sqlite3 "${DB_PATH}" "DELETE FROM logs WHERE retention_until < datetime('now'); SELECT changes();")
    logger_info "Retention-Cleanup: ${deleted} alte Logs gelöscht"
    echo "${deleted}"
}

# Ein kompletter Sammel-Durchlauf
run_collection_cycle() {
    logger_info "============================================================"
    logger_info "LOG COLLECTOR CYCLE START"
    logger_info "============================================================"
    
    # Schema initialisieren
    init_schema "${DB_PATH}"
    
    # 1. Nodes holen
    local nodes_json
    nodes_json=$(get_nodes)
    local nodes_count
    nodes_count=$(echo "${nodes_json}" | jq length)
    logger_info "Gefunden: ${nodes_count} Nodes"
    
    # 2. Collection-Run starten
    local run_id
    run_id=$(sqlite3 "${DB_PATH}" "INSERT INTO collection_runs (started_at, nodes_total) VALUES (CURRENT_TIMESTAMP, ${nodes_count}); SELECT last_insert_rowid();")
    
    # 3. Für jeden Node sammeln
    local success_count=0
    local failed_count=0
    local total_logs=0
    
    for ((i=0; i<nodes_count; i++)); do
        local node
        node=$(echo "${nodes_json}" | jq ".[${i}]")
        local node_id
        node_id=$(echo "${node}" | jq -r '.node_id')
        
        if [[ "${node_id}" == "node1" ]]; then
            # Lokale Logs (Gateway selbst)
            logger_info "node1: Lokale Collection (Gateway)"
            ((success_count++))
        else
            # Remote-Node abfragen
            local result
            result=$(ssh_connect_and_collect "${node}")
            if [[ "${result}" != "null" ]]; then
                ((success_count++))
                ((total_logs+=result))
            else
                ((failed_count++))
            fi
        fi
    done
    
    # 4. Run abschließen
    sqlite3 "${DB_PATH}" <<EOF
UPDATE collection_runs SET
    finished_at = CURRENT_TIMESTAMP,
    nodes_success = ${success_count},
    nodes_failed = ${failed_count},
    logs_collected = ${total_logs}
WHERE run_id = ${run_id};
EOF
    
    # 5. Retention-Cleanup
    logger_info "Retention-Cleanup (30 Tage)..."
    cleanup_retention >/dev/null
    
    logger_info "============================================================"
    logger_info "SUMMARY: ${success_count} OK, ${failed_count} Failed, ${total_logs} Logs"
    logger_info "============================================================"
}

main() {
    local today
    today=$(date +%Y-%m-%d)
    LOG_FILE="${LOG_DIR}/${today}.log"
    
    echo "============================================================"
    echo "LOG COLLECTOR"
    echo "============================================================"
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq ist nicht installiert"
        exit 1
    fi
    
    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "ERROR: sqlite3 ist nicht installiert"
        exit 1
    fi
    
    run_collection_cycle
}

main "$@"
