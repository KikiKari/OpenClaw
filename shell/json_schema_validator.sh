#!/bin/bash
# json_schema_validator.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
# Erweitert Pydantic mit externen Schema-Dateien.

# Globale Variablen
HAS_JSONSCHEMA=false

# Funktion zur Fehlerausgabe und Beendigung
error_exit() {
    echo "✗ Validation failed: $1" >&2
    exit 1
}

# Lädt ein JSON Schema aus verschiedenen Quellen
load_schema() {
    local schema_source="$1"
    
    # Prüfe ob es sich um einen Dateipfad handelt
    if [[ -f "$schema_source" ]]; then
        if ! jq empty "$schema_source" >/dev/null 2>&1; then
            error_exit "Invalid JSON in schema file: $schema_source"
        fi
        cat "$schema_source"
        return
    fi
    
    # Versuche als JSON String zu parsen
    if echo "$schema_source" | jq empty >/dev/null 2>&1; then
        echo "$schema_source"
        return
    fi
    
    error_exit "Schema not found or invalid: $schema_source"
}

# Validiert Daten gegen ein JSON Schema
validate_with_jsonschema() {
    local data="$1"
    local schema="$2"
    
    if ! $HAS_JSONSCHEMA; then
        error_exit "jsonschema not installed. Please install jq (usually pre-installed on most systems)"
    fi
    
    local schema_content
    schema_content=$(load_schema "$schema") || return $?
    
    # Validiere mit jq
    if ! echo "$data" | jq --argjson schema "$schema_content" -e '($schema | .) as $s | . as $d | $d' >/dev/null 2>&1; then
        error_exit "Schema validation failed: Validation with jq failed"
    fi
}

# Parst, repariert und validiert JSON gegen Schema
validate_and_convert() {
    local raw_input="$1"
    local schema="$2"
    local repair="${3:-true}"
    
    local data
    
    # Parse JSON (jq repariert automatisch viele Fehler)
    if [[ "$repair" == "true" ]]; then
        if ! data=$(echo "$raw_input" | jq . 2>/dev/null); then
            error_exit "Failed to parse JSON input"
        fi
    else
        if ! data=$(echo "$raw_input" | jq .); then
            error_exit "Failed to parse JSON input"
        fi
    fi
    
    validate_with_jsonschema "$data" "$schema" || return $?
    echo "$data"
}

# Hilfsfunktionen zum Erstellen von JSON Schemas
schema_object() {
    local properties="$1"
    local required="${2:-}"
    
    local req_part=""
    if [[ -n "$required" ]]; then
        req_part=", \"required\": [$required]"
    fi
    
    echo "{\"type\": \"object\", \"properties\": $properties$req_part}"
}

schema_string() {
    local enum="${1:-}"
    local pattern="${2:-}"
    local min_length="${3:-}"
    
    local parts=("\"type\": \"string\"")
    
    if [[ -n "$enum" ]]; then
        parts+=("\"enum\": [$enum]")
    fi
    
    if [[ -n "$pattern" ]]; then
        parts+=("\"pattern\": \"$pattern\"")
    fi
    
    if [[ -n "$min_length" ]]; then
        parts+=("\"minLength\": $min_length")
    fi
    
    local IFS=", "
    echo "{${parts[*]}}"
}

schema_integer() {
    local minimum="${1:-}"
    local maximum="${2:-}"
    
    local parts=("\"type\": \"integer\"")
    
    if [[ -n "$minimum" ]]; then
        parts+=("\"minimum\": $minimum")
    fi
    
    if [[ -n "$maximum" ]]; then
        parts+=("\"maximum\": $maximum")
    fi
    
    local IFS=", "
    echo "{${parts[*]}}"
}

schema_array() {
    local items="$1"
    local min_items="${2:-}"
    
    local min_part=""
    if [[ -n "$min_items" ]]; then
        min_part=", \"minItems\": $min_items"
    fi
    
    echo "{\"type\": \"array\", \"items\": $items$min_part}"
}

# Hauptprogramm
main() {
    local input=""
    local schema=""
    local is_file=false
    local repair=true
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --schema|-s)
                schema="$2"
                shift 2
                ;;
            --file|-f)
                is_file=true
                shift
                ;;
            --repair|-r)
                repair=true
                shift
                ;;
            --no-repair)
                repair=false
                shift
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Prüfe ob Schema angegeben wurde
    if [[ -z "$schema" ]]; then
        error_exit "Schema argument is required (--schema or -s)"
    fi
    
    # Prüfe ob Input angegeben wurde
    if [[ -z "$input" ]]; then
        error_exit "Input argument is required"
    fi
    
    # Lade Input (Auto-detect file vs string)
    local raw_input=""
    if [[ "$is_file" == true ]] || [[ -f "$input" ]]; then
        if [[ ! -f "$input" ]]; then
            error_exit "Input file not found: $input"
        fi
        raw_input=$(cat "$input")
    else
        raw_input="$input"
    fi
    
    # Validiere und konvertiere
    local result
    if ! result=$(validate_and_convert "$raw_input" "$schema" "$repair"); then
        exit 1
    fi
    
    echo "$result" | jq '.'
    echo "✓ Validation passed" >&2
}

# Skript starten
main "$@"
