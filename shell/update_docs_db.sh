#!/usr/bin/env bash
# update_docs_db.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/update_docs_db.py
# Erzeugt: 2026-08-24 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Scan documentation files and refresh docs.db for the mounted workspace.

WORKSPACE="${OPENCLAW_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DB_PATH="$WORKSPACE/docs.db"

# Function to find all .md files recursively, excluding certain directories
iter_docs() {
    find "$WORKSPACE" -type f -name "*.md" ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/backups/*" 2>/dev/null || true
}

# Function to compute MD5 hash of a file
file_hash() {
    local path="$1"
    if command -v md5sum >/dev/null 2>&1; then
        md5sum < "$path" | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$path"
    else
        echo "No MD5 utility found" >&2
        exit 1
    fi
}

# Function to count words in a file
word_count() {
    local path="$1"
    if [[ -r "$path" ]]; then
        wc -w < "$path" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Function to build rows of data for insertion into database
build_rows() {
    local indexed
    indexed=$(date +%s.%N)
    while IFS= read -r md_file; do
        local rel_path
        rel_path="${md_file#$WORKSPACE/}"
        local hash
        hash=$(file_hash "$md_file")
        local wc
        wc=$(word_count "$md_file")
        printf '%s|%s|%s|%s\n' "$rel_path" "$hash" "$indexed" "$wc"
    done < <(iter_docs)
}

# Function to ensure schema exists in SQLite database
ensure_schema() {
    sqlite3 "$DB_PATH" <<EOF
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

# Function to update the database with new document data
update_database() {
    local temp_data="$1"
    ensure_schema
    sqlite3 "$DB_PATH" <<EOF
DELETE FROM documents;
.separator |
.import $temp_data documents
EOF
}

# Function to export table data to JSON and CSV formats
export_table() {
    local table="$1"
    local json_path="$WORKSPACE/db_${table}.json"
    local csv_path="$WORKSPACE/db_${table}.csv"
    
    # Export to CSV
    sqlite3 -header -csv "$DB_PATH" "SELECT * FROM $table;" > "$csv_path"
    
    # Export to JSON using jq if available
    if command -v jq >/dev/null 2>&1; then
        sqlite3 -separator ',' "$DB_PATH" "SELECT * FROM $table;" | \
        jq -R -s 'split("\n")[:-1] | map(split(",")) | .[0] as $header | .[1:] | map( [$header, .] | transpose | map({key:.[0], value:.[1]}) | from_entries )' > "$json_path"
    else
        # Fallback without jq: create simple array format
        sqlite3 -separator ',' "$DB_PATH" "SELECT * FROM $table;" | \
        awk 'BEGIN {FS=","; OFS="\",\""; print "["} NR==1 {for(i=1;i<=NF;i++) header[i]=$i } NR>1 { printf "  {"; for(i=1;i<=NF;i++) printf "\"%s\":\"%s\"" (i<NF ? "," : ""), header[i], $i; print "}" } END {print "]"}' > "$json_path"
    fi
}

# Main function
main() {
    echo "============================================================"
    echo "DOCS.DB UPDATER"
    echo "============================================================"
    
    local temp_data
    temp_data=$(mktemp)
    
    # Build rows and write to temporary file
    build_rows > "$temp_data"
    local doc_count
    doc_count=$(wc -l < "$temp_data" | tr -d ' ')
    
    echo "Gefunden: $doc_count Dokumente"
    
    # Update database
    update_database "$temp_data"
    echo "✅ $doc_count Dokumente in docs.db aktualisiert"
    
    # Export tables
    export_table "documents"
    export_table "tags"
    echo "✅ Exporte aktualisiert"
    
    # Cleanup
    rm -f "$temp_data"
    
    echo ""
    echo "============================================================"
    echo "DOCS.DB AKTUALISIERT"
    echo "============================================================"
}

main "$@"
