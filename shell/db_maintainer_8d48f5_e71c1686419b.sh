#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "6a3ec805c42897a0e0217a639dc7196947d90917ceced8549abd9c5daa60f56b", "source_sha256": "8d48f51942bb1c171bbd41e0696beb0722cb4b94d6596233f54b32928b645086", "target_language": "shell"}
# db_maintainer.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

# Konfiguration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE="${OPENCLAW_WORKSPACE:-$(realpath "$SCRIPT_DIR/../")}"
readonly DB_DIR="$WORKSPACE"
readonly BACKUP_DIR="$WORKSPACE/db/backups"
readonly LOG_DIR="$WORKSPACE/logs/db-maintainer"
readonly IMPORTANT_DIR="$WORKSPACE/important"
readonly STATE_FILE="$DB_DIR/maintainer_state.json"

# Verzeichnisse erstellen
mkdir -p "$BACKUP_DIR" "$LOG_DIR" "$IMPORTANT_DIR"

# Globale Variablen
declare LOG_FILE=""
declare CURRENT_DATE=""

# Logger Funktionen
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[${timestamp}] [${level}] ${message}"
    echo "$line"
    echo "$line" >> "$LOG_FILE"
}

info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }

# Hilfsfunktionen
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"last_check": null, "last_backup": null, "last_tree_update": null, "file_hashes": {}}'
    fi
}

save_state() {
    local state="$1"
    echo "$state" > "$STATE_FILE"
}

get_file_hash() {
    local filepath="$1"
    if [[ -f "$filepath" ]]; then
        md5sum "$filepath" | cut -d' ' -f1
    else
        echo ""
    fi
}

python_tree_fallback() {
    local max_depth=8
    local root="$WORKSPACE"
    echo "$root"
    
    walk() {
        local dirpath="$1"
        local prefix="$2"
        local depth="$3"
        
        if (( depth > max_depth )); then
            return
        fi
        
        local entries
        mapfile -t entries < <(find "$dirpath" -maxdepth 1 -not -path "$dirpath" -print0 | xargs -0 ls -1d 2>/dev/null | sort)
        
        local i=0
        local total=${#entries[@]}
        
        for entry in "${entries[@]}"; do
            local basename_entry
            basename_entry=$(basename "$entry")
            local connector="├── "
            if (( i == total - 1 )); then
                connector="└── "
            fi
            
            echo "${prefix}${connector}${basename_entry}"
            
            if [[ -d "$entry" ]] && [[ ! -L "$entry" ]]; then
                local extension="│   "
                if (( i == total - 1 )); then
                    extension="    "
                fi
                walk "$entry" "${prefix}${extension}" $((depth + 1))
            fi
            ((i++))
        done
    }
    
    walk "$root" "" 1
}

run_tree_command() {
    local output
    if command -v tree >/dev/null 2>&1; then
        output=$(timeout 60 tree -a -L 8 "$WORKSPACE" 2>&1)
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            info "tree -a -L 8 erfolgreich ausgeführt"
            echo "$output"
        else
            warn "tree command fehlgeschlagen: $(echo "$output" | tr '\n' ' ') – nutze Python-Fallback"
            python_tree_fallback
        fi
    else
        warn "tree-Binary nicht installiert – nutze Python-Fallback"
        python_tree_fallback
    fi
}

update_tree_file() {
    local tree_output="$1"
    if [[ -z "$tree_output" ]]; then
        return 1
    fi
    
    local tree_file="$IMPORTANT_DIR/openclaw-tree.txt"
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    cat > "$tree_file" <<EOF
# OpenClaw Workspace Tree
# Generiert: $timestamp
# Befehl: tree -a -L 8 $WORKSPACE
# Diese Datei wird automatisch von db-maintainer aktualisiert

$tree_output
EOF
    
    info "openclaw-tree.txt aktualisiert: $tree_file"
    return 0
}

scan_documentations() {
    local temp_file
    temp_file=$(mktemp)
    
    find "$WORKSPACE" -type f -name "*.md" ! -path "*/db/backups/*" ! -path "*/node_modules/*" | while read -r file; do
        local rel_path
        rel_path=$(realpath --relative-to="$WORKSPACE" "$file")
        local hash
        hash=$(get_file_hash "$file")
        local mtime
        mtime=$(stat -c %Y "$file")
        echo "$rel_path|$hash|$mtime"
    done > "$temp_file"
    
    echo "$temp_file"
}

check_for_changes() {
    local temp_docs="$1"
    local state
    state=$(load_state)
    local temp_changes
    temp_changes=$(mktemp)
    
    # Neue und geänderte Dateien finden
    while IFS='|' read -r path hash _; do
        local old_hash
        old_hash=$(echo "$state" | jq -r ".file_hashes.\"$path\" // \"\"")
        
        if [[ -z "$old_hash" ]]; then
            echo "NEW: $path" >> "$temp_changes"
        elif [[ "$old_hash" != "$hash" ]]; then
            echo "CHANGED: $path" >> "$temp_changes"
        fi
    done < "$temp_docs"
    
    # Gelöschte Dateien finden
    local paths_in_docs
    paths_in_docs=$(cut -d'|' -f1 "$temp_docs")
    echo "$state" | jq -r '.file_hashes | keys[]' | while read -r old_path; do
        if ! grep -q "^${old_path}$" <<< "$paths_in_docs" 2>/dev/null; then
            echo "DELETED: $old_path" >> "$temp_changes"
        fi
    done
    
    echo "$temp_changes"
}

update_databases() {
    local result
    result=$(timeout 60 python3 "$WORKSPACE/scripts/update_docs_db.py" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        info "docs.db aktualisiert"
        return 0
    else
        error "DB-Update fehlgeschlagen: $result"
        return 1
    fi
}

update_tree_db_v2() {
    local result
    result=$(timeout 120 python3 "$WORKSPACE/scripts/tree_indexer_v2.py" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        info "tree.db v2 aktualisiert"
        return 0
    else
        error "Tree-DB v2 fehlgeschlagen: $result"
        return 1
    fi
}

create_backup() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M')
    
    for db_name in docs.db tree.db; do
        local source="$DB_DIR/$db_name"
        if [[ -f "$source" ]]; then
            local backup_name="${timestamp}_${db_name}.bak"
            local backup_path="$BACKUP_DIR/$backup_name"
            cp "$source" "$backup_path"
            info "Backup erstellt: $backup_name"
        fi
    done
    
    echo "$timestamp"
}

cleanup_old_backups() {
    local retention_days=3
    local cutoff
    cutoff=$(date -d "$retention_days days ago" +%s)
    local deleted=0
    
    for db_name in docs.db tree.db; do
        find "$BACKUP_DIR" -name "*_${db_name}.bak" | while read -r backup; do
            local filename
            filename=$(basename "$backup")
            local date_part
            date_part=$(echo "$filename" | cut -d'_' -f1)
            local time_part
            time_part=$(echo "$filename" | cut -d'_' -f2)
            
            if [[ -n "$date_part" ]] && [[ -n "$time_part" ]]; then
                local backup_time
                backup_time=$(date -d "${date_part}_${time_part}" +%s 2>/dev/null) || continue
                
                if [[ $backup_time -lt $cutoff ]]; then
                    rm "$backup"
                    ((deleted++))
                    info "Altes Backup gelöscht: $filename"
                fi
            else
                warn "Konnte Backup-Datum nicht parsen: $filename"
            fi
        done
    done
    
    if [[ $deleted -eq 0 ]]; then
        info "Keine alten Backups zum Löschen"
    else
        info "$deleted alte Backups gelöscht (< 3 Tage)"
    fi
}

run_cycle() {
    info "============================================================"
    info "DB MAINTAINER CYCLE START"
    info "============================================================"
    
    local state
    state=$(load_state)
    
    # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    info "Führe tree -a -L 8 aus..."
    local tree_output
    tree_output=$(run_tree_command)
    if [[ -n "$tree_output" ]]; then
        update_tree_file "$tree_output"
        state=$(echo "$state" | jq ".last_tree_update = \"$(date --iso-8601=seconds)\"")
    fi
    
    # 2. tree.db aktualisieren (intern v2)
    info "Aktualisiere tree.db v2..."
    update_tree_db_v2
    
    # 3. Änderungen prüfen
    info "Prüfe auf Dokumentations-Änderungen..."
    local temp_docs
    temp_docs=$(scan_documentations)
    local temp_changes
    temp_changes=$(check_for_changes "$temp_docs")
    local changes_count
    changes_count=$(wc -l < "$temp_changes" | tr -d ' ')
    
    if [[ $changes_count -gt 0 ]]; then
        info "$changes_count Änderungen gefunden:"
        head -10 "$temp_changes" | while read -r change; do
            info "  - $change"
        done
        
        if [[ $changes_count -gt 10 ]]; then
            info "  ... und $((changes_count-10)) weitere"
        fi
        
        # 4. docs.db aktualisieren
        info "Aktualisiere docs.db..."
        if update_databases; then
            state=$(echo "$state" | jq ".last_check = \"$(date --iso-8601=seconds)\"")
            
            # Aktualisiere file_hashes
            local new_hashes
            new_hashes=$(mktemp)
            echo "{}" > "$new_hashes"
            while IFS='|' read -r path hash _; do
                echo "$new_hashes" | jq ".\"$path\" = \"$hash\"" > "${new_hashes}.tmp" && mv "${new_hashes}.tmp" "$new_hashes"
            done < "$temp_docs"
            state=$(echo "$state" | jq ".file_hashes = $(cat "$new_hashes")")
            rm "$new_hashes"
        fi
    else
        info "Keine Dokumentations-Änderungen gefunden"
    fi
    
    # 5. Prüfe ob Backup fällig (stündlich)
    local last_backup
    last_backup=$(echo "$state" | jq -r '.last_backup // ""')
    local do_backup=false
    
    if [[ -z "$last_backup" ]]; then
        do_backup=true
    else
        local last_backup_time
        last_backup_time=$(date -d "$last_backup" +%s)
        local current_time
        current_time=$(date +%s)
        local diff_hours
        diff_hours=$(( (current_time - last_backup_time) / 3600 ))
        
        if [[ $diff_hours -ge 1 ]]; then
            do_backup=true
        fi
    fi
    
    if [[ "$do_backup" == true ]]; then
        info "Erstelle stündliches Backup..."
        local timestamp
        timestamp=$(create_backup)
        state=$(echo "$state" | jq ".last_backup = \"$(date --iso-8601=seconds)\"")
        
        # 6. Alte Backups aufräumen (3 Tage Retention)
        info "Räume alte Backups auf (3 Tage Retention)..."
        cleanup_old_backups
    else
        info "Backup nicht nötig (letztes < 1h)"
    fi
    
    save_state "$state"
    
    # Temporäre Dateien aufräumen
    [[ -f "$temp_docs" ]] && rm "$temp_docs"
    [[ -f "$temp_changes" ]] && rm "$temp_changes"
    
    info "============================================================"
    info "DB MAINTAINER CYCLE END"
    info "============================================================"
}

main() {
    CURRENT_DATE=$(date '+%Y-%m-%d')
    LOG_FILE="$LOG_DIR/${CURRENT_DATE}.log"
    
    run_cycle
}

main "$@"
