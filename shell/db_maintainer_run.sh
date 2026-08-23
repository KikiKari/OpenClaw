#!/bin/bash
# db_maintainer_run.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer_run.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

WORKSPACE="/workspace"
DB_DIR="$WORKSPACE/db"
BACKUP_DIR="$DB_DIR/backups"
LOG_DIR="$WORKSPACE/logs/db-maintainer"
IMPORTANT_DIR="$WORKSPACE/important"

# Verzeichnisse erstellen
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

# Globale Variablen für den Zustand
STATE_FILE="$DB_DIR/maintainer_state.json"
RETENTION_DAYS=3

# Logger Funktionen
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[$timestamp] [$level] $message"
    echo "$line"
    local today
    today=$(date '+%Y-%m-%d')
    echo "$line" >> "$LOG_DIR/$today.log"
}

info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }

# Zustandsmanagement
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"last_check": null, "last_backup": null, "last_tree_update": null, "file_hashes": {}}'
    fi
}

save_state() {
    local state="$1"
    echo "$state" | jq . > "$STATE_FILE"
}

# Datei-Hash-Berechnung
get_file_hash() {
    local filepath="$1"
    if [[ -f "$filepath" ]]; then
        md5sum "$filepath" | cut -d' ' -f1
    else
        echo "null"
    fi
}

# Tree-Befehl ausführen
run_tree_command() {
    local output
    output=$(timeout 60 tree -a -L 6 "$WORKSPACE" 2>/dev/null) && {
        info "tree -a -L 6 erfolgreich ausgeführt"
        echo "$output"
    } || {
        error "tree command fehlgeschlagen"
        echo "null"
    }
}

# Tree-Datei aktualisieren
update_tree_file() {
    local tree_output="$1"
    if [[ "$tree_output" == "null" ]] || [[ -z "$tree_output" ]]; then
        return 1
    fi

    local tree_file="$IMPORTANT_DIR/openclaw-tree.txt"
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    cat > "$tree_file" <<EOF
# OpenClaw Workspace Tree
# Generiert: $timestamp
# Befehl: tree -a -L 6 $WORKSPACE
# Diese Datei wird automatisch von db-maintainer aktualisiert

$tree_output
EOF
    
    info "openclaw-tree.txt aktualisiert: $tree_file"
    return 0
}

# Dokumentationen scannen
scan_documentations() {
    local temp_file
    temp_file=$(mktemp)
    
    find "$WORKSPACE" -name "*.md" ! -path "*/db/backups/*" ! -path "*/node_modules/*" -type f | while read -r file; do
        local rel_path
        rel_path="${file#$WORKSPACE/}"
        local hash
        hash=$(get_file_hash "$file")
        local mtime
        mtime=$(stat -c %Y "$file")
        echo "{\"path\":\"$rel_path\",\"hash\":\"$hash\",\"mtime\":$mtime}"
    done > "$temp_file"
    
    echo "$temp_file"
}

# Auf Änderungen prüfen
check_for_changes() {
    local state="$1"
    local docs_temp="$2"
    local changes_file
    changes_file=$(mktemp)
    
    # Aktuelle Hashes laden
    local current_hashes_temp
    current_hashes_temp=$(mktemp)
    
    jq -r '.file_hashes | to_entries[] | "\(.key):\(.value)"' <<<"$state" > "$current_hashes_temp" 2>/dev/null || true
    
    # Prüfe auf neue/geänderte Dateien
    while IFS= read -r doc_json; do
        local path
        path=$(jq -r '.path' <<<"$doc_json")
        local hash
        hash=$(jq -r '.hash' <<<"$doc_json")
        
        local found_in_state
        found_in_state=$(grep -c "^$path:" "$current_hashes_temp" 2>/dev/null || echo "0")
        
        if [[ "$found_in_state" -eq 0 ]]; then
            echo "NEW: $path" >> "$changes_file"
        else
            local old_hash
            old_hash=$(grep "^$path:" "$current_hashes_temp" | cut -d':' -f2)
            if [[ "$old_hash" != "$hash" ]]; then
                echo "CHANGED: $path" >> "$changes_file"
            fi
        fi
    done < "$docs_temp"
    
    # Prüfe auf gelöschte Dateien
    jq -r '.file_hashes | keys[]' <<<"$state" | while read -r old_path; do
        if ! grep -q "\"path\":\"$old_path\"" "$docs_temp" 2>/dev/null; then
            echo "DELETED: $old_path" >> "$changes_file"
        fi
    done 2>/dev/null || true
    
    echo "$changes_file"
}

# DB-Updates durchführen
update_databases() {
    if timeout 60 python3 "$WORKSPACE/scripts/update_docs_db.py" >/dev/null 2>&1; then
        info "docs.db aktualisiert"
        return 0
    else
        error "DB-Update fehlgeschlagen"
        return 1
    fi
}

# Tree-DB v2 aktualisieren
update_tree_db_v2() {
    if timeout 120 python3 "$WORKSPACE/scripts/tree_indexer_v2.py" >/dev/null 2>&1; then
        info "tree.db v2 aktualisiert"
        return 0
    else
        error "Tree-DB v2 fehlgeschlagen"
        return 1
    fi
}

# Backup erstellen
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

# Alte Backups aufräumen
cleanup_old_backups() {
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "$RETENTION_DAYS days ago" +%s)
    local deleted=0
    
    for db_name in docs.db tree.db; do
        find "$BACKUP_DIR" -name "*_${db_name}.bak" -type f | while read -r backup; do
            local filename
            filename=$(basename "$backup")
            local date_part
            date_part=$(echo "$filename" | cut -d'_' -f1)
            local time_part
            time_part=$(echo "$filename" | cut -d'_' -f2)
            
            if [[ -n "$date_part" ]] && [[ -n "$time_part" ]]; then
                local backup_datestr="${date_part}_${time_part%.*}"
                local backup_timestamp
                backup_timestamp=$(date -d "$backup_datestr" +%s 2>/dev/null) || {
                    warn "Konnte Backup-Datum nicht parsen: $filename"
                    continue
                }
                
                if [[ "$backup_timestamp" -lt "$cutoff_timestamp" ]]; then
                    rm -f "$backup"
                    deleted=$((deleted + 1))
                    info "Altes Backup gelöscht: $filename"
                fi
            fi
        done
    done
    
    if [[ "$deleted" -eq 0 ]]; then
        info "Keine alten Backups zum Löschen"
    else
        info "$deleted alte Backups gelöscht (< 3 Tage)"
    fi
}

# Hauptwartungszyklus
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
    if [[ "$tree_output" != "null" ]]; then
        update_tree_file "$tree_output"
        state=$(echo "$state" | jq --arg now "$(date --iso-8601=seconds)" '.last_tree_update = $now')
    fi
    
    # 2. tree.db aktualisieren (intern v2)
    info "Aktualisiere tree.db v2..."
    update_tree_db_v2
    
    # 3. Änderungen prüfen
    info "Prüfe auf Dokumentations-Änderungen..."
    local docs_temp
    docs_temp=$(scan_documentations)
    local changes_file
    changes_file=$(check_for_changes "$state" "$docs_temp")
    
    if [[ -s "$changes_file" ]]; then
        local change_count
        change_count=$(wc -l < "$changes_file" | tr -d ' ')
        info "$change_count Änderungen gefunden:"
        head -10 "$changes_file" | while read -r change; do
            info "  - $change"
        done
        if [[ "$change_count" -gt 10 ]]; then
            local remaining
            remaining=$((change_count - 10))
            info "  ... und $remaining weitere"
        fi
        
        # 4. docs.db aktualisieren
        info "Aktualisiere docs.db..."
        if update_databases; then
            state=$(echo "$state" | jq --arg now "$(date --iso-8601=seconds)" '.last_check = $now')
            
            # Aktualisiere file_hashes im Zustand
            local new_hashes
            new_hashes=$(mktemp)
            echo "{}" > "$new_hashes"
            while IFS= read -r doc_json; do
                local path
                path=$(jq -r '.path' <<<"$doc_json")
                local hash
                hash=$(jq -r '.hash' <<<"$doc_json")
                echo "$(jq --arg p "$path" --arg h "$hash" '.[$p] = $h' "$new_hashes")" > "$new_hashes"
            done < "$docs_temp"
            state=$(echo "$state" | jq --argjson hashes "$(cat "$new_hashes")" '.file_hashes = $hashes')
            rm -f "$new_hashes"
        fi
    else
        info "Keine Dokumentations-Änderungen gefunden"
    fi
    
    # 5. Prüfe ob Backup fällig (stündlich)
    local last_backup
    last_backup=$(echo "$state" | jq -r '.last_backup // "null"')
    local do_backup=false
    
    if [[ "$last_backup" == "null" ]]; then
        do_backup=true
    else
        local last_backup_seconds
        last_backup_seconds=$(date -d "$last_backup" +%s 2>/dev/null) || last_backup_seconds=0
        local now_seconds
        now_seconds=$(date +%s)
        local diff_seconds=$((now_seconds - last_backup_seconds))
        if [[ "$diff_seconds" -ge 3600 ]]; then
            do_backup=true
        fi
    fi
    
    if [[ "$do_backup" == true ]]; then
        info "Erstelle stündliches Backup..."
        local timestamp
        timestamp=$(create_backup)
        state=$(echo "$state" | jq --arg now "$(date --iso-8601=seconds)" '.last_backup = $now')
        
        # 6. Alte Backups aufräumen (3 Tage Retention)
        info "Räume alte Backups auf (3 Tage Retention)..."
        cleanup_old_backups
    else
        info "Backup nicht nötig (letztes < 1h)"
    fi
    
    save_state "$state"
    
    # Temporäre Dateien aufräumen
    rm -f "$docs_temp" "$changes_file"
    
    info "============================================================"
    info "DB MAINTAINER CYCLE END"
    info "============================================================"
}

# Hauptfunktion
main() {
    run_cycle
}

# Skript starten
main "$@"
