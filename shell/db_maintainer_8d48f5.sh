#!/bin/bash
# db_maintainer.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

# Konfiguration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$(dirname "$SCRIPT_DIR")}"
readonly DB_DIR="$OPENCLAW_WORKSPACE"
readonly BACKUP_DIR="$OPENCLAW_WORKSPACE/db/backups"
readonly LOG_DIR="$OPENCLAW_WORKSPACE/logs/db-maintainer"
readonly IMPORTANT_DIR="$OPENCLAW_WORKSPACE/important"
readonly STATE_FILE="$DB_DIR/maintainer_state.json"

# Verzeichnisse erstellen
mkdir -p "$BACKUP_DIR" "$LOG_DIR" "$IMPORTANT_DIR"

# Globale Variablen
RETENTION_DAYS=3


# Logger Funktionen
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[${timestamp}] [${level}] ${message}"
    echo "$line"
    local today
    today=$(date '+%Y-%m-%d')
    echo "$line" >> "$LOG_DIR/${today}.log"
}

info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }


# JSON Hilfsfunktionen
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"last_check": null, "last_backup": null, "last_tree_update": null, "file_hashes": {}}'
    fi
}

save_state() {
    local state_json="$1"
    echo "$state_json" > "$STATE_FILE"
}


# Hash Funktion
get_file_hash() {
    local filepath="$1"
    if [[ -f "$filepath" ]]; then
        md5sum "$filepath" | cut -d' ' -f1
    else
        echo ""
    fi
}


# Python-Fallback für tree
_python_tree_fallback() {
    local max_depth=${1:-8}
    local output=""
    local root="$OPENCLAW_WORKSPACE"
    
    output+="$root"$'\n'
    
    walk() {
        local dirpath="$1"
        local prefix="$2"
        local depth="$3"
        
        if (( depth > max_depth )); then
            return
        fi
        
        local entries
        mapfile -t entries < <(find "$dirpath" -mindepth 1 -maxdepth 1 2>/dev/null | sort)
        
        local i=0
        local total=${#entries[@]}
        
        for entry in "${entries[@]}"; do
            local basename_entry
            basename_entry=$(basename "$entry")
            local connector="├── "
            
            if (( i == total - 1 )); then
                connector="└── "
            fi
            
            output+="${prefix}${connector}${basename_entry}"$'\n'
            
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
    echo "$output"
}


run_tree_command() {
    local tree_output=""
    
    if command -v tree >/dev/null 2>&1; then
        if tree_output=$(timeout 60 tree -a -L 8 "$OPENCLAW_WORKSPACE" 2>/dev/null); then
            info "tree -a -L 8 erfolgreich ausgeführt"
            echo "$tree_output"
        else
            warn "tree command fehlgeschlagen – nutze Python-Fallback"
            _python_tree_fallback
        fi
    else
        warn "tree-Binary nicht installiert – nutze Python-Fallback"
        _python_tree_fallback
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
    
    local header="# OpenClaw Workspace Tree
# Generiert: $timestamp
# Befehl: tree -a -L 8 $OPENCLAW_WORKSPACE
# Diese Datei wird automatisch von db-maintainer aktualisiert

"
    
    {
        echo "$header"
        echo "$tree_output"
    } > "$tree_file"
    
    info "openclaw-tree.txt aktualisiert: $tree_file"
    return 0
}


scan_documentations() {
    local docs_json="{"
    local first=true
    
    while IFS= read -r -d '' file; do
        local rel_path
        rel_path="${file#$OPENCLAW_WORKSPACE/}"
        
        # Skip files in db/backups and node_modules
        if [[ "$rel_path" == db/backups/* ]] || [[ "$rel_path" == */node_modules/* ]] || [[ "$rel_path" == node_modules/* ]]; then
            continue
        fi
        
        local hash
        hash=$(get_file_hash "$file")
        local mtime
        mtime=$(stat -c %Y "$file" 2>/dev/null || echo "0")
        
        if [[ "$first" == true ]]; then
            first=false
        else
            docs_json+=","
        fi
        
        docs_json+="\"$rel_path\":{\"hash\":\"$hash\",\"mtime\":$mtime}"
    done < <(find "$OPENCLAW_WORKSPACE" -name "*.md" -type f -print0 2>/dev/null || true)
    
    docs_json+="}"
    echo "$docs_json"
}


check_for_changes() {
    local state_json="$1"
    local current_docs_json="$2"
    
    local changes_file="/tmp/db_maintainer_changes_$$"
    : > "$changes_file"
    
    # Parse current docs
    local current_paths=()
    while IFS= read -r line; do
        current_paths+=("$line")
    done < <(echo "$current_docs_json" | jq -r 'keys[]' 2>/dev/null || echo "")
    
    # Check for new or changed files
    for path in "${current_paths[@]}"; do
        local current_hash
        current_hash=$(echo "$current_docs_json" | jq -r ".[\"$path\"].hash" 2>/dev/null || echo "")
        local old_hash
        old_hash=$(echo "$state_json" | jq -r ".file_hashes.\"$path\"" 2>/dev/null || echo "null")
        
        if [[ "$old_hash" == "null" ]]; then
            echo "NEW: $path" >> "$changes_file"
        elif [[ "$old_hash" != "$current_hash" ]]; then
            echo "CHANGED: $path" >> "$changes_file"
        fi
    done
    
    # Check for deleted files
    local old_paths=()
    while IFS= read -r line; do
        old_paths+=("$line")
    done < <(echo "$state_json" | jq -r '.file_hashes | keys[]' 2>/dev/null || echo "")
    
    for old_path in "${old_paths[@]}"; do
        local found=false
        for current_path in "${current_paths[@]}"; do
            if [[ "$old_path" == "$current_path" ]]; then
                found=true
                break
            fi
        done
        
        if [[ "$found" == false ]]; then
            echo "DELETED: $old_path" >> "$changes_file"
        fi
    done
    
    cat "$changes_file"
    rm -f "$changes_file"
}


update_databases() {
    local script_path="$OPENCLAW_WORKSPACE/scripts/update_docs_db.py"
    
    if [[ -f "$script_path" ]]; then
        if timeout 60 python3 "$script_path" >/dev/null 2>&1; then
            info "docs.db aktualisiert"
            return 0
        else
            error "DB-Update fehlgeschlagen"
            return 1
        fi
    else
        error "DB-Update Script nicht gefunden: $script_path"
        return 1
    fi
}


update_tree_db_v2() {
    local script_path="$OPENCLAW_WORKSPACE/scripts/tree_indexer_v2.py"
    
    if [[ -f "$script_path" ]]; then
        if timeout 120 python3 "$script_path" >/dev/null 2>&1; then
            info "tree.db v2 aktualisiert"
            return 0
        else
            error "Tree-DB v2 fehlgeschlagen"
            return 1
        fi
    else
        error "Tree-DB v2 Script nicht gefunden: $script_path"
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
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "-$RETENTION_DAYS days" +%s)
    local deleted=0
    
    for db_name in docs.db tree.db; do
        while IFS= read -r backup; do
            local filename
            filename=$(basename "$backup")
            local date_part
            date_part=$(echo "$filename" | cut -d'_' -f1)
            local time_part
            time_part=$(echo "$filename" | cut -d'_' -f2)
            
            if [[ -n "$date_part" ]] && [[ -n "$time_part" ]]; then
                local backup_datestr="${date_part}_${time_part%.*}"
                local backup_timestamp
                backup_timestamp=$(date -d "$backup_datestr" +%s 2>/dev/null || echo "0")
                
                if (( backup_timestamp < cutoff_timestamp )); then
                    rm -f "$backup"
                    ((deleted++))
                    info "Altes Backup gelöscht: $filename"
                fi
            else
                warn "Konnte Backup-Datum nicht parsen: $filename"
            fi
        done < <(find "$BACKUP_DIR" -name "*_${db_name}.bak" -type f 2>/dev/null || true)
    done
    
    if (( deleted == 0 )); then
        info "Keine alten Backups zum Löschen"
    else
        info "$deleted alte Backups gelöscht (< 3 Tage)"
    fi
}


run_cycle() {
    info "============================================================"
    info "DB MAINTAINER CYCLE START"
    info "============================================================"
    
    local state_json
    state_json=$(load_state)
    
    # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    info "Führe tree -a -L 8 aus..."
    local tree_output
    tree_output=$(run_tree_command)
    if [[ -n "$tree_output" ]]; then
        update_tree_file "$tree_output"
        state_json=$(echo "$state_json" | jq ".last_tree_update=\"$(date --iso-8601=seconds)\"")
    fi
    
    # 2. tree.db aktualisieren (intern v2)
    info "Aktualisiere tree.db v2..."
    update_tree_db_v2
    
    # 3. Änderungen prüfen
    info "Prüfe auf Dokumentations-Änderungen..."
    local current_docs_json
    current_docs_json=$(scan_documentations)
    local changes
    changes=$(check_for_changes "$state_json" "$current_docs_json")
    
    if [[ -n "$changes" ]]; then
        local changes_count
        changes_count=$(echo "$changes" | wc -l)
        info "$changes_count Änderungen gefunden:"
        echo "$changes" | head -10 | while read -r change; do
            info "  - $change"
        done
        if (( changes_count > 10 )); then
            info "  ... und $((changes_count-10)) weitere"
        fi
        
        # 4. docs.db aktualisieren
        info "Aktualisiere docs.db..."
        if update_databases; then
            state_json=$(echo "$state_json" | jq ".last_check=\"$(date --iso-8601=seconds)\"")
            
            # Update file hashes in state
            local new_file_hashes="{"
            local first=true
            while IFS= read -r path; do
                local hash
                hash=$(echo "$current_docs_json" | jq -r ".[\"$path\"].hash" 2>/dev/null || echo "")
                if [[ "$first" == true ]]; then
                    first=false
                else
                    new_file_hashes+=","
                fi
                new_file_hashes+="\"$path\":\"$hash\""
            done < <(echo "$current_docs_json" | jq -r 'keys[]' 2>/dev/null || echo "")
            new_file_hashes+="}"
            
            state_json=$(echo "$state_json" | jq ".file_hashes=$new_file_hashes")
        fi
    else
        info "Keine Dokumentations-Änderungen gefunden"
    fi
    
    # 5. Prüfe ob Backup fällig (stündlich)
    local last_backup
    last_backup=$(echo "$state_json" | jq -r '.last_backup // empty')
    local do_backup=false
    
    if [[ -z "$last_backup" ]]; then
        do_backup=true
    else
        local last_backup_timestamp
        last_backup_timestamp=$(date -d "$last_backup" +%s 2>/dev/null || echo "0")
        local current_timestamp
        current_timestamp=$(date +%s)
        local diff_hours
        diff_hours=$(( (current_timestamp - last_backup_timestamp) / 3600 ))
        
        if (( diff_hours >= 1 )); then
            do_backup=true
        fi
    fi
    
    if [[ "$do_backup" == true ]]; then
        info "Erstelle stündliches Backup..."
        local timestamp
        timestamp=$(create_backup)
        state_json=$(echo "$state_json" | jq ".last_backup=\"$timestamp\"")
        
        # 6. Alte Backups aufräumen (3 Tage Retention)
        info "Räume alte Backups auf (3 Tage Retention)..."
        cleanup_old_backups
    else
        info "Backup nicht nötig (letztes < 1h)"
    fi
    
    save_state "$state_json"
    
    info "============================================================"
    info "DB MAINTAINER CYCLE END"
    info "============================================================"
}


main() {
    if ! command -v jq >/dev/null 2>&1; then
        error "jq ist erforderlich, aber nicht installiert"
        exit 1
    fi
    
    if run_cycle; then
        exit 0
    else
        error "CRITICAL ERROR im Hauptprogramm"
        exit 1
    fi
}


main "$@"
