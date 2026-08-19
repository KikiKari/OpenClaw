#!/usr/bin/env bash
# db_maintainer.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

readonly SCRIPT_NAME="db_maintainer.sh"
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_DIR="${WORKSPACE}/db"
readonly BACKUP_DIR="${DB_DIR}/backups"
readonly LOG_DIR="${WORKSPACE}/logs/db-maintainer"
readonly IMPORTANT_DIR="${WORKSPACE}/important"
readonly STATE_FILE="${DB_DIR}/maintainer_state.json"

readonly RETENTION_DAYS=3

# Create directories
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}" "${IMPORTANT_DIR}"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[${timestamp}] [${level}] ${message}"
    echo "${log_line}"
    
    local today
    today=$(date '+%Y-%m-%d')
    echo "${log_line}" >> "${LOG_DIR}/${today}.log"
}

info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }

# Load state from JSON file
load_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        cat "${STATE_FILE}"
    else
        echo '{"last_check": null, "last_backup": null, "last_tree_update": null, "file_hashes": {}}'
    fi
}

# Save state to JSON file
save_state() {
    local state="$1"
    echo "${state}" | jq '.' > "${STATE_FILE}"
}

# Calculate MD5 hash of a file
get_file_hash() {
    local filepath="$1"
    if [[ -f "${filepath}" ]]; then
        md5sum "${filepath}" | cut -d' ' -f1
    else
        echo "null"
    fi
}

# Run tree command and return output
run_tree_command() {
    local result
    result=$(timeout 60 tree -a -L 6 "${WORKSPACE}" 2>&1)
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        info "tree -a -L 6 erfolgreich ausgeführt"
        echo "${result}"
        return 0
    else
        error "tree command fehlgeschlagen: ${result}"
        return 1
    fi
}

# Write tree output to important/openclaw-tree.txt
update_tree_file() {
    local tree_output="$1"
    if [[ -z "${tree_output}" ]]; then
        return 1
    fi
    
    local tree_file="${IMPORTANT_DIR}/openclaw-tree.txt"
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    # Header with timestamp
    cat > "${tree_file}" <<EOF
# OpenClaw Workspace Tree
# Generiert: ${timestamp}
# Befehl: tree -a -L 6 ${WORKSPACE}
# Diese Datei wird automatisch von db-maintainer aktualisiert

${tree_output}
EOF
    
    info "openclaw-tree.txt aktualisiert: ${tree_file}"
    return 0
}

# Scan all .md files for changes
scan_documentations() {
    local temp_file
    temp_file=$(mktemp)
    
    find "${WORKSPACE}" -type f -name "*.md" \
        ! -path "${DB_DIR}/backups/*" \
        ! -path "*/node_modules/*" \
        -exec stat -c "%n|%Y" {} \; | while IFS='|' read -r filepath mtime; do
        local rel_path
        rel_path=${filepath#"${WORKSPACE}/"}
        local hash
        hash=$(get_file_hash "${filepath}")
        echo "{\"path\":\"${rel_path}\",\"hash\":\"${hash}\",\"mtime\":${mtime}}"
    done > "${temp_file}"
    
    echo "${temp_file}"
}

# Check for changes since last run
check_for_changes() {
    local temp_docs="$1"
    local state
    state=$(load_state)
    
    local changes_file
    changes_file=$(mktemp)
    
    # Process current documents
    local current_hashes_temp
    current_hashes_temp=$(mktemp)
    
    while IFS= read -r line; do
        local path hash
        path=$(echo "${line}" | jq -r '.path')
        hash=$(echo "${line}" | jq -r '.hash')
        
        echo "${path}|${hash}" >> "${current_hashes_temp}"
        
        # Check if file is new or changed
        local old_hash
        old_hash=$(echo "${state}" | jq -r ".file_hashes[\"${path}\"] // \"null\"")
        
        if [[ "${old_hash}" == "null" ]]; then
            echo "NEW: ${path}" >> "${changes_file}"
        elif [[ "${old_hash}" != "${hash}" ]]; then
            echo "CHANGED: ${path}" >> "${changes_file}"
        fi
    done < "${temp_docs}"
    
    # Check for deleted files
    local old_paths
    old_paths=$(echo "${state}" | jq -r '(.file_hashes | keys[]) // empty')
    
    while IFS= read -r old_path; do
        if ! grep -q "^${old_path}|" "${current_hashes_temp}" 2>/dev/null; then
            echo "DELETED: ${old_path}" >> "${changes_file}"
        fi
    done <<< "${old_paths}"
    
    echo "${changes_file}"
    echo "${current_hashes_temp}"
}

# Update databases by running Python scripts
update_databases() {
    local result
    result=$(timeout 60 python3 "${WORKSPACE}/scripts/update_docs_db.py" 2>&1)
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        info "docs.db aktualisiert"
        return 0
    else
        error "DB-Update fehlgeschlagen: ${result}"
        return 1
    fi
}

# Update tree database v2
update_tree_db_v2() {
    local result
    result=$(timeout 120 python3 "${WORKSPACE}/scripts/tree_indexer_v2.py" 2>&1)
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        info "tree.db v2 aktualisiert"
        return 0
    else
        error "Tree-DB v2 fehlgeschlagen: ${result}"
        return 1
    fi
}

# Create backup of both databases
create_backup() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M')
    
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

# Clean up old backups (older than 3 days)
cleanup_old_backups() {
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "-${RETENTION_DAYS} days" +%s)
    local deleted=0
    
    for db_name in docs.db tree.db; do
        find "${BACKUP_DIR}" -name "*_${db_name}.bak" -type f | while read -r backup; do
            # Extract date from filename (Format: YYYY-MM-DD_HH-MM)
            local basename
            basename=$(basename "${backup}")
            local date_part time_part
            date_part=$(echo "${basename}" | cut -d'_' -f1)
            time_part=$(echo "${basename}" | cut -d'_' -f2)
            
            if [[ -n "${date_part}" && -n "${time_part}" ]]; then
                local backup_datestr="${date_part}_${time_part%.bak}"
                local backup_timestamp
                backup_timestamp=$(date -d "${backup_datestr}" +%s 2>/dev/null || echo "0")
                
                if [[ ${backup_timestamp} -lt ${cutoff_timestamp} ]] && [[ ${backup_timestamp} -gt 0 ]]; then
                    rm "${backup}"
                    ((deleted++))
                    info "Altes Backup gelöscht: $(basename "${backup}")"
                fi
            else
                warn "Konnte Backup-Datum nicht parsen: $(basename "${backup}")"
            fi
        done
    done
    
    if [[ ${deleted} -eq 0 ]]; then
        info "Keine alten Backups zum Löschen"
    else
        info "${deleted} alte Backups gelöscht (< 3 Tage)"
    fi
}

# Run one complete maintenance cycle
run_cycle() {
    info "============================================================"
    info "DB MAINTAINER CYCLE START"
    info "============================================================"
    
    local state
    state=$(load_state)
    
    # 1. Run tree command and write to openclaw-tree.txt
    info "Führe tree -a -L 8 aus..."
    local tree_output
    tree_output=$(run_tree_command)
    if [[ -n "${tree_output}" ]]; then
        update_tree_file "${tree_output}"
        state=$(echo "${state}" | jq --arg time "$(date --iso-8601=seconds)" '.last_tree_update = $time')
    fi
    
    # 2. Update tree.db (internal v2)
    info "Aktualisiere tree.db v2..."
    update_tree_db_v2
    
    # 3. Check for changes
    info "Prüfe auf Dokumentations-Änderungen..."
    local temp_docs
    temp_docs=$(scan_documentations)
    local results
    results=$(check_for_changes "${temp_docs}")
    local changes_file current_hashes_temp
    changes_file=$(echo "${results}" | head -n1)
    current_hashes_temp=$(echo "${results}" | tail -n1)
    
    local changes_count
    changes_count=$(wc -l < "${changes_file}" | tr -d ' ')
    
    if [[ ${changes_count} -gt 0 ]]; then
        info "${changes_count} Änderungen gefunden:"
        local count=0
        while IFS= read -r change && [[ ${count} -lt 10 ]]; do
            info "  - ${change}"
            ((count++))
        done < "${changes_file}"
        
        if [[ ${changes_count} -gt 10 ]]; then
            local remaining
            remaining=$((changes_count - 10))
            info "  ... und ${remaining} weitere"
        fi
        
        # 4. Update docs.db
        info "Aktualisiere docs.db..."
        if update_databases; then
            state=$(echo "${state}" | jq --arg time "$(date --iso-8601=seconds)" '.last_check = $time')
            
            # Build new file_hashes object
            local hashes_json="{"
            local first=true
            while IFS='|' read -r path hash; do
                if [[ "${first}" == true ]]; then
                    first=false
                else
                    hashes_json+=","
                fi
                hashes_json+="\"${path}\":\"${hash}\""
            done < "${current_hashes_temp}"
            hashes_json+="}"
            
            state=$(echo "${state}" | jq --argjson hashes "${hashes_json}" '.file_hashes = $hashes')
        fi
    else
        info "Keine Dokumentations-Änderungen gefunden"
    fi
    
    # 5. Check if backup is due (hourly)
    local last_backup
    last_backup=$(echo "${state}" | jq -r '.last_backup // "null"')
    local do_backup=false
    
    if [[ "${last_backup}" == "null" ]]; then
        do_backup=true
    else
        local last_backup_timestamp
        last_backup_timestamp=$(date -d "${last_backup}" +%s 2>/dev/null || echo "0")
        local current_timestamp
        current_timestamp=$(date +%s)
        local diff_hours
        diff_hours=$(( (current_timestamp - last_backup_timestamp) / 3600 ))
        
        if [[ ${diff_hours} -ge 1 ]]; then
            do_backup=true
        fi
    fi
    
    if [[ "${do_backup}" == true ]]; then
        info "Erstelle stündliches Backup..."
        local timestamp
        timestamp=$(create_backup)
        state=$(echo "${state}" | jq --arg time "$(date --iso-8601=seconds)" '.last_backup = $time')
        
        # 6. Clean up old backups (3 days retention)
        info "Räume alte Backups auf (3 Tage Retention)..."
        cleanup_old_backups
    else
        info "Backup nicht nötig (letztes < 1h)"
    fi
    
    save_state "${state}"
    
    # Clean up temporary files
    rm -f "${temp_docs}" "${changes_file}" "${current_hashes_temp}"
    
    info "============================================================"
    info "DB MAINTAINER CYCLE END"
    info "============================================================"
}

# Main function
main() {
    # Check if required commands are available
    command -v jq >/dev/null 2>&1 || { error "jq ist nicht installiert"; exit 1; }
    command -v tree >/dev/null 2>&1 || { error "tree ist nicht installiert"; exit 1; }
    command -v md5sum >/dev/null 2>&1 || { error "md5sum ist nicht verfügbar"; exit 1; }
    
    # Run the maintenance cycle
    run_cycle
}

# Run main function
main "$@"
