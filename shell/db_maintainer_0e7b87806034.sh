#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "9d7c35b942b05ccbd52f2864ccff33dd47be4d1bad55dc36ea33f7ed8bab118a", "source_sha256": "3ee904e4ee842489bd9bef8522f5a93fc06583e6cb1c3c5243afae19a4e2ed5f", "target_language": "shell"}
# db_maintainer.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_DIR="${WORKSPACE}/db"
readonly BACKUP_DIR="${DB_DIR}/backups"
readonly LOG_DIR="${WORKSPACE}/logs/db-maintainer"
readonly IMPORTANT_DIR="${WORKSPACE}/important"

# Verzeichnisse erstellen
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

# Globale Variablen für Zustand
declare -A file_hashes
declare -A state_vars

# Logger Funktionen
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

# Hilfsfunktionen
get_file_hash() {
    local filepath="$1"
    if [[ -f "${filepath}" ]]; then
        md5sum "${filepath}" | cut -d' ' -f1
    else
        echo ""
    fi
}

load_state() {
    local state_file="${DB_DIR}/maintainer_state.json"
    if [[ -f "${state_file}" ]]; then
        # Parsen des JSON-Zustands (vereinfacht)
        while IFS="=" read -r key value; do
            if [[ $key == "last_check" ]] || [[ $key == "last_backup" ]] || [[ $key == "last_tree_update" ]]; then
                state_vars[$key]="$value"
            fi
        done < <(grep -E '"last_check"|"last_backup"|"last_tree_update"' "${state_file}" | sed 's/[", ]//g')
    else
        state_vars["last_check"]=""
        state_vars["last_backup"]=""
        state_vars["last_tree_update"]=""
    fi
}

save_state() {
    local state_file="${DB_DIR}/maintainer_state.json"
    {
        echo "{"
        echo "  \"last_check\": \"${state_vars[last_check]}\","
        echo "  \"last_backup\": \"${state_vars[last_backup]}\","
        echo "  \"last_tree_update\": \"${state_vars[last_tree_update]}\","
        echo "  \"file_hashes\": {"
        for file in "${!file_hashes[@]}"; do
            echo "    \"${file}\": \"${file_hashes[$file]}\","
        done | sed '$ s/,$//'
        echo "  }"
        echo "}"
    } > "${state_file}"
}

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

update_tree_file() {
    local tree_output="$1"
    if [[ -z "${tree_output}" ]]; then
        return 1
    fi
    
    local tree_file="${IMPORTANT_DIR}/openclaw-tree.txt"
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    {
        echo "# OpenClaw Workspace Tree"
        echo "# Generiert: ${timestamp}"
        echo "# Befehl: tree -a -L 8 ${WORKSPACE}"
        echo "# Diese Datei wird automatisch von db-maintainer aktualisiert"
        echo ""
        echo "${tree_output}"
    } > "${tree_file}"
    
    info "openclaw-tree.txt aktualisiert: ${tree_file}"
    return 0
}

scan_documentations() {
    local docs_list=()
    local temp_file
    temp_file=$(mktemp)
    
    find "${WORKSPACE}" -name "*.md" ! -path "${DB_DIR}/backups/*" ! -path "*/node_modules/*" -type f > "${temp_file}"
    
    while IFS= read -r filepath; do
        local rel_path
        rel_path=${filepath#"${WORKSPACE}/"}
        local hash
        hash=$(get_file_hash "${filepath}")
        local mtime
        mtime=$(stat -c %Y "${filepath}")
        docs_list+=("${rel_path}|${hash}|${mtime}")
    done < "${temp_file}"
    
    rm -f "${temp_file}"
    echo "${docs_list[@]}"
}

check_for_changes() {
    local current_docs
    current_docs=$(scan_documentations)
    
    local changes=()
    local new_hashes=()
    
    # Aktuelle Hashes verarbeiten
    while IFS='|' read -ra doc_info <<< "${current_docs}"; do
        for item in "${doc_info[@]}"; do
            if [[ $item =~ ^(.+)\|(.+)\|(.+)$ ]]; then
                local path="${BASH_REMATCH[1]}"
                local hash="${BASH_REMATCH[2]}"
                new_hashes+=("${path}=${hash}")
                
                if [[ -z "${file_hashes[$path]:-}" ]]; then
                    changes+=("NEW: ${path}")
                elif [[ "${file_hashes[$path]}" != "${hash}" ]]; then
                    changes+=("CHANGED: ${path}")
                fi
            fi
        done
    done <<< "${current_docs}"
    
    # Auf gelöschte Dateien prüfen
    for old_path in "${!file_hashes[@]}"; do
        local found=false
        while IFS='|' read -ra doc_info <<< "${current_docs}"; do
            for item in "${doc_info[@]}"; do
                if [[ $item =~ ^(.+)\|(.+)\|(.+)$ ]]; then
                    local path="${BASH_REMATCH[1]}"
                    if [[ $path == "$old_path" ]]; then
                        found=true
                        break
                    fi
                fi
            done
        done <<< "${current_docs}"
        
        if [[ $found == false ]]; then
            changes+=("DELETED: ${old_path}")
        fi
    done
    
    # Neue Hashes setzen
    for entry in "${new_hashes[@]}"; do
        IFS='=' read -r key val <<< "${entry}"
        file_hashes["$key"]="$val"
    done
    
    printf '%s\n' "${changes[@]}"
}

update_databases() {
    local result
    result=$(timeout 60 python3 "${WORKSPACE}/scripts/update_docs_db.py" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
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
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
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
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "-3 days" +%s)
    local deleted=0
    
    for db_name in docs.db tree.db; do
        while IFS= read -r backup; do
            local filename
            filename=$(basename "${backup}")
            if [[ $filename =~ ([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2})_${db_name}\.bak ]]; then
                local date_part="${BASH_REMATCH[1]}"
                local time_part="${BASH_REMATCH[2]}"
                local backup_datetime="${date_part} ${time_part//-/:}"
                local backup_timestamp
                backup_timestamp=$(date -d "${backup_datetime}" +%s 2>/dev/null || echo "0")
                
                if [[ $backup_timestamp -lt $cutoff_timestamp ]] && [[ $backup_timestamp -gt 0 ]]; then
                    rm -f "${backup}"
                    deleted=$((deleted + 1))
                    info "Altes Backup gelöscht: ${filename}"
                fi
            else
                warn "Konnte Backup-Datum nicht parsen: ${filename}"
            fi
        done < <(find "${BACKUP_DIR}" -name "*_${db_name}.bak" -type f)
    done
    
    if [[ $deleted -eq 0 ]]; then
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
    
    # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    info "Führe tree -a -L 8 aus..."
    local tree_output
    tree_output=$(run_tree_command) || true
    if [[ -n "${tree_output}" ]]; then
        update_tree_file "${tree_output}"
        state_vars["last_tree_update"]=$(date --iso-8601=seconds)
    fi
    
    # 2. tree.db aktualisieren (intern v2)
    info "Aktualisiere tree.db v2..."
    update_tree_db_v2 || true
    
    # 3. Änderungen prüfen
    info "Prüfe auf Dokumentations-Änderungen..."
    local changes
    changes=$(check_for_changes)
    
    if [[ -n "${changes}" ]]; then
        local change_count
        change_count=$(wc -l <<< "${changes}")
        info "${change_count} Änderungen gefunden:"
        local i=0
        while IFS= read -r change; do
            if [[ $i -lt 10 ]]; then
                info "  - ${change}"
            elif [[ $i -eq 10 ]]; then
                info "  ... und $((change_count-10)) weitere"
                break
            fi
            i=$((i+1))
        done <<< "${changes}"
        
        # 4. docs.db aktualisieren
        info "Aktualisiere docs.db..."
        if update_databases; then
            state_vars["last_check"]=$(date --iso-8601=seconds)
        fi
    else
        info "Keine Dokumentations-Änderungen gefunden"
    fi
    
    # 5. Prüfe ob Backup fällig (stündlich)
    local do_backup=false
    if [[ -n "${state_vars[last_backup]:-}" ]]; then
        local last_backup_timestamp
        last_backup_timestamp=$(date -d "${state_vars[last_backup]}" +%s 2>/dev/null || echo "0")
        local now_timestamp
        now_timestamp=$(date +%s)
        local diff_hours
        diff_hours=$(( (now_timestamp - last_backup_timestamp) / 3600 ))
        
        if [[ $diff_hours -ge 1 ]]; then
            do_backup=true
        fi
    else
        do_backup=true
    fi
    
    if [[ $do_backup == true ]]; then
        info "Erstelle stündliches Backup..."
        local timestamp
        timestamp=$(create_backup)
        state_vars["last_backup"]=$(date --iso-8601=seconds)
        
        # 6. Alte Backups aufräumen (3 Tage Retention)
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
    trap 'error "CRITICAL ERROR: $?"' ERR
    
    run_cycle
}

main "$@"
