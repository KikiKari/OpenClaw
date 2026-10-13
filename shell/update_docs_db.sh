#!/usr/bin/env bash
# update_docs_db.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Scannt alle vorhandenen Dokumentationen und aktualisiert docs.db

readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly DB_PATH="${WORKSPACE}/db/docs.db"

# Funktion zum Extrahieren der ersten Zeile als Beschreibung
get_description() {
    local md_file="$1"
    local first_line
    first_line=$(head -n 1 "$md_file" 2>/dev/null || echo "Dokumentation")
    if [[ $first_line == \#* ]]; then
        first_line=${first_line#\#}
        first_line=$(echo "$first_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    if [ ${#first_line} -gt 50 ]; then
        first_line="${first_line:0:50}..."
    fi
    echo "$first_line"
}

# Funktion zum Abrufen des letzten Änderungsdatums
get_mtime() {
    local md_file="$1"
    if stat --version &>/dev/null; then
        stat -c %Y "$md_file" 2>/dev/null | xargs -I {} date -d @{} +%Y-%m-%d 2>/dev/null || echo "2026-04-18"
    else
        stat -f %m "$md_file" 2>/dev/null | xargs -I {} date -r {} +%Y-%m-%d 2>/dev/null || echo "2026-04-18"
    fi
}

# Funktion zum Aktualisieren der Datenbank
update_database() {
    local temp_sql=$(mktemp)
    local inserted=0

    # Lösche alte Einträge (außer config)
    echo "DELETE FROM documents WHERE category != 'config';" > "$temp_sql"

    # Füge neue ein
    while IFS=$'\t' read -r name path category description type has_symlink symlink_path last_update; do
        printf "INSERT INTO documents (name, path, category, description, type, has_symlink, symlink_path, last_update) VALUES ('%s','%s','%s','%s','%s',%s,%s,'%s');\n" \
            "$(echo "$name" | sed "s/'/''/g")" \
            "$(echo "$path" | sed "s/'/''/g")" \
            "$(echo "$category" | sed "s/'/''/g")" \
            "$(echo "$description" | sed "s/'/''/g")" \
            "$(echo "$type" | sed "s/'/''/g")" \
            "$has_symlink" \
            "$symlink_path" \
            "$(echo "$last_update" | sed "s/'/''/g")" >> "$temp_sql"
        ((inserted++))
    done < <(cat "${WORKSPACE}/docs_temp.tsv")

    sqlite3 "$DB_PATH" < "$temp_sql"
    rm -f "$temp_sql"
    echo "$inserted"
}

# Funktion zum Erstellen aller Exporte
export_all() {
    local tables=("documents" "skills" "symlinks")
    for table in "${tables[@]}"; do
        local json_path="${WORKSPACE}/db_${table}.json"
        local csv_path="${WORKSPACE}/db_${table}.csv"
        
        # JSON Export
        sqlite3 -json "$DB_PATH" "SELECT * FROM $table;" > "$json_path"
        echo "✅ $json_path"
        
        # CSV Export
        sqlite3 -header -csv "$DB_PATH" "SELECT * FROM $table;" > "$csv_path"
        echo "✅ $csv_path"
    done
}

# Hauptfunktion
main() {
    echo "============================================================"
    echo "DOCS.DB UPDATER"
    echo "============================================================"

    # Temporäre TSV-Datei für die Dokumente erstellen
    local docs_temp="${WORKSPACE}/docs_temp.tsv"
    > "$docs_temp"

    echo
    echo "--- Scanne Dokumentationen ---"

    # Hauptverzeichnis
    while IFS= read -r -d '' file; do
        if [[ -f "$file" && ! -L "$file" ]]; then
            local name=$(basename "$file")
            local description=$(get_description "$file")
            local last_update=$(get_mtime "$file")
            printf "%s\t/\tmain\t%s\tdoc\t0\tNULL\t%s\n" "$name" "$description" "$last_update" >> "$docs_temp"
        fi
    done < <(find "$WORKSPACE" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)

    # WebSearch Verzeichnis
    if [[ -d "${WORKSPACE}/websearch" ]]; then
        while IFS= read -r -d '' file; do
            local name=$(basename "$file")
            local description=$(get_description "$file")
            local last_update=$(get_mtime "$file")
            local type="config"
            if [[ $name == *"GUIDE"* ]]; then
                type="guide"
            fi
            printf "%s\twebsearch/\twebsearch\t%s\t%s\t1\twebsearch/%s\t%s\n" "$name" "$description" "$type" "$name" "$last_update" >> "$docs_temp"
        done < <(find "${WORKSPACE}/websearch" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)
    fi

    # MCP Verzeichnis
    if [[ -d "${WORKSPACE}/mcp" ]]; then
        while IFS= read -r -d '' file; do
            local name=$(basename "$file")
            local description=$(get_description "$file")
            local last_update=$(get_mtime "$file")
            local is_symlink=0
            local symlink_path="NULL"
            local type="guide"
            
            if [[ -L "$file" ]]; then
                is_symlink=1
                symlink_path=$(readlink "$file" 2>/dev/null || echo "NULL")
                type="symlink"
            fi
            
            printf "%s\tmcp/\tmcp\t%s\t%s\t%d\t%s\t%s\n" "$name" "$description" "$type" "$is_symlink" "$symlink_path" "$last_update" >> "$docs_temp"
        done < <(find "${WORKSPACE}/mcp" -maxdepth 1 -name "*.md" -type f -o -type l -print0 2>/dev/null || true)
    fi

    # Docs-Unterverzeichnisse
    if [[ -d "${WORKSPACE}/docs" ]]; then
        while IFS= read -r -d '' dir; do
            local subdir_name=$(basename "$dir")
            while IFS= read -r -d '' file; do
                local name=$(basename "$file")
                local description=$(get_description "$file")
                local last_update=$(get_mtime "$file")
                printf "%s\tdocs/%s/\t%s\t%s\tdoc\t0\tNULL\t%s\n" "$name" "$subdir_name" "$subdir_name" "$description" "$last_update" >> "$docs_temp"
            done < <(find "$dir" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)
        done < <(find "${WORKSPACE}/docs" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi

    # Cluster, Memory, Reports, Skills
    local categories=("cluster" "memory" "reports" "skills")
    for category in "${categories[@]}"; do
        if [[ -d "${WORKSPACE}/${category}" ]]; then
            while IFS= read -r -d '' file; do
                local name=$(basename "$file")
                local description=$(get_description "$file")
                local last_update=$(get_mtime "$file")
                printf "%s\t%s/\t%s\t%s\tdoc\t0\tNULL\t%s\n" "$name" "$category" "$category" "$description" "$last_update" >> "$docs_temp"
            done < <(find "${WORKSPACE}/${category}" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)
        fi
    done

    local count=$(wc -l < "$docs_temp" | tr -d ' ')
    echo "Gefunden: $count Dokumente"

    echo
    echo "--- Aktualisiere docs.db ---"
    local inserted=$(update_database)
    echo "✅ $inserted Dokumente in docs.db aktualisiert"

    echo
    echo "--- Erstelle Exporte ---"
    export_all

    echo
    echo "============================================================"
    echo "DOCS.DB AKTUALISIERT"
    echo "============================================================"

    # Temporäre Datei aufräumen
    rm -f "$docs_temp"
}

# Skript starten
main
