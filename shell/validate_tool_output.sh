#!/usr/bin/env bash
# validate_tool_output.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/validate_tool_output.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/validate_tool_output.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Validiert Tool-Outputs gegen ein JSON-Schema.
# Für OpenClaw Tool-Call-Validierung.

# Prüfe ob jq installiert ist
if ! command -v jq &> /dev/null; then
    echo "Error: jq not installed" >&2
    exit 1
fi

# Globale Variablen
json_input=""
schema_file=""
input_is_file=false
repair=true
strict=false

# Funktion zur Ausgabe der Hilfe
usage() {
    cat << EOF
Usage: $0 [OPTIONS] JSON_INPUT

Validate tool output against schema

Arguments:
  JSON_INPUT    JSON string or file path

Options:
  --schema FILE, -s FILE    JSON schema file (required)
  --file, -f                Input is a file
  --repair, -r              Repair mode (default: true)
  --strict                  Strict validation
  --help, -h                Show this message and exit
EOF
}

# Argumente parsen
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --schema|-s)
                schema_file="$2"
                shift 2
                ;;
            --file|-f)
                input_is_file=true
                shift
                ;;
            --repair|-r)
                repair=true
                shift
                ;;
            --strict)
                strict=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                json_input="$1"
                shift
                ;;
        esac
    done

    # Pflichtargumente prüfen
    if [[ -z "$schema_file" ]] || [[ -z "$json_input" ]]; then
        echo "Error: both JSON_INPUT and --schema are required" >&2
        usage
        exit 1
    fi
}

# Lade Schema
load_schema() {
    if [[ ! -f "$schema_file" ]]; then
        echo "Error: schema file '$schema_file' does not exist" >&2
        exit 1
    fi
    
    if ! jq empty "$schema_file" 2>/dev/null; then
        echo "Error: invalid JSON in schema file '$schema_file'" >&2
        exit 1
    fi
}

# Lade Input
load_input() {
    if [[ "$input_is_file" == true ]]; then
        if [[ ! -f "$json_input" ]]; then
            echo "Error: input file '$json_input' does not exist" >&2
            exit 1
        fi
        raw_input=$(cat "$json_input")
    else
        raw_input="$json_input"
    fi
    
    # Prüfe ob Input gültiges JSON ist
    if ! echo "$raw_input" | jq empty 2>/dev/null; then
        echo "Error: input is not valid JSON" >&2
        exit 1
    fi
}

# Erstelle dynamisches Modell aus Schema und validiere
validate_json() {
    local schema_props
    local schema_required
    local temp_validated
    
    # Extrahiere Properties und Required-Felder aus dem Schema
    schema_props=$(jq '.properties // {}' "$schema_file")
    schema_required=$(jq -r '.required // [] | .[]' "$schema_file")
    
    # Erstelle leeres validiertes JSON-Objekt
    temp_validated="{}"
    
    # Iteriere durch alle Properties im Schema
    local props
    props=$(echo "$schema_props" | jq -r 'keys[]')
    
    while IFS= read -r key; do
        local field_info
        field_info=$(echo "$schema_props" | jq -r ".[\"$key\"]")
        
        # Bestimme den Typ aus dem Schema
        local json_type
        json_type=$(echo "$field_info" | jq -r '.type // "string"')
        
        # Prüfe ob Feld required ist
        local is_required=false
        while IFS= read -r req_key; do
            if [[ "$req_key" == "$key" ]]; then
                is_required=true
                break
            fi
        done <<< "$schema_required"
        
        # Hole das Feld aus dem Input
        local input_value
        input_value=$(echo "$raw_input" | jq -r ".[\"$key\"]")
        
        # Wenn Feld nicht vorhanden und required, Fehler
        if [[ "$input_value" == "null" ]] && [[ "$is_required" == true ]]; then
            echo "Validation error: required field '$key' is missing" >&2
            exit 1
        fi
        
        # Wenn Feld nicht vorhanden und nicht required, überspringe
        if [[ "$input_value" == "null" ]] && [[ "$is_required" == false ]]; then
            continue
        fi
        
        # Reparatur/Typkonvertierung wenn aktiviert
        if [[ "$repair" == true ]]; then
            case "$json_type" in
                integer)
                    if [[ "$input_value" =~ ^-?[0-9]+$ ]]; then
                        temp_validated=$(echo "$temp_validated" | jq ".[\"$key\"] = ($input_value | tonumber)")
                    elif [[ "$is_required" == true ]]; then
                        echo "Validation error: field '$key' should be integer but is '$input_value'" >&2
                        exit 1
                    fi
                    ;;
                number)
                    if [[ "$input_value" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
                        temp_validated=$(echo "$temp_validated" | jq ".[\"$key\"] = ($input_value | tonumber)")
                    elif [[ "$is_required" == true ]]; then
                        echo "Validation error: field '$key' should be number but is '$input_value'" >&2
                        exit 1
                    fi
                    ;;
                boolean)
                    if [[ "$input_value" == "true" ]] || [[ "$input_value" == "false" ]]; then
                        temp_validated=$(echo "$temp_validated" | jq ".[\"$key\"] = ($input_value | test(\"true\"))")
                    elif [[ "$is_required" == true ]]; then
                        echo "Validation error: field '$key' should be boolean but is '$input_value'" >&2
                        exit 1
                    fi
                    ;;
                array)
                    if echo "$input_value" | jq -e 'type == "array"' >/dev/null 2>&1; then
                        temp_validated=$(echo "$temp_validated" | jq ".[\"$key\"] = $input_value")
                    elif [[ "$is_required" == true ]]; then
                        echo "Validation error: field '$key' should be array but is '$input_value'" >&2
                        exit 1
                    fi
                    ;;
                object)
                    if echo "$input_value" | jq -e 'type == "object"' >/dev/null 2>&1; then
                        temp_validated=$(echo "$temp_validated" | jq ".[\"$key\"] = $input_value")
                    elif [[ "$is_required" == true ]]; then
                        echo "Validation error: field '$key' should be object but is '$input_value'" >&2
                        exit 1
                    fi
                    ;;
                *)
                    # Standard: string
                    temp_validated=$(echo "$temp_validated" | jq ".[\"$key\"] = \"$input_value\"")
                    ;;
            esac
        else
            # Ohne Reparatur: einfach übernehmen
            temp_validated=$(echo "$temp_validated" | jq ".[\"$key\"] = $input_value")
        fi
    done <<< "$props"
    
    # Bei strikter Validierung zusätzliche Felder prüfen
    if [[ "$strict" == true ]]; then
        local input_keys
        input_keys=$(echo "$raw_input" | jq -r 'keys[]')
        
        while IFS= read -r key; do
            if ! echo "$schema_props" | jq -e "has(\"$key\")" >/dev/null 2>&1; then
                echo "Validation error: unexpected field '$key' in strict mode" >&2
                exit 1
            fi
        done <<< "$input_keys"
    fi
    
    # Gebe validiertes JSON aus
    echo "$temp_validated" | jq .
}

# Hauptfunktion
main() {
    parse_args "$@"
    load_schema
    load_input
    validate_json
}

# Skript ausführen
main "$@"
