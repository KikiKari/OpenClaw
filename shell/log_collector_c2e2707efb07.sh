#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "2331a8d3681198589ee059c4a20bd367eb2a3fba7bb4b633748bb5b49eb9a257", "source_sha256": "5081f9f0745ca8b2223c2de657aa97d48e58ccf61c24467e46c9d562803e34a6", "target_language": "shell"}
# log_collector.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
# auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Log Collector Sub-Agent
# Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_PATH="${WORKSPACE}/db/logs.db"
readonly LOG_DIR="${WORKSPACE}/logs/log-collector"

mkdir -p "${LOG_DIR}"

# Lade Hilfsfunktionen
source "${SCRIPT_DIR}/lib/helpers.sh"

# Initialisiere Logging
init_logger() {
    local today
    today=$(date '+%Y-%m-%d')
    readonly LOG_FILE="${LOG_DIR}/${today}.log"
}

log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    local line="[${timestamp}] [${level}] ${msg}"
    echo "${line}" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "$1"; }
error() { log "ERROR" "$1"; }

# Datenbankverbindung und Schema-Initialisierung
connect_db() {
    if ! command -v sqlite3 >/dev/null 2>&1; then
        error "SQLite3 nicht gefunden"
        exit 1
    fi
    
    if [ ! -f "${DB_PATH}" ]; then
        error "Datenbank nicht gefunden: ${DB_PATH}"
        exit 1
    fi
    
    # Prüfe ob Tabellen existieren
    if ! sqlite3 "${DB_PATH}" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 1;" >/dev/null 2>&1; then
        local schema_path="${WORKSPACE}/db/logs.db.schema.sql"
        if [ -f "${schema_path}" ]; then
            sqlite3 "${DB_PATH}" < "${schema_path}"
        else
            error "Schema-Datei nicht gefunden: ${schema_path}"
            exit 1
        fi
    fi
}

# Hole alle Nodes aus der Datenbank
get_nodes() {
    sqlite3 "${DB_PATH}" -json "SELECT * FROM nodes;"
}

# Prüfe VPN-Konnektivität
check_vpn() {
    local ip="$1"
    ping -c 1 -W 3 "${ip}" >/dev/null 2>&1
}

# SSH-Verbindung und Log-Sammlung
ssh_connect_and_collect() {
    local node_json="$1"
    
    local node_id
    node_id=$(echo "${node_json}" | jq -r '.node_id')
    
    local vpn_ip
    vpn_ip=$(echo "${node_json}" | jq -r '.vpn_ip // .tailscale_ip // .wireguard_ip // empty')
    
    if [ -z "${vpn_ip}" ]; then
        error "${node_id}: Keine VPN-IP konfiguriert"
        return 1
    fi
    
    info "${node_id}: Prüfe VPN ${vpn_ip}..."
    if ! check_vpn "${vpn_ip}"; then
        error "${node_id}: VPN nicht erreichbar"
        log_ssh_connection "${node_id}" "tailscale" "false" "VPN unreachable"
        return 1
    fi
    
    info "${node_id}: Verbinde via SSH..."
    
    local log_commands=(
        "journalctl -n 500 --no-pager"
        "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'"
        "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"
    )
    
    local logs_collected=()
    local cmd
    for cmd in "${log_commands[@]}"; do
        if output=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "openclaw@${vpn_ip}" "${cmd}" 2>/dev/null); then
            logs_collected+=("${cmd}|${output}")
        fi
    done
    
    # Erfolg loggen
    log_ssh_connection "${node_id}" "ssh" "true" ""
    
    # Logs in DB speichern
    insert_logs "${node_id}" "${logs_collected[@]}"
    
    info "${node_id}: ${#logs_collected[@]} Log-Einträge gespeichert"
    return 0
}

# Logge SSH-Verbindungsversuch
log_ssh_connection() {
    local node_id="$1"
    local conn_type="$2"
    local success="$3"
    local error_msg="$4"
    
    sqlite3 "${DB_PATH}" <<EOF
INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
VALUES ('${node_id}', '${conn_type}', ${success}, '${error_msg}');
EOF
}

# Speichere Logs in Datenbank
insert_logs() {
    local node_id="$1"
    shift
    local logs=("$@")
    
    local retention
    retention=$(date -d "+30 days" --iso-8601=seconds)
    
    local cmd
    local output
    for log_entry in "${logs[@]}"; do
        IFS='|' read -r cmd output <<< "${log_entry}"
        
        # Begrenze Länge der Felder
        cmd=${cmd:0:50}
        output=${output:0:10000}
        
        sqlite3 "${DB_PATH}" <<EOF
INSERT INTO logs (node_id, log_type, source, content, severity, collected_by, collection_method, retention_until)
VALUES ('${node_id}', 'system', '${cmd}', '${output}', 'info', 'node1', 'ssh', '${retention}');
EOF
    done
}

# Lösche alte Logs (>30 Tage)
cleanup_retention() {
    local deleted
    deleted=$(sqlite3 "${DB_PATH}" "DELETE FROM logs WHERE retention_until < datetime('now'); SELECT changes();")
    info "Retention-Cleanup: ${deleted} alte Logs gelöscht"
    return "${deleted}"
}

# Haupt-Sammelzyklus
run_collection_cycle() {
    info "============================================================"
    info "LOG COLLECTOR CYCLE START"
    info "============================================================"
    
    connect_db
    
    # Nodes holen
    local nodes_json
    nodes_json=$(get_nodes)
    local node_count
    node_count=$(echo "${nodes_json}" | jq 'length')
    info "Gefunden: ${node_count} Nodes"
    
    # Collection-Run starten
    local run_id
    run_id=$(sqlite3 "${DB_PATH}" "INSERT INTO collection_runs (started_at, nodes_total) VALUES (CURRENT_TIMESTAMP, ${node_count}); SELECT last_insert_rowid();")
    
    # Für jeden Node sammeln
    local success_count=0
    local failed_count=0
    local total_logs=0
    
    local i
    for ((i=0; i<node_count; i++)); do
        local node_json
        node_json=$(echo "${nodes_json}" | jq ".[${i}]")
        local node_id
        node_id=$(echo "${node_json}" | jq -r '.node_id')
        
        if [ "${node_id}" = "node1" ]; then
            # Lokale Logs (Gateway selbst)
            info "node1: Lokale Collection (Gateway)"
            ((success_count++))
        else
            # Remote-Node abfragen
            if ssh_connect_and_collect "${node_json}"; then
                ((success_count++))
                # TODO: Zähle tatsächlich gesammelte Logs
            else
                ((failed_count++))
            fi
        fi
    done
    
    # Run abschließen
    sqlite3 "${DB_PATH}" <<EOF
UPDATE collection_runs SET
    finished_at = CURRENT_TIMESTAMP,
    nodes_success = ${success_count},
    nodes_failed = ${failed_count},
    logs_collected = ${total_logs}
WHERE run_id = ${run_id};
EOF
    
    # Retention-Cleanup
    info "Retention-Cleanup (30 Tage)..."
    cleanup_retention
    
    info "============================================================"
    info "SUMMARY: ${success_count} OK, ${failed_count} Failed, ${total_logs} Logs"
    info "============================================================"
}

# Hauptprogramm
main() {
    echo "============================================================"
    echo "LOG COLLECTOR"
    echo "============================================================"
    
    init_logger
    
    if ! run_collection_cycle; then
        error "Collection cycle fehlgeschlagen"
        exit 1
    fi
}

# Starte das Programm
main "$@"
