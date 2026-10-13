#!/usr/bin/env bash
# tree_indexer_v2.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:scripts/tree_indexer_v2.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Tree Indexer v2 - Erweitertes Tracking mit Metadaten

readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_DIR="$WORKSPACE/db"
readonly DB_PATH="$DB_DIR/tree.db"

# Funktion zur Initialisierung des Schemas
init_schema_v2() {
    mkdir -p "$DB_DIR"

    sqlite3 "$DB_PATH" <<'EOF'
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

# Funktion zum Generieren einer eindeutigen Datei-ID
generate_file_id() {
    local relative_path="$1"
    printf "%s" "$relative_path" | md5sum | cut -d' ' -f1 | head -c16
}

# Funktion zum Extrahieren von Metadaten einer Datei
get_file_metadata() {
    local full_path="$1"
    if [[ -e "$full_path" ]]; then
        local size mtime mtime_iso
        size=$(stat -c%s "$full_path" 2>/dev/null || echo 0)
        mtime=$(stat -c%Y "$full_path" 2>/dev/null || echo 0)
        mtime_iso=$(date -d "@$mtime" -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "")
        echo "$size|$mtime|$mtime_iso"
    else
        echo "0|0|"
    fi
}

# Funktion zum detaillierten Scannen eines Verzeichnisses
scan_directory_detailed() {
    local root_path="$1"
    local max_depth="${2:-8}"
    local temp_entries="/tmp/tree_entries_$$.txt"
    : > "$temp_entries"

    find "$root_path" -type f,d,l -print0 2>/dev/null | while IFS= read -r -d '' item; do
        local relative_path
        relative_path=$(realpath --relative-to="$root_path" "$item" 2>/dev/null || echo "")
        
        # Tiefe prüfen
        local depth
        depth=$(echo "$relative_path" | tr '/' '\n' | wc -l)
        if (( depth > max_depth )); then
            continue
        fi

        local file_id name type parent_path metadata size mtime mtime_iso
        file_id=$(generate_file_id "$relative_path")
        name=$(basename "$item")
        if [[ -d "$item" ]]; then
            type="directory"
        elif [[ -L "$item" ]]; then
            type="symlink"
        else
            type="file"
        fi
        parent_path=$(dirname "$relative_path")
        parent_path=${parent_path#.}
        parent_path=${parent_path#/}

        metadata=$(get_file_metadata "$item")
        IFS='|' read -r size mtime mtime_iso <<< "$metadata"

        echo "$file_id|$root_path|$relative_path|$name|$type|$depth|$parent_path|$size|$mtime|$mtime_iso" >> "$temp_entries"
    done

    cat "$temp_entries"
    rm -f "$temp_entries"
}

# Funktion zum Aktualisieren der Datenbank
update_database() {
    local temp_entries="/tmp/current_entries_$$.txt"
    cat > "$temp_entries"

    local now_timestamp
    now_timestamp=$(date +%s)

    # Alle bestehenden Einträge als "potentiell gelöscht" markieren
    sqlite3 "$DB_PATH" "UPDATE tree_entries_v2 SET change_type = NULL;"

    local new_count=0 modified_count=0 unchanged_count=0 moved_count=0

    while IFS='|' read -r file_id root_path relative_path name type depth parent_path size_bytes mtime_timestamp mtime_iso; do
        # Prüfe ob Datei bereits bekannt
        local existing_data
        existing_data=$(sqlite3 "$DB_PATH" "SELECT mtime_timestamp,size_bytes,relative_path FROM tree_entries_v2 WHERE file_id='$file_id';")

        if [[ -n "$existing_data" ]]; then
            IFS='|' read -r old_mtime old_size old_path <<< "$existing_data"
            old_mtime=${old_mtime:-0}
            old_size=${old_size:-0}
            old_path=${old_path:-""}

            local size_change change_type
            size_change=$((size_bytes - old_size))

            if [[ "$old_path" != "$relative_path" ]]; then
                change_type="MOVED"
                moved_count=$((moved_count + 1))
            elif [[ "$old_mtime" != "$mtime_timestamp" ]] || [[ "$old_size" != "$size_bytes" ]]; then
                change_type="MODIFIED"
                modified_count=$((modified_count + 1))
            else
                change_type="UNCHANGED"
                unchanged_count=$((unchanged_count + 1))
            fi

            # Update
            sqlite3 "$DB_PATH" <<EOF
UPDATE tree_entries_v2 SET
    size_bytes = $size_bytes,
    previous_size_bytes = $old_size,
    size_change_bytes = $size_change,
    mtime_timestamp = $mtime_timestamp,
    mtime_iso = '$mtime_iso',
    last_seen_timestamp = $now_timestamp,
    change_type = '$change_type',
    previous_path = CASE WHEN '$change_type' = 'MOVED' THEN '$old_path' ELSE NULL END,
    original_path = COALESCE(original_path, '$old_path'),
    updated_at = CURRENT_TIMESTAMP
WHERE file_id = '$file_id';
EOF

            # Änderung in Historie loggen
            if [[ "$change_type" == "MODIFIED" ]] || [[ "$change_type" == "MOVED" ]]; then
                sqlite3 "$DB_PATH" <<EOF
INSERT INTO file_history
(file_id, timestamp, change_type, old_path, new_path, old_size, new_size)
VALUES ('$file_id', $now_timestamp, '$change_type', '$old_path', '$relative_path', $old_size, $size_bytes);
EOF
            fi
        else
            # Neue Datei
            new_count=$((new_count + 1))
            sqlite3 "$DB_PATH" <<EOF
INSERT INTO tree_entries_v2
(file_id, root_path, relative_path, name, type, depth, parent_path,
 size_bytes, previous_size_bytes, size_change_bytes,
 mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
 change_type, content_hash)
VALUES ('$file_id', '$root_path', '$relative_path', '$name', '$type', $depth, '$parent_path',
        $size_bytes, $size_bytes, 0,
        $mtime_timestamp, '$mtime_iso', $now_timestamp, $now_timestamp,
        'NEW', NULL);
EOF
        fi
    done < "$temp_entries"

    # Markiere nicht aktualisierte Einträge als DELETED
    local deleted_count
    deleted_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tree_entries_v2 WHERE change_type IS NULL OR last_seen_timestamp < ($now_timestamp - 3600);" | head -n1)
    sqlite3 "$DB_PATH" "UPDATE tree_entries_v2 SET change_type = 'DELETED', updated_at = CURRENT_TIMESTAMP WHERE change_type IS NULL OR last_seen_timestamp < ($now_timestamp - 3600);"

    rm -f "$temp_entries"

    echo "new:$new_count"
    echo "modified:$modified_count"
    echo "moved:$moved_count"
    echo "unchanged:$unchanged_count"
    echo "deleted:$deleted_count"
}

# Funktion zum Exportieren von Änderungen
export_changes() {
    local since_hours="${1:-24}"
    local since
    since=$(( $(date +%s) - (since_hours * 3600) ))

    local export_file="$WORKSPACE/tree_changes_last_${since_hours}h.json"

    sqlite3 "$DB_PATH" <<EOF
.headers on
.mode json
.output $export_file
SELECT * FROM tree_entries_v2 
WHERE change_type IN ('NEW', 'MODIFIED', 'MOVED', 'DELETED')
AND last_seen_timestamp > $since
ORDER BY last_seen_timestamp DESC;
EOF

    local count
    count=$(jq length "$export_file" 2>/dev/null || echo 0)
    echo "✅ Änderungen exportiert: $export_file ($count Einträge)"
}

# Hauptfunktion
main() {
    echo "============================================================"
    echo "TREE INDEXER v2 - Erweitertes Tracking"
    echo "============================================================"

    init_schema_v2

    echo ""
    echo "--- Scanning Workspace ---"
    local entries_file="/tmp/all_entries_$$.txt"
    scan_directory_detailed "/home/openclaw/.openclaw/workspace/" 8 > "$entries_file"
    local entry_count
    entry_count=$(wc -l < "$entries_file")
    echo "Gefunden: $entry_count Einträge"

    echo ""
    echo "--- Aktualisiere Datenbank ---"
    local stats_output
    stats_output=$(update_database < "$entries_file")
    
    local new modified moved unchanged deleted
    new=$(echo "$stats_output" | grep "^new:" | cut -d: -f2)
    modified=$(echo "$stats_output" | grep "^modified:" | cut -d: -f2)
    moved=$(echo "$stats_output" | grep "^moved:" | cut -d: -f2)
    unchanged=$(echo "$stats_output" | grep "^unchanged:" | cut -d: -f2)
    deleted=$(echo "$stats_output" | grep "^deleted:" | cut -d: -f2)

    echo "Statistiken:"
    echo "  NEU:        ${new:-0}"
    echo "  MODIFIED:   ${modified:-0}"
    echo "  MOVED:      ${moved:-0}"
    echo "  UNCHANGED:  ${unchanged:-0}"
    echo "  DELETED:    ${deleted:-0}"

    rm -f "$entries_file"

    echo ""
    echo "--- Exportiere Änderungen (24h) ---"
    export_changes 24

    echo ""
    echo "============================================================"
    echo "TREE INDEXING ABGESCHLOSSEN"
    echo "============================================================"
}

# Skript ausführen
main "$@"
