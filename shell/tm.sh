#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "41d629afe1c69d2c780d5115ae26b63fd1c473c3b0afd400eeb42e6935257344", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "shell"}
# tm.go — portiert nach shell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
declare -A TM_ENTRIES=()
TM_PATH=""

# Struktur für TMEntry (als JSON-String)
# Die Felder sind: cache_key, segment_id, source_path, text_hash, text, translated, provider, model, src_lang, tgt_lang, updated_at

# Funktion zum Laden der Übersetzungsspeicherdatei
load_translation_memory() {
    local path="$1"
    TM_PATH="$path"

    # Wenn die Datei nicht existiert, ist das okay - wir beginnen mit einem leeren Speicher
    if [[ ! -f "$path" ]]; then
        return 0
    fi

    # Zeilenweise Lesen und Parsen
    while IFS= read -r line || [[ -n "${line:-}" ]]; do
        local trimmed
        trimmed=$(echo "$line" | tr -d '\r\n' | xargs)
        if [[ -n "$trimmed" ]]; then
            # Validieren, dass es gültiges JSON ist (rudimentär)
            if echo "$trimmed" | jq empty 2>/dev/null; then
                local cache_key
                cache_key=$(echo "$trimmed" | jq -r '.cache_key // ""')
                local translated
                translated=$(echo "$trimmed" | jq -r '.translated // ""' | xargs)
                
                if [[ -n "$cache_key" ]] && [[ -n "$translated" ]]; then
                    TM_ENTRIES["$cache_key"]="$trimmed"
                fi
            else
                echo "Fehler beim Decodieren des Übersetzungsspeichers" >&2
                return 1
            fi
        fi
    done < "$path"
    
    return 0
}

# Funktion zum Abrufen eines Eintrags anhand des Cache-Schlüssels
get_tm_entry() {
    local cache_key="$1"
    
    if [[ -z "${TM_ENTRIES[$cache_key]:-}" ]]; then
        echo "false"
        return
    fi
    
    local entry="${TM_ENTRIES[$cache_key]}"
    local translated
    translated=$(echo "$entry" | jq -r '.translated // ""' | xargs)
    
    if [[ -z "$translated" ]]; then
        echo "false"
        return
    fi
    
    echo "$entry"
    echo "true"
}

# Funktion zum Hinzufügen oder Aktualisieren eines Eintrags
put_tm_entry() {
    local entry_json="$1"
    local cache_key
    cache_key=$(echo "$entry_json" | jq -r '.cache_key // ""')
    
    if [[ -z "$cache_key" ]]; then
        return
    fi
    
    TM_ENTRIES["$cache_key"]="$entry_json"
}

# Funktion zum Speichern der Übersetzungsspeicherdatei
save_translation_memory() {
    if [[ -z "$TM_PATH" ]]; then
        return 0
    fi
    
    local dir
    dir=$(dirname "$TM_PATH")
    mkdir -p "$dir"
    
    local tmp_path="${TM_PATH}.tmp"
    
    # Sortierte Schlüssel sammeln
    local keys=()
    for key in "${!TM_ENTRIES[@]}"; do
        keys+=("$key")
    done
    IFS=$'\n' keys=($(sort <<<"${keys[*]}"))
    unset IFS
    
    {
        for key in "${keys[@]}"; do
            echo "${TM_ENTRIES[$key]}"
        done
    } > "$tmp_path"
    
    mv "$tmp_path" "$TM_PATH"
}
