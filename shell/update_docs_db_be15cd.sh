#!/usr/bin/env bash
# update_docs_db.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Scan documentation files and refresh docs.db for the mounted workspace.

WORKSPACE="/workspace"
DB_PATH="$WORKSPACE/db/docs.db"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Create db directory if it doesn't exist
mkdir -p "$WORKSPACE/db"

iter_docs() {
    find "$WORKSPACE" -type f -name "*.md" ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/backups/*"
}

file_hash() {
    local path="$1"
    md5sum < "$path" | cut -d' ' -f1
}

word_count() {
    local path="$1"
    if [[ -r "$path" ]]; then
        wc -w < "$path" 2>/dev/null | tr -d ' ' || echo 0
    else
        echo 0
    fi
}

build_rows() {
    local indexed=$(date +%s.%N)
    local temp_csv="$TEMP_DIR/rows.csv"
    
    {
        echo "path,content_hash,last_indexed,word_count"
        while IFS= read -r md_file; do
            local rel_path="${md_file#$WORKSPACE/}"
            local hash=$(file_hash "$md_file")
            local words=$(word_count "$md_file")
            echo "\"$rel_path\",$hash,$indexed,$words"
        done < <(iter_docs)
    } > "$temp_csv"
    
    echo "$temp_csv"
}

ensure_schema() {
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS documents (
    path TEXT PRIMARY KEY,
    content_hash TEXT,
    last_indexed REAL,
    word_count INTEGER
);
CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT,
    tag TEXT
);
EOF
}

update_database() {
    local csv_file="$1"
    ensure_schema
    
    sqlite3 "$DB_PATH" << EOF
DELETE FROM documents;
.mode csv
.import "$csv_file" documents
EOF
}

export_table() {
    local table="$1"
    local json_path="$WORKSPACE/db_${table}.json"
    local csv_path="$WORKSPACE/db_${table}.csv"
    
    # Export to CSV
    sqlite3 -header -csv "$DB_PATH" "SELECT * FROM $table;" > "$csv_path"
    
    # Export to JSON
    if [[ -s "$csv_path" ]]; then
        # Convert CSV to JSON using jq if available, otherwise create minimal JSON
        if command -v jq >/dev/null 2>&1; then
            jq -R . "$csv_path" | jq -s -c 'split("\n")[:-1] | map(split(",") | .[0] |= sub("^\"(.*)\"$"; "\1")) | 
                 .[0] as $headers | .[1:] | map( [$headers, .] | transpose | map({key:.[0], value: .[1]}) | from_entries )' > "$json_path"
        else
            # Fallback: create a simple JSON structure
            echo "[" > "$json_path"
            local first=true
            while IFS= read -r line; do
                if [[ "$first" == true ]]; then
                    first=false
                    continue
                fi
                echo "  {\"data\": \"$line\"}," >> "$json_path"
            done < "$csv_path"
            sed -i '$ s/,$//' "$json_path"
            echo "]" >> "$json_path"
        fi
    else
        echo "[]" > "$json_path"
    fi
}

main() {
    echo "============================================================"
    echo "DOCS.DB UPDATER"
    echo "============================================================"
    
    local csv_file=$(build_rows)
    local doc_count=$(($(wc -l < "$csv_file") - 1))  # Subtract header line
    
    echo "Gefunden: $doc_count Dokumente"
    
    update_database "$csv_file"
    
    echo "✅ $doc_count Dokumente in docs.db aktualisiert"
    
    export_table "documents"
    export_table "tags"
    
    echo "✅ Exporte aktualisiert"
    echo ""
    echo "============================================================"
    echo "DOCS.DB AKTUALISIERT"
    echo "============================================================"
}

main "$@"
