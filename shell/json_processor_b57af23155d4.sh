#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "e2393c61f2485f6afbe2b340d90efb4886bf219ddb31984cb7407d40f01e38b8", "source_sha256": "f68a161573356fe83ce98ebe454cffaef6896f81d310cd932a9847500e671f9b", "target_language": "shell"}
# json_processor.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# JSON Processor mit Bash-Implementierung
# Für robuste Verarbeitung von LLM-Outputs

# Globale Variablen
HAS_JSON_REPAIR=false
JSON_PROCESSING_ERROR=1
JSON_VALIDATION_ERROR=2
JSON_REPAIR_ERROR=3

# Fehlerfunktionen
json_processing_error() {
    echo "Error: $1" >&2
    exit $JSON_PROCESSING_ERROR
}

json_validation_error() {
    echo "Error: JSON validation failed: $1" >&2
    exit $JSON_VALIDATION_ERROR
}

json_repair_error() {
    echo "Error: JSON repair failed: $1" >&2
    exit $JSON_REPAIR_ERROR
}

# Prüfe ob jq installiert ist
if ! command -v jq &> /dev/null; then
    echo "Error: jq not installed. Please install jq" >&2
    exit 1
fi

# Prüfe ob json_repair verfügbar ist (simuliert)
if command -v python3 &> /dev/null && python3 -c "import json_repair" 2>/dev/null; then
    HAS_JSON_REPAIR=true
else
    echo "Warning: json_repair not available. Using basic repair functions" >&2
fi

# JSON Reparatur-Funktion
repair_json_string() {
    local raw_json="$1"
    
    if $HAS_JSON_REPAIR; then
        python3 -c "
import json_repair
import sys
try:
    repaired = json_repair.repair_json(sys.argv[1], return_objects=False)
    print(repaired)
except Exception as e:
    sys.exit(1)
" "$raw_json" || json_repair_error "JSON repair failed"
    else
        # Fallback: Manuelle Reparaturen
        local cleaned="$raw_json"
        
        # Entferne JavaScript-Kommentare
        cleaned=$(echo "$cleaned" | sed 's|//.*$||g')
        cleaned=$(echo "$cleaned" | sed 's|/\*.*\*/||g')
        
        # Entferne trailing commas vor ] oder }
        cleaned=$(echo "$cleaned" | sed 's/,[[:space:]]*\]/]/g')
        cleaned=$(echo "$cleaned" | sed 's/,[[:space:]]*\}/}/g')
        
        echo "$cleaned"
    fi
}

# JSON Parsing mit optionaler Reparatur
parse_json() {
    local raw_input="$1"
    local repair="${2:-true}"
    
    raw_input=$(echo "$raw_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Versuche zuerst direktes Parsing
    if echo "$raw_input" | jq . >/dev/null 2>&1; then
        echo "$raw_input"
        return 0
    fi
    
    # Extrahiere JSON aus Markdown-Code-Blöcken
    if echo "$raw_input" | grep -q '```'; then
        # Suche nach JSON in ```json ... ``` oder ``` ... ```
        local patterns=(
            '```json[[:space:]]*\(.*\)[[:space:]]*```'
            '```[[:space:]]*\({.*}\)[[:space:]]*```'
            '```[[:space:]]*\(\[.*\]\)[[:space:]]*```'
        )
        
        for pattern in "${patterns[@]}"; do
            local match=$(echo "$raw_input" | sed -n "s/.*$pattern.*/\1/p" | head -1)
            if [ -n "$match" ] && echo "$match" | jq . >/dev/null 2>&1; then
                echo "$match"
                return 0
            fi
        done
    fi
    
    # Versuche Reparatur
    if [ "$repair" = "true" ]; then
        local repaired=$(repair_json_string "$raw_input")
        if echo "$repaired" | jq . >/dev/null 2>&1; then
            echo "$repaired"
            return 0
        else
            json_processing_error "Could not parse JSON even after repair"
        fi
    fi
    
    json_processing_error "Could not parse JSON"
}

# Sicheres JSON-Parsing mit Fallback
safe_json_loads() {
    local raw_input="$1"
    local default="${2:-null}"
    local repair="${3:-true}"
    
    if result=$(parse_json "$raw_input" "$repair" 2>/dev/null); then
        echo "$result"
    else
        echo "$default"
    fi
}

# Extrahiere JSON-Objekte aus Text
extract_json_from_text() {
    local text="$1"
    local results=()
    
    # Pattern für JSON-Objekte und Arrays (vereinfacht)
    local obj_matches=$(echo "$text" | grep -o '{[^}]*}' | head -10)
    local arr_matches=$(echo "$text" | grep -o '\[[^]]*\]' | head -10)
    
    while IFS= read -r match; do
        if [ -n "$match" ]; then
            if result=$(parse_json "$match" "true" 2>/dev/null); then
                results+=("$result")
            fi
        fi
    done <<< "$obj_matches"
    
    while IFS= read -r match; do
        if [ -n "$match" ]; then
            if result=$(parse_json "$match" "true" 2>/dev/null); then
                results+=("$result")
            fi
        fi
    done <<< "$arr_matches"
    
    printf '%s\n' "${results[@]}"
}

# Hauptfunktion für CLI
main() {
    local input=""
    local is_file=false
    local repair=true
    local pretty=false
    
    # Einfache Argumentenverarbeitung
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                is_file=true
                shift
                ;;
            -r|--repair)
                repair=true
                shift
                ;;
            --no-repair)
                repair=false
                shift
                ;;
            -p|--pretty)
                pretty=true
                shift
                ;;
            *)
                input="$1"
                shift
                ;;
        esac
    done
    
    if [ -z "$input" ]; then
        echo "Error: No input provided" >&2
        exit 1
    fi
    
    local content=""
    if [ "$is_file" = true ]; then
        if [ ! -f "$input" ]; then
            echo "Error: File not found: $input" >&2
            exit 1
        fi
        content=$(cat "$input")
    else
        content="$input"
    fi
    
    local result=$(parse_json "$content" "$repair")
    
    if [ "$pretty" = true ]; then
        echo "$result" | jq .
    else
        echo "$result"
    fi
}

# Wenn direkt ausgeführt
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
