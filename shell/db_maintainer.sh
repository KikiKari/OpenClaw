#!/usr/bin/env bash
# db_maintainer.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_DIR="${WORKSPACE}/db"
readonly BACKUP_DIR="${DB_DIR}/backups"
readonly LOG_DIR="${WORKSPACE}/logs/db-maintainer"
readonly IMPORTANT_DIR="${WORKSPACE}/important"
readonly STATE_FILE="${DB_DIR}/maintainer_state.json"

# Verzeichnisse erstellen
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

# Globale Variablen
declare LOG_FILE=""
declare TODAY=""

# Einfacher Logger mit Datei-Ausgabe
init_logger() {
    TODAY=$(date +%Y-%m-%d)
    LOG_FILE="${LOG_DIR}/${TODAY}.log"
}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[${timestamp}] [${level}] ${message}"
    echo "${line}"
    echo "${line}" >> "${LOG_FILE}"
}

info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }

# Lädt letzten Check-Zustand
load_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        cat "${STATE_FILE}"
    else
        echo '{"last_check": null, "last_backup": null, "last_tree_update": null, "file_hashes": {}}'
    fi
}

# Speichert aktuellen Zustand
save_state() {
    local state="$1"
    echo "${state}" | jq '.' > "${STATE_FILE}"
}

# Berechnet MD5-Hash einer Datei
get_file_hash() {
    local filepath="$1"
    if [[ -f "${filepath}" ]]; then
        md5sum "${filepath}" | cut -d' ' -f1
    else
        echo ""
    fi
}

# Führt tree -a -L 8 auf workspace aus und gibt Ergebnis zurück
run_tree_command() {
    local output
    output=$(timeout 60 tree -a -L 8 "${WORKSPACE}" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        info "tree -a -L 8 erfolgreich ausgeführt"
        echo "${output}"
        return 0
    else
        error "tree command fehlgeschlagen: ${output}"
        return 1
    fi
}

# Schreibt tree-output in important/openclaw-tree.txt
update_tree_file() {
    local tree_output="$1"
    if [[ -z "${tree_output}" ]]; then
        return 1
    fi
    
    local tree_file="${IMPORTANT_DIR}/openclaw-tree.txt"
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    # Header mit Timestamp
    cat > "${tree_file}" <<EOF
# OpenClaw Workspace Tree
# Generiert: ${timestamp}
# Befehl: tree -a -L 8 ${WORKSPACE}
# Diese Datei wird automatisch von db-maintainer aktualisiert

${tree_output}
EOF
    
    info "openclaw-tree.txt aktualisiert: ${tree_file}"
    return 0
}

# Scannt alle .md Dateien auf Änderungen
scan_documentations() {
    local temp_file
    temp_file=$(mktemp)
    
    find "${WORKSPACE}" -type f -name "*.md" ! -path "*/db/backups/*" ! -path "*/node_modules/*" | while read -r file; do
        local rel_path
        rel_path=$(realpath --relative-to="${WORKSPACE}" "${file}")
        local hash
        hash=$(get_file_hash "${file}")
        local mtime
        mtime=$(stat -c %Y "${file}")
        echo "${rel_path}|${hash}|${mtime}"
    done > "${temp_file}"
    
    cat "${temp_file}"
    rm -f "${temp_file}"
}

# Prüft auf Änderungen seit letztem Lauf
check_for_changes() {
    local state="$1"
    local current_docs_temp
    current_docs_temp=$(mktemp)
    local changes_temp
    changes_temp=$(mktemp)
    
    scan_documentations > "${current_docs_temp}"
    
    # Prüfe auf neue/geänderte Dateien
    while IFS='|' read -r path hash _; do
        local old_hash
        old_hash=$(echo "${state}" | jq -r ".file_hashes.\"${path}\" // \"\"")
        
        if [[ -z "${old_hash}" ]]; then
            echo "NEW: ${path}" >> "${changes_temp}"
        elif [[ "${old_hash}" != "${hash}" ]]; then
            echo "CHANGED: ${path}" >> "${changes_temp}"
        fi
    done < "${current_docs_temp}"
    
    # Prüfe auf gelöschte Dateien
    local existing_paths
    existing_paths=$(cut -d'|' -f1 "${current_docs_temp}")
    
    echo "${state}" | jq -r '.file_hashes | keys[]' | while read -r old_path; do
        if ! grep -q "^${old_path}|" "${current_docs_temp}" 2>/dev/null; then
            echo "DELETED: ${old_path}" >> "${changes_temp}"
        fi
    done
    
    cat "${changes_temp}"
    rm -f "${current_docs_temp}" "${changes_temp}"
}

# Erstellt Hash-Map für aktuelle Dateien
create_current_hashes() {
    local current_docs_temp
    current_docs_temp=$(mktemp)
    local hashes_json
    hashes_json=$(mktemp)
    
    scan_documentations > "${current_docs_temp}"
    
    echo "{" > "${hashes_json}"
    local first=true
    while IFS='|' read -r path hash _; do
        if [[ "${first}" == true ]]; then
            first=false
        else
            echo "," >> "${hashes_json}"
        fi
        printf '"%s": "%s"' "${path}" "${hash}" >> "${hashes_json}"
    done < "${current_docs_temp}"
    echo "}" >> "${hashes_json}"
    
    cat "${hashes_json}"
    rm -f "${current_docs_temp}" "${hashes_json}"
}

# Führt DB-Update-Scripts aus
update_databases() {
    local output
    output=$(timeout 60 python3 "${WORKSPACE}/scripts/update_docs_db.py" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        info "docs.db aktualisiert"
        return 0
    else
        error "DB-Update fehlgeschlagen: ${output}"
        return 1
    fi
}

# Führt tree_indexer_v2.py aus
update_tree_db_v2() {
    local output
    output=$(timeout 120 python3 "${WORKSPACE}/scripts/tree_indexer_v2.py" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        info "tree.db v2 aktualisiert"
        return 0
    else
        error "Tree-DB v2 fehlgeschlagen: ${output}"
        return 1
    fi
}

# Erstellt Backup beider Datenbanken
create_backup() {
    local timestamp
    timestamp=$(date +%Y-%m-%d_%H-%M)
    
    for db_name in docs.db tree.db; do
        local source="${DB_DIR}/${db_name}"
        if [[ -f "${source}" ]]; then
            local backup_name="${timestamp}_${db_name}.bak"
            local backup_path="${BACKUP_DIR}/${backup_name}"
            cp "${source}" "${backup_path}"
            info "Backup erstellt: ${backup_name}"
        fi
    done
    
    echo "${timestamp}"
}

# Löscht Backups älter als 3 Tage
cleanup_old_backups() {
    local cutoff
    cutoff=$(date -d '3 days ago' +%s)
    local deleted=0
    
    for db_name in docs.db tree.db; do
        for backup in "${BACKUP_DIR}"/*_"${db_name}".bak; do
            if [[ -f "${backup}" ]]; then
                # Extrahiere Datum aus Filename (Format: YYYY-MM-DD_HH-MM)
                local basename
                basename=$(basename "${backup}")
                local date_part
                date_part=$(echo "${basename}" | cut -d'_' -f1)
                local time_part
                time_part=$(echo "${basename}" | cut -d'_' -f2)
                local backup_time_str="${date_part}_${time_part}"
                
                if date -d "${backup_time_str//_/ }" >/dev/null 2>&1; then
                    local backup_timestamp
                    backup_timestamp=$(date -d "${backup_time_str//_/ }" +%s)
                    
                    if [[ ${backup_timestamp} -lt ${cutoff} ]]; then
                        rm "${backup}"
                        ((deleted++))
                        info "Altes Backup gelöscht: ${basename}"
                    fi
                else
                    warn "Konnte Backup-Datum nicht parsen: ${basename}"
                fi
            fi
        done
    done
    
    if [[ ${deleted} -eq 0 ]]; then
        info "Keine alten Backups zum Löschen"
    else
        info "${deleted} alte Backups gelöscht (< 3 Tage)"
    fi
}

# Ein kompletter Wartungszyklus
run_cycle() {
    info "============================================================"
    info "DB MAINTAINER CYCLE START"
    info "============================================================"
    
    local state
    state=$(load_state)
    
    # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    info "Führe tree -a -L 8 aus..."
    local tree_output
    if tree_output=$(run_tree_command); then
        update_tree_file "${tree_output}"
        state=$(echo "${state}" | jq --arg time "$(date --iso-8601=seconds)" '.last_tree_update = $time')
    fi
    
    # 2. tree.db aktualisieren (intern v2)
    info "Aktualisiere tree.db v2..."
    update_tree_db_v2 >/dev/null || true
    
    # 3. Änderungen prüfen
    info "Prüfe auf Dokumentations-Änderungen..."
    local changes
    changes=$(check_for_changes "${state}")
    local change_count
    change_count=$(echo "${changes}" | grep -v '^$' | wc -l)
    
    if [[ ${change_count} -gt 0 ]]; then
        info "${change_count} Änderungen gefunden:"
        echo "${changes}" | head -n 10 | while read -r change; do
            if [[ -n "${change}" ]]; then
                info "  - ${change}"
            fi
        done
        if [[ ${change_count} -gt 10 ]]; then
            local remaining
            remaining=$((change_count - 10))
            info "  ... und ${remaining} weitere"
        fi
        
        # 4. docs.db aktualisieren
        info "Aktualisiere docs.db..."
        if update_databases; then
            state=$(echo "${state}" | jq --arg time "$(date --iso-8601=seconds)" '.last_check = $time')
            local current_hashes
            current_hashes=$(create_current_hashes)
            state=$(echo "${state}" | jq --argjson hashes "${current_hashes}" '.file_hashes = $hashes')
        fi
    else
        info "Keine Dokumentations-Änderungen gefunden"
    fi
    
    # 5. Prüfe ob Backup fällig (stündlich)
    local last_backup
    last_backup=$(echo "${state}" | jq -r '.last_backup // "null"')
    local do_backup=false
    
    if [[ "${last_backup}" == "null" ]]; then
        do_backup=true
    else
        local last_backup_seconds
        last_backup_seconds=$(date -d "${last_backup}" +%s)
        local now_seconds
        now_seconds=$(date +%s)
        local diff_hours
        diff_hours=$(( (now_seconds - last_backup_seconds) / 3600 ))
        
        if [[ ${diff_hours} -ge 1 ]]; then
            do_backup=true
        fi
    fi
    
    if [[ "${do_backup}" == true ]]; then
        info "Erstelle stündliches Backup..."
        local timestamp
        timestamp=$(create_backup)
        state=$(echo "${state}" | jq --arg time "$(date --iso-8601=seconds)" '.last_backup = $time')
        
        # 6. Alte Backups aufräumen (3 Tage Retention)
        info "Räume alte Backups auf (3 Tage Retention)..."
        cleanup_old_backups
    else
        info "Backup nicht nötig (letztes < 1h)"
    fi
    
    save_state "${state}"
    
    info "============================================================"
    info "DB MAINTAINER CYCLE END"
    info "============================================================"
}

# Hauptfunktion
main() {
    init_logger
    
    if ! command -v jq >/dev/null 2>&1; then
        error "jq ist nicht installiert"
        exit 1
    fi
    
    if ! command -v tree >/dev/null 2>&1; then
        error "tree ist nicht installiert"
        exit 1
    fi
    
    if ! command -v md5sum >/dev/null 2>&1; then
        error "md5sum ist nicht verfügbar"
        exit 1
    fi
    
    trap 'error "CRITICAL ERROR: Script terminated"' ERR
    
    run_cycle
}

main "$@"
