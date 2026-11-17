#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "7bd707a001a3919c3bf6f341317e2be0034dc531c21491052e7bdedce80a0030", "source_sha256": "f55ff3c9a1d0fb13ff0d5dd08f91e1c1a304c7d83f3d1bb93f165f2437d276b9", "target_language": "shell"}
# json_schema_validator.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
# Erweitert Pydantic mit externen Schema-Dateien.

# Prüfe ob jq installiert ist
if ! command -v jq &>/dev/null; then
    echo "jq ist nicht installiert. Bitte installieren Sie jq." >&2
    exit 1
fi

# Prüfe ob jsonschema (python) verfügbar ist
if ! python3 -c "import jsonschema" 2>/dev/null; then
    echo "jsonschema Python Modul nicht gefunden. Führen Sie 'pip install jsonschema' aus." >&2
    exit 1
fi

# Globale Variablen
INPUT=""
SCHEMA_FILE=""
IS_FILE=false
REPAIR=true

# Fehlermeldung ausgeben und beenden
error_exit() {
    echo "✗ $1" >&2
    exit 1
}

# JSON parsen und ggf. reparieren
parse_json() {
    local raw_input="$1"
    local repair="$2"
    
    if [[ "$repair" == true ]]; then
        # Entferne einfache Anführungszeichen und andere typische Formatierungsfehler
        echo "$raw_input" | sed "s/'/\"/g"
    else
        echo "$raw_input"
    fi
}

# Schema laden
load_schema() {
    local schema_source="$1"
    
    if [[ -f "$schema_source" ]]; then
        if ! jq empty "$schema_source" 2>/dev/null; then
            error_exit "Ungültiges JSON in Schema-Datei: $schema_source"
        fi
        cat "$schema_source"
    elif echo "$schema_source" | jq empty 2>/dev/null; then
        echo "$schema_source"
    else
        error_exit "Schema nicht gefunden oder ungültig: $schema_source"
    fi
}

# Mit jsonschema validieren
validate_with_jsonschema() {
    local data="$1"
    local schema="$2"
    
    local temp_data
    local temp_schema
    temp_data=$(mktemp)
    temp_schema=$(mktemp)
    
    echo "$data" > "$temp_data"
    echo "$schema" > "$temp_schema"
    
    # Validierung mit Python jsonschema
    python3 -c "
import sys
import json
from jsonschema import validate, ValidationError

try:
    with open('$temp_data') as f:
        data = json.load(f)
    with open('$temp_schema') as f:
        schema = json.load(f)
    validate(instance=data, schema=schema)
    print('true')
except ValidationError as e:
    print('false')
    print(str(e), file=sys.stderr)
except Exception as e:
    print('false')
    print(str(e), file=sys.stderr)
" 2>"$temp_data.err"
    
    local result
    result=$(cat "$temp_data")
    
    if [[ "$result" != "true" ]]; then
        local error_msg
        error_msg=$(cat "$temp_data.err")
        rm -f "$temp_data" "$temp_schema" "$temp_data.err"
        error_exit "Schema-Validierung fehlgeschlagen: $error_msg"
    fi
    
    rm -f "$temp_data" "$temp_schema" "$temp_data.err"
    echo "true"
}

# Parsen, reparieren und validieren
validate_and_convert() {
    local raw_input="$1"
    local schema="$2"
    local repair="$3"
    
    local parsed_data
    parsed_data=$(parse_json "$raw_input" "$repair")
    
    # Validiere das geladene Schema
    local schema_dict
    schema_dict=$(load_schema "$schema")
    
    validate_with_jsonschema "$parsed_data" "$schema_dict"
    echo "$parsed_data"
}

# Hilfsfunktionen für Schema Builder
schema_object() {
    local properties="$1"
    local required="${2:-}"
    
    local schema='{"type":"object","properties":'"$properties"'}'
    
    if [[ -n "$required" ]]; then
        schema=$(echo "$schema" | jq --argjson req "$required" '.required = $req')
    fi
    
    echo "$schema"
}

schema_string() {
    local enum="${1:-}"
    local pattern="${2:-}"
    local min_length="${3:-}"
    
    local schema='{"type":"string"}'
    
    if [[ -n "$enum" && "$enum" != "null" ]]; then
        schema=$(echo "$schema" | jq --argjson en "$enum" '.enum = $en')
    fi
    
    if [[ -n "$pattern" && "$pattern" != "null" ]]; then
        schema=$(echo "$schema" | jq --arg pat "$pattern" '.pattern = $pat')
    fi
    
    if [[ -n "$min_length" && "$min_length" != "null" ]]; then
        schema=$(echo "$schema" | jq --argjson minl "$min_length" '.minLength = $minl')
    fi
    
    echo "$schema"
}

schema_integer() {
    local minimum="${1:-}"
    local maximum="${2:-}"
    
    local schema='{"type":"integer"}'
    
    if [[ -n "$minimum" && "$minimum" != "null" ]]; then
        schema=$(echo "$schema" | jq --argjson min "$minimum" '.minimum = $min')
    fi
    
    if [[ -n "$maximum" && "$maximum" != "null" ]]; then
        schema=$(echo "$schema" | jq --argjson max "$maximum" '.maximum = $max')
    fi
    
    echo "$schema"
}

schema_array() {
    local items="$1"
    local min_items="${2:-}"
    
    local schema='{"type":"array","items":'"$items"'}'
    
    if [[ -n "$min_items" && "$min_items" != "null" ]]; then
        schema=$(echo "$schema" | jq --argjson mini "$min_items" '.minItems = $mini')
    fi
    
    echo "$schema"
}

# Hauptprogramm
main() {
    local input_arg=""
    local schema_arg=""
    local file_flag=false
    local repair_flag=true
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --schema|-s)
                schema_arg="$2"
                shift 2
                ;;
            --file|-f)
                file_flag=true
                shift
                ;;
            --repair|-r)
                repair_flag=true
                shift
                ;;
            --no-repair)
                repair_flag=false
                shift
                ;;
            *)
                if [[ -z "$input_arg" ]]; then
                    input_arg="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$input_arg" || -z "$schema_arg" ]]; then
        echo "Verwendung: $0 [--file|-f] [--repair|--no-repair] <Eingabe> --schema|-s <Schema>" >&2
        exit 1
    fi
    
    # Eingabe laden (automatisch Datei oder String erkennen)
    local raw_input=""
    if [[ "$file_flag" == true ]] || [[ -f "$input_arg" ]]; then
        if [[ ! -f "$input_arg" ]]; then
            error_exit "Eingabedatei nicht gefunden: $input_arg"
        fi
        raw_input=$(cat "$input_arg")
    else
        raw_input="$input_arg"
    fi
    
    # Validierung durchführen
    local result
    result=$(validate_and_convert "$raw_input" "$schema_arg" "$repair_flag" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "✗ Validierung fehlgeschlagen: $result" >&2
        exit 1
    fi
    
    echo "$result" | jq .
    echo "✓ Validierung erfolgreich" >&2
}

# Wenn das Skript direkt aufgerufen wird
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
