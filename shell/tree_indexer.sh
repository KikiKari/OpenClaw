#!/usr/bin/env bash
# tree_indexer.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:scripts/tree_indexer.py
# auch in: OpenClaw@gateway2:scripts/tree_indexer.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Tree Indexer - Scannt Verzeichnisbäume und speichert in tree.db

WORKSPACE="/home/openclaw/.openclaw/workspace"
DB_DIR="$WORKSPACE/db"
DB_PATH="$DB_DIR/tree.db"

# Initialisiert die Datenbank
init_db() {
    mkdir -p "$DB_DIR"
    sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS tree_scans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    root_path TEXT,
    max_depth INTEGER,
    total_files INTEGER,
    total_dirs INTEGER,
    total_symlinks INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tree_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    root_path TEXT,
    relative_path TEXT,
    name TEXT,
    type TEXT,
    depth INTEGER,
    parent_path TEXT,
    size INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF
}

# Führt tree -a -L {depth} aus und gibt Ausgabe zurück
run_tree() {
    local root_path="$1"
    local max_depth="$2"
    local output
    output=$(timeout 30 tree -a -L "$max_depth" "$root_path" 2>/dev/null) || {
        echo "❌ Fehler bei tree $root_path" >&2
        return 1
    }
    echo "$output"
}

# Parst tree-Ausgabe und gibt Einträge als Array zurück
parse_tree_output() {
    local tree_output="$1"
    local root_path="$2"
    local entries=()
    
    # Regex für tree-Zeilen
    # Beispiel: "├── .bash_history" oder "│   ├── bin"
    while IFS= read -r line; do
        if [[ $line =~ ^[│\ ]*[├└]──\ (.+)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            # Tiefe bestimmen durch Anzahl der │ und Leerzeichen
            local depth=0
            local temp_line="$line"
            while [[ $temp_line =~ ^[│\ ] ]]; do
                temp_line="${temp_line#?}"
                ((depth++))
            done
            
            # Typ bestimmen
            local entry_type="file"
            if [[ $name == */ ]]; then
                entry_type="directory"
                name="${name%/}"
            elif [[ $name == *" -> "* ]]; then
                entry_type="symlink"
                name="${name%% -> *}"
            fi
            
            entries+=("$name|$entry_type|$depth|$line")
        fi
    done <<< "$tree_output"
    
    printf '%s\n' "${entries[@]}"
}

# Speichert Einträge in tree.db
save_to_db() {
    local root_path="$1"
    local max_depth="$2"
    local entries="$3"
    
    local total_files=0
    local total_dirs=0
    local total_symlinks=0
    
    while IFS='|' read -r name entry_type _ _; do
        case "$entry_type" in
            file) ((total_files++)) ;;
            directory) ((total_dirs++)) ;;
            symlink) ((total_symlinks++)) ;;
        esac
    done <<< "$entries"
    
    local scan_id
    scan_id=$(sqlite3 "$DB_PATH" \
        "INSERT INTO tree_scans (root_path, max_depth, total_files, total_dirs, total_symlinks) VALUES ('$root_path', $max_depth, $total_files, $total_dirs, $total_symlinks); SELECT last_insert_rowid();")
    
    while IFS='|' read -r name entry_type depth _; do
        sqlite3 "$DB_PATH" \
            "INSERT INTO tree_entries (root_path, relative_path, name, type, depth, parent_path, size) VALUES ('$root_path', '$name', '$name', '$entry_type', $depth, '$root_path', 0)"
    done <<< "$entries"
    
    local count
    count=$(wc -l <<< "$entries")
    echo "✅ $count Einträge gespeichert für $root_path"
}

# Komplette Indexierung eines Verzeichnisses
index_directory() {
    local root_path="$1"
    local max_depth="$2"
    
    echo
    echo "--- Indexiere: $root_path (Depth: $max_depth) ---"
    
    local tree_output
    tree_output=$(run_tree "$root_path" "$max_depth") || return 1
    
    local entries
    entries=$(parse_tree_output "$tree_output" "$root_path")
    
    if [[ -n "$entries" ]]; then
        save_to_db "$root_path" "$max_depth" "$entries"
    fi
}

# Exportiert alle Tree-Einträge als CSV
export_csv() {
    local csv_path="$WORKSPACE/export_tree_all.csv"
    
    if ! sqlite3 "$DB_PATH" "SELECT * FROM tree_entries LIMIT 1;" >/dev/null 2>&1; then
        echo "⚠️ Keine Tree-Daten vorhanden"
        return 1
    fi
    
    sqlite3 -header -csv "$DB_PATH" "SELECT * FROM tree_entries ORDER BY root_path, depth, name;" > "$csv_path"
    
    local count
    count=$(tail -n +2 "$csv_path" | wc -l)
    echo "✅ Tree CSV exportiert: $csv_path ($count Einträge)"
}

# Exportiert getrennt nach root_path
export_by_root() {
    local roots
    roots=$(sqlite3 -noheader "$DB_PATH" "SELECT DISTINCT root_path FROM tree_entries;")
    
    while IFS= read -r root_path; do
        local safe_name
        safe_name=$(echo "$root_path" | tr '/.' '_')
        local csv_path="$WORKSPACE/export_tree$safe_name.csv"
        
        sqlite3 -header -csv "$DB_PATH" "SELECT * FROM tree_entries WHERE root_path = '$root_path' ORDER BY depth, name;" > "$csv_path"
        
        local count
        count=$(tail -n +2 "$csv_path" | wc -l)
        echo "✅ Export $root_path: $csv_path ($count Einträge)"
    done <<< "$roots"
}

main() {
    echo "============================================================"
    echo "TREE INDEXER"
    echo "============================================================"
    
    init_db
    
    # 1. /home/openclaw/ mit depth 3
    index_directory "/home/openclaw/" 3 || true
    
    # 2. Workspace mit depth 6
    index_directory "/home/openclaw/.openclaw/workspace/" 6 || true
    
    # Exporte erstellen
    echo
    echo "--- Exporte ---"
    export_csv || true
    export_by_root || true
    
    echo
    echo "============================================================"
    echo "TREE INDEXIERUNG ABGESCHLOSSEN"
    echo "============================================================"
}

main "$@"
