#!/usr/bin/env bash
# db_maintainer.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_DIR="${WORKSPACE}/db"
readonly BACKUP_DIR="${DB_DIR}/backups"
readonly LOG_DIR="${WORKSPACE}/logs/db-maintainer"
readonly IMPORTANT_DIR="${WORKSPACE}/important"

# Create directories
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

# Global variables for state management
declare -A FILE_HASHES
declare -a CHANGES

# Logger functions
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[${timestamp}] [${level}] ${message}"
    echo "${line}"
    local today
    today=$(date '+%Y-%m-%d')
    echo "${line}" >> "${LOG_DIR}/${today}.log"
}

info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }

# State management functions
state_file="${DB_DIR}/maintainer_state.json"

load_state() {
    if [[ -f "${state_file}" ]]; then
        # We'll parse the JSON manually since bash doesn't have native JSON support
        LAST_CHECK=$(jq -r '.last_check // "null"' "${state_file}" 2>/dev/null || echo "null")
        LAST_BACKUP=$(jq -r '.last_backup // "null"' "${state_file}" 2>/dev/null || echo "null")
        LAST_TREE_UPDATE=$(jq -r '.last_tree_update // "null"' "${state_file}" 2>/dev/null || echo "null")
        
        # Load file hashes into associative array
        while IFS=":" read -r key value; do
            if [[ -n "${key}" && -n "${value}" ]]; then
                FILE_HASHES["${key}"]=$(echo "${value}" | tr -d '"')
            fi
        done < <(jq -r '.file_hashes | to_entries[] | "\(.key):\(.value)"' "${state_file}" 2>/dev/null || true)
    else
        LAST_CHECK="null"
        LAST_BACKUP="null"
        LAST_TREE_UPDATE="null"
    fi
}

save_state() {
    local temp_file
    temp_file=$(mktemp)
    
    cat > "${temp_file}" <<EOF
{
  "last_check": $(if [[ "${LAST_CHECK}" != "null" ]]; then echo "\"${LAST_CHECK}\""; else echo "null"; fi),
  "last_backup": $(if [[ "${LAST_BACKUP}" != "null" ]]; then echo "\"${LAST_BACKUP}\""; else echo "null"; fi),
  "last_tree_update": $(if [[ "${LAST_TREE_UPDATE}" != "null" ]]; then echo "\"${LAST_TREE_UPDATE}\""; else echo "null"; fi),
  "file_hashes": {
EOF

    local first=true
    for key in "${!FILE_HASHES[@]}"; do
        if [[ "${first}" == true ]]; then
            echo "    \"${key}\": \"${FILE_HASHES[${key}]}\"" >> "${temp_file}"
            first=false
        else
            echo "    ,\"${key}\": \"${FILE_HASHES[${key}]}\"" >> "${temp_file}"
        fi
    done
    
    cat >> "${temp_file}" <<EOF
  }
}
EOF
    
    mv "${temp_file}" "${state_file}"
}

get_file_hash() {
    local filepath="$1"
    if [[ -f "${filepath}" ]]; then
        md5sum "${filepath}" | cut -d' ' -f1
    else
        echo "null"
    fi
}

run_tree_command() {
    local output
    output=$(timeout 60 tree -a -L 8 "${WORKSPACE}" 2>&1)
    local ret=$?
    
    if [[ ${ret} -eq 0 ]]; then
        info "tree -a -L 8 erfolgreich ausgeführt"
        echo "${output}"
        return 0
    else
        error "tree command fehlgeschlagen: ${output}"
        return 1
    fi
}

update_tree_file() {
    local tree_output="$1"
    if [[ -z "${tree_output}" ]]; then
        return 1
    fi
    
    local tree_file="${IMPORTANT_DIR}/openclaw-tree.txt"
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    local header="# OpenClaw Workspace Tree
# Generiert: ${timestamp}
# Befehl: tree -a -L 8 ${WORKSPACE}
# Diese Datei wird automatisch von db-maintainer aktualisiert

"
    
    echo "${header}${tree_output}" > "${tree_file}"
    info "openclaw-tree.txt aktualisiert: ${tree_file}"
    return 0
}

scan_documentations() {
    local docs_list=()
    local find_pattern="-name '*.md'"
    
    while IFS= read -r -d '' file; do
        if [[ -f "${file}" ]] && [[ ! -L "${file}" ]]; then
            local rel_path
            rel_path=$(realpath --relative-to="${WORKSPACE}" "${file}")
            if [[ "${rel_path}" != *"db/backups"* ]] && [[ "${rel_path}" != *"node_modules"* ]]; then
                docs_list+=("${rel_path}")
            fi
        fi
    done < <(find "${WORKSPACE}" ${find_pattern} -print0 2>/dev/null)
    
    echo "${docs_list[@]}"
}

check_for_changes() {
    CHANGES=()
    local current_docs
    mapfile -t current_docs < <(scan_documentations)
    declare -A current_hashes
    
    # Check for new or changed files
    for doc_path in "${current_docs[@]}"; do
        local full_path="${WORKSPACE}/${doc_path}"
        local hash
        hash=$(get_file_hash "${full_path}")
        current_hashes["${doc_path}"]="${hash}"
        
        if [[ -z "${FILE_HASHES[${doc_path}]+isset}" ]]; then
            CHANGES+=("NEW: ${doc_path}")
        elif [[ "${FILE_HASHES[${doc_path}]}" != "${hash}" ]]; then
            CHANGES+=("CHANGED: ${doc_path}")
        fi
    done
    
    # Check for deleted files
    for old_path in "${!FILE_HASHES[@]}"; do
        local found=false
        for doc_path in "${current_docs[@]}"; do
            if [[ "${old_path}" == "${doc_path}" ]]; then
                found=true
                break
            fi
        done
        
        if [[ "${found}" == false ]]; then
            CHANGES+=("DELETED: ${old_path}")
        fi
    done
    
    # Return the current hashes by setting global variable
    FILE_HASHES=()
    for key in "${!current_hashes[@]}"; do
        FILE_HASHES["${key}"]="${current_hashes[${key}]}"
    done
}

update_databases() {
    local result
    result=$(timeout 60 python3 "${WORKSPACE}/scripts/update_docs_db.py" 2>&1)
    local ret=$?
    
    if [[ ${ret} -eq 0 ]]; then
        info "docs.db aktualisiert"
        return 0
    else
        error "DB-Update fehlgeschlagen: ${result}"
        return 1
    fi
}

update_tree_db_v2() {
    local result
    result=$(timeout 120 python3 "${WORKSPACE}/scripts/tree_indexer_v2.py" 2>&1)
    local ret=$?
    
    if [[ ${ret} -eq 0 ]]; then
        info "tree.db v2 aktualisiert"
        return 0
    else
        error "Tree-DB v2 fehlgeschlagen: ${result}"
        return 1
    fi
}

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

cleanup_old_backups() {
    local retention_days=3
    local cutoff
    cutoff=$(date -d "-${retention_days} days" +%s)
    local deleted=0
    
    for db_name in docs.db tree.db; do
        while IFS= read -r -d '' backup; do
            local basename
            basename=$(basename "${backup}")
            local date_part
            date_part=$(echo "${basename}" | cut -d'_' -f1)
            local time_part
            time_part=$(echo "${basename}" | cut -d'_' -f2)
            
            if [[ -n "${date_part}" && -n "${time_part}" ]]; then
                local backup_datestr="${date_part}_${time_part}"
                local backup_timestamp
                backup_timestamp=$(date -d "${backup_datestr//_/:}" +%s 2>/dev/null || echo "0")
                
                if [[ "${backup_timestamp}" -lt "${cutoff}" ]]; then
                    rm "${backup}"
                    ((deleted++))
                    info "Altes Backup gelöscht: ${basename}"
                fi
            else
                warn "Konnte Backup-Datum nicht parsen: ${basename}"
            fi
        done < <(find "${BACKUP_DIR}" -name "*_${db_name}.bak" -print0 2>/dev/null)
    done
    
    if [[ ${deleted} -eq 0 ]]; then
        info "Keine alten Backups zum Löschen"
    else
        info "${deleted} alte Backups gelöscht (< 3 Tage)"
    fi
}

run_cycle() {
    info "============================================================"
    info "DB MAINTAINER CYCLE START"
    info "============================================================"
    
    load_state
    
    # 1. Run tree command and write to openclaw-tree.txt
    info "Führe tree -a -L 8 aus..."
    local tree_output
    tree_output=$(run_tree_command) || true
    if [[ -n "${tree_output}" ]]; then
        update_tree_file "${tree_output}"
        LAST_TREE_UPDATE=$(date --iso-8601=seconds)
    fi
    
    # 2. Update tree.db v2
    info "Aktualisiere tree.db v2..."
    update_tree_db_v2 >/dev/null 2>&1 || true
    
    # 3. Check for changes
    info "Prüfe auf Dokumentations-Änderungen..."
    check_for_changes
    
    if [[ ${#CHANGES[@]} -gt 0 ]]; then
        info "${#CHANGES[@]} Änderungen gefunden:"
        local i=0
        for change in "${CHANGES[@]}"; do
            if [[ ${i} -lt 10 ]]; then
                info "  - ${change}"
            fi
            ((i++))
        done
        if [[ ${#CHANGES[@]} -gt 10 ]]; then
            info "  ... und $(( ${#CHANGES[@]} - 10 )) weitere"
        fi
        
        # 4. Update docs.db
        info "Aktualisiere docs.db..."
        if update_databases; then
            LAST_CHECK=$(date --iso-8601=seconds)
        fi
    else
        info "Keine Dokumentations-Änderungen gefunden"
    fi
    
    # 5. Check if backup is due (hourly)
    local do_backup=false
    if [[ "${LAST_BACKUP}" == "null" ]]; then
        do_backup=true
    else
        local last_backup_timestamp
        last_backup_timestamp=$(date -d "${LAST_BACKUP}" +%s 2>/dev/null || echo "0")
        local now_timestamp
        now_timestamp=$(date +%s)
        local diff_hours
        diff_hours=$(( (now_timestamp - last_backup_timestamp) / 3600 ))
        
        if [[ ${diff_hours} -ge 1 ]]; then
            do_backup=true
        fi
    fi
    
    if [[ "${do_backup}" == true ]]; then
        info "Erstelle stündliches Backup..."
        local timestamp
        timestamp=$(create_backup)
        LAST_BACKUP=$(date --iso-8601=seconds)
        
        # 6. Clean up old backups (3 days retention)
        info "Räume alte Backups auf (3 Tage Retention)..."
        cleanup_old_backups
    else
        info "Backup nicht nötig (letztes < 1h)"
    fi
    
    save_state
    
    info "============================================================"
    info "DB MAINTAINER CYCLE END"
    info "============================================================"
}

main() {
    trap 'error "CRITICAL ERROR: Script terminated unexpectedly"' ERR
    
    run_cycle
}

main "$@"
