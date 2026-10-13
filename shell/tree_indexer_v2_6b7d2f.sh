#!/usr/bin/env bash
# tree_indexer_v2.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/tree_indexer_v2.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Tree Indexer v2 - Erweitertes Tracking mit Metadaten

WORKSPACE="/workspace"
DB_DIR="$WORKSPACE/db"
DB_FILE="$DB_DIR/tree.db"

# Erstellt erweiterte Tabellenstruktur
init_schema_v2() {
    mkdir -p "$DB_DIR"
    
    sqlite3 "$DB_FILE" << 'EOF'
CREATE TABLE IF NOT EXISTS tree_entries_v2 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id TEXT UNIQUE,
    root_path TEXT NOT NULL,
    relative_path TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
    depth INTEGER,
    parent_path TEXT,
    size_bytes INTEGER,
    previous_size_bytes INTEGER,
    size_change_bytes INTEGER,
    mtime_timestamp REAL,
    mtime_iso TEXT,
    first_seen_timestamp REAL,
    last_seen_timestamp REAL,
    change_type TEXT CHECK(change_type IN ('NEW', 'MODIFIED', 'MOVED', 'RENAMED', 'UNCHANGED', 'DELETED')),
    original_name TEXT,
    original_path TEXT,
    previous_path TEXT,
    content_hash TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS file_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id TEXT NOT NULL,
    timestamp REAL NOT NULL,
    change_type TEXT NOT NULL,
    old_path TEXT,
    new_path TEXT,
    old_size INTEGER,
    new_size INTEGER,
    FOREIGN KEY (file_id) REFERENCES tree_entries_v2(file_id)
);

CREATE INDEX IF NOT EXISTS idx_file_id ON tree_entries_v2(file_id);
CREATE INDEX IF NOT EXISTS idx_path ON tree_entries_v2(relative_path);
CREATE INDEX IF NOT EXISTS idx_mtime ON tree_entries_v2(mtime_timestamp);
CREATE INDEX IF NOT EXISTS idx_change_type ON tree_entries_v2(change_type);
EOF
    
    echo "✅ tree.db Schema v2 erstellt/aktualisiert"
}

# Generiert eindeutige ID aus Pfad
generate_file_id() {
    local relative_path="$1"
    printf "%s" "$relative_path" | md5sum | cut -d' ' -f1 | head -c16
}

# Extrahiert Metadaten einer Datei
get_file_metadata() {
    local full_path="$1"
    if [[ -e "$full_path" ]]; then
        local size
        size=$(stat -c%s "$full_path" 2>/dev/null || echo "0")
        local mtime
        mtime=$(stat -c%Y "$full_path" 2>/dev/null || echo "0")
        local mtime_iso
        mtime_iso=$(date -d "@$mtime" -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "")
        echo "$size|$mtime|$mtime_iso"
    else
        echo "0|0|"
    fi
}

# Detailliertes Scanning mit Metadaten
scan_directory_detailed() {
    local root_path="$1"
    local max_depth="${2:-8}"
    local entries=()
    
    while IFS= read -r -d '' file; do
        local rel_path
        rel_path=${file#$root_path/}
        local depth
        depth=$(echo "$rel_path" | tr '/' '\n' | wc -l)
        
        if [[ $depth -le $max_depth ]]; then
            local file_id
            file_id=$(generate_file_id "$rel_path")
            local metadata
            metadata=$(get_file_metadata "$file")
            IFS='|' read -r size mtime mtime_iso <<< "$metadata"
            local name
            name=$(basename "$file")
            local ftype="file"
            [[ -d "$file" ]] && ftype="directory"
            [[ -L "$file" ]] && ftype="symlink"
            local parent_path
            parent_path=$(dirname "$rel_path")
            [[ "$parent_path" == "." ]] && parent_path=""
            
            entries+=("$file_id|$root_path|$rel_path|$name|$ftype|$depth|$parent_path|$size|$mtime|$mtime_iso")
        fi
    done < <(find "$root_path" -mindepth 1 -print0 2>/dev/null)
    
    printf '%s\n' "${entries[@]}"
}

# Aktualisiert DB mit Änderungs-Erkennung
update_database() {
    local temp_file="$DB_DIR/temp_scan.txt"
    scan_directory_detailed "$WORKSPACE" 8 > "$temp_file"
    
    local now_timestamp
    now_timestamp=$(date +%s)
    
    # Alle bestehenden Einträge als "potentiell gelöscht" markieren
    sqlite3 "$DB_FILE" "UPDATE tree_entries_v2 SET change_type = NULL"
    
    local new_count=0
    local modified_count=0
    local unchanged_count=0
    local moved_count=0
    
    while IFS='|' read -r file_id root_path relative_path name ftype depth parent_path size_bytes mtime_timestamp mtime_iso; do
        # Prüfe ob Datei bereits bekannt
        local existing
        existing=$(sqlite3 "$DB_FILE" "SELECT mtime_timestamp,size_bytes,relative_path FROM tree_entries_v2 WHERE file_id='$file_id' LIMIT 1" 2>/dev/null || echo "")
        
        if [[ -n "$existing" ]]; then
            IFS='|' read -r old_mtime old_size old_path <<< "$existing"
            local size_change=$((size_bytes - old_size))
            
            local change_type="UNCHANGED"
            if [[ "$old_path" != "$relative_path" ]]; then
                change_type="MOVED"
                ((moved_count++))
            elif [[ "$old_mtime" != "$mtime_timestamp" ]] || [[ "$old_size" != "$size_bytes" ]]; then
                change_type="MODIFIED"
                ((modified_count++))
            else
                ((unchanged_count++))
            fi
            
            # Update
            sqlite3 "$DB_FILE" << EOF
UPDATE tree_entries_v2 SET
    size_bytes = $size_bytes,
    previous_size_bytes = $old_size,
    size_change_bytes = $size_change,
    mtime_timestamp = $mtime_timestamp,
    mtime_iso = '$mtime_iso',
    last_seen_timestamp = $now_timestamp,
    change_type = '$change_type',
    previous_path = '$old_path',
    original_path = COALESCE(original_path, '$old_path'),
    updated_at = CURRENT_TIMESTAMP
WHERE file_id = '$file_id';
EOF
            
            # Änderung in Historie loggen
            if [[ "$change_type" == "MODIFIED" ]] || [[ "$change_type" == "MOVED" ]]; then
                sqlite3 "$DB_FILE" << EOF
INSERT INTO file_history
(file_id, timestamp, change_type, old_path, new_path, old_size, new_size)
VALUES ('$file_id', $now_timestamp, '$change_type', '$old_path', '$relative_path', $old_size, $size_bytes);
EOF
            fi
        else
            # Neue Datei
            ((new_count++))
            sqlite3 "$DB_FILE" << EOF
INSERT INTO tree_entries_v2
(file_id, root_path, relative_path, name, type, depth, parent_path,
 size_bytes, previous_size_bytes, size_change_bytes,
 mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
 change_type, content_hash)
VALUES ('$file_id', '$root_path', '$relative_path', '$name', '$ftype', $depth, '$parent_path',
 $size_bytes, $size_bytes, 0,
 $mtime_timestamp, '$mtime_iso', $now_timestamp, $now_timestamp,
 'NEW', NULL);
EOF
        fi
    done < "$temp_file"
    
    # Markiere nicht aktualisierte Einträge als DELETED
    local deleted_ids
    deleted_ids=$(sqlite3 "$DB_FILE" "SELECT file_id FROM tree_entries_v2 WHERE change_type IS NULL OR last_seen_timestamp < ($now_timestamp - 3600)" 2>/dev/null || echo "")
    local deleted_count=0
    if [[ -n "$deleted_ids" ]]; then
        while IFS= read -r file_id; do
            if [[ -n "$file_id" ]]; then
                sqlite3 "$DB_FILE" "UPDATE tree_entries_v2 SET change_type = 'DELETED', updated_at = CURRENT_TIMESTAMP WHERE file_id = '$file_id'"
                ((deleted_count++))
            fi
        done <<< "$deleted_ids"
    fi
    
    rm -f "$temp_file"
    
    echo "new:$new_count"
    echo "modified:$modified_count"
    echo "moved:$moved_count"
    echo "unchanged:$unchanged_count"
    echo "deleted:$deleted_count"
}

# Exportiert Änderungen der letzten X Stunden
export_changes() {
    local since_hours="${1:-24}"
    local since
    since=$(( $(date +%s) - (since_hours * 3600) ))
    
    local export_file="$WORKSPACE/tree_changes_last_${since_hours}h.json"
    
    # Export als JSON
    sqlite3 "$DB_FILE" << EOF
.headers on
.mode json
.output $export_file
SELECT * FROM tree_entries_v2 
WHERE change_type IN ('NEW', 'MODIFIED', 'MOVED', 'DELETED')
AND last_seen_timestamp > $since
ORDER BY last_seen_timestamp DESC;
EOF
    
    local count
    count=$(jq length "$export_file" 2>/dev/null || echo "0")
    echo "✅ Änderungen exportiert: $export_file ($count Einträge)"
}

main() {
    echo "============================================================"
    echo "TREE INDEXER v2 - Erweitertes Tracking"
    echo "============================================================"
    
    init_schema_v2
    
    echo ""
    echo "--- Scanning Workspace ---"
    local entry_count
    entry_count=$(find "$WORKSPACE" -mindepth 1 2>/dev/null | wc -l)
    echo "Gefunden: $entry_count Einträge"
    
    echo ""
    echo "--- Aktualisiere Datenbank ---"
    local stats_output
    stats_output=$(update_database)
    
    local new_count=0
    local modified_count=0
    local moved_count=0
    local unchanged_count=0
    local deleted_count=0
    
    while IFS=':' read -r key value; do
        case "$key" in
            new) new_count=$value ;;
            modified) modified_count=$value ;;
            moved) moved_count=$value ;;
            unchanged) unchanged_count=$value ;;
            deleted) deleted_count=$value ;;
        esac
    done <<< "$stats_output"
    
    echo "Statistiken:"
    echo "  NEU:        $new_count"
    echo "  MODIFIED:   $modified_count"
    echo "  MOVED:      $moved_count"
    echo "  UNCHANGED:  $unchanged_count"
    echo "  DELETED:    $deleted_count"
    
    echo ""
    echo "--- Exportiere Änderungen (24h) ---"
    export_changes 24
    
    echo ""
    echo "============================================================"
    echo "TREE INDEXING ABGESCHLOSSEN"
    echo "============================================================"
}

main "$@"
