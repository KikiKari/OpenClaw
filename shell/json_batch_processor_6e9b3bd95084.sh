#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "3a4c78072fd3fd3ac5a6e821425237b4a55264611cd3ed3ad5499f31130098bb", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "shell"}
# json_batch_processor.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).

# Globale Variablen
HAS_PYDANTIC=false
REPAIR=true
WORKERS=4
OUTPUT=""
SUMMARY=false
JSONL_MODE=false

# Prüfe ob jq installiert ist
if ! command -v jq &>/dev/null; then
    echo "jq ist nicht installiert. Bitte installieren." >&2
    exit 1
fi

# Prüfe ob pydantic verfügbar ist (über Python)
if python3 -c "import pydantic" &>/dev/null; then
    HAS_PYDANTIC=true
fi

# Hilfsfunktionen
log_error() {
    echo "ERROR: $*" >&2
}

# Liest JSON-Lines (NDJSON) Datei Zeile für Zeile
read_jsonl() {
    local file_path="$1"
    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$line" ]]; then
            continue
        fi
        echo "$line"
    done < "$file_path"
}

# Repariert JSON falls nötig
repair_json() {
    local json_str="$1"
    # Entferne trailing Kommas vor } oder ]
    json_str=$(echo "$json_str" | sed 's/,\s*\([}\]]\)/\1/g')
    echo "$json_str"
}

# Parst JSON mit jq
parse_json() {
    local content="$1"
    local repair="${2:-true}"

    if [[ "$repair" == true ]]; then
        content=$(repair_json "$content")
    fi

    echo "$content" | jq -e . >/dev/null 2>&1
    echo "$content"
}

# Dummy-Funktion für Validierung (ersetzt pydantic)
validate_json() {
    local content="$1"
    local model="$2"
    local repair="${3:-true}"

    # In echter Implementierung würde hier das Modell verwendet
    parse_json "$content" "$repair"
}

# Schreibt Ergebnis als JSON-Lines
write_jsonl() {
    local results=("$@")
    local output_path="$OUTPUT"
    local only_successful="${results[-1]}"
    unset 'results[${#results[@]}-1]'

    {
        for result in "${results[@]}"; do
            if [[ "$only_successful" == true ]] && [[ "$(echo "$result" | jq -r '.success')" != "true" ]]; then
                continue
            fi
            echo "$result"
        done
    } > "$output_path"
}

# Verarbeitet eine einzelne JSON-Datei
process_single_file() {
    local path="$1"
    local idx="$2"
    local repair="${3:-$REPAIR}"

    local content
    local success=true
    local data=""
    local error=""

    if ! content=$(cat "$path" 2>/dev/null); then
        success=false
        error="Could not read file"
    else
        if ! data=$(parse_json "$content" "$repair"); then
            success=false
            error="Invalid JSON"
        fi
    fi

    jq -n --arg idx "$idx" \
          --arg source "$path" \
          --argjson success "$success" \
          --arg data "$data" \
          --arg error "$error" \
          '{index: ($idx | tonumber), source: $source, success: $success, data: $data, error: $error}'
}

# Verarbeitet eine JSONL-Datei zeilenweise
process_jsonl_file() {
    local file_path="$1"
    local repair="${2:-$REPAIR}"
    local results=()
    local line_num=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$line" ]]; then
            continue
        fi

        local success=true
        local data=""
        local error=""

        if ! data=$(parse_json "$line" "$repair"); then
            success=false
            error="Invalid JSON"
        fi

        local result
        result=$(jq -n --arg idx "$line_num" \
                     --arg source "$file_path:$line_num" \
                     --argjson success "$success" \
                     --arg data "$data" \
                     --arg error "$error" \
                     '{index: ($idx | tonumber), source: $source, success: $success, data: $data, error: $error}')
        results+=("$result")
    done < "$file_path"

    printf '%s\n' "${results[@]}"
}

# Verarbeitet mehrere Dateien parallel
process_file_batch() {
    local file_paths=("$@")
    local results=()
    local temp_dir
    temp_dir=$(mktemp -d)

    # Starte Hintergrundprozesse
    local pids=()
    for idx in "${!file_paths[@]}"; do
        local path="${file_paths[$idx]}"
        (
            result=$(process_single_file "$path" "$idx" "$REPAIR")
            echo "$result" > "$temp_dir/result_$idx.json"
        ) &
        pids+=($!)
    done

    # Warte auf alle Prozesse
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done

    # Sammle Ergebnisse
    for idx in "${!file_paths[@]}"; do
        if [[ -f "$temp_dir/result_$idx.json" ]]; then
            results+=("$(cat "$temp_dir/result_$idx.json")")
        fi
    done

    # Sortiere nach Index
    printf '%s\n' "${results[@]}" | jq -s 'sort_by(.index)[]'

    rm -rf "$temp_dir"
}

# Hauptprogramm
main() {
    local inputs=()
    local arg
    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            --jsonl|-l)
                JSONL_MODE=true
                shift
                ;;
            --repair|-r)
                REPAIR=true
                shift
                ;;
            --no-repair)
                REPAIR=false
                shift
                ;;
            --workers|-w)
                WORKERS="$2"
                shift 2
                ;;
            --output|-o)
                OUTPUT="$2"
                shift 2
                ;;
            --summary|-s)
                SUMMARY=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS] INPUTS..."
                echo "Options:"
                echo "  --jsonl, -l         Treat inputs as JSON-Lines files"
                echo "  --repair, -r        Enable JSON repair (default)"
                echo "  --no-repair         Disable JSON repair"
                echo "  --workers N, -w N   Parallel workers (not used in bash)"
                echo "  --output FILE, -o FILE  Output JSON-Lines file"
                echo "  --summary, -s       Show summary only"
                echo "  --help, -h          Show this help"
                exit 0
                ;;
            -*)
                log_error "Unbekannte Option: $arg"
                exit 1
                ;;
            *)
                inputs+=("$arg")
                shift
                ;;
        esac
    done

    if [[ ${#inputs[@]} -eq 0 ]]; then
        log_error "Keine Eingabedateien angegeben."
        exit 1
    fi

    local all_results=()
    local successful=0
    local failed=0

    if [[ "$JSONL_MODE" == true ]]; then
        # JSON-Lines Modus
        for input_path in "${inputs[@]}"; do
            mapfile -t results < <(process_jsonl_file "$input_path" "$REPAIR")
            all_results+=("${results[@]}")
        done
    else
        # Standard JSON Batch
        all_results=$(process_file_batch "${inputs[@]}")
        mapfile -t all_results <<< "$all_results"
    fi

    # Zähle erfolgreiche und fehlgeschlagene
    for result in "${all_results[@]}"; do
        if [[ "$(echo "$result" | jq -r '.success')" == "true" ]]; then
            ((successful++))
        else
            ((failed++))
        fi
    done

    # Ausgabe
    if [[ "$SUMMARY" == true ]]; then
        echo "Processed: $((${#all_results[@]}))"
        echo "Successful: $successful"
        echo "Failed: $failed"
    else
        for result in "${all_results[@]}"; do
            if [[ "$(echo "$result" | jq -r '.success')" == "true" ]]; then
                echo "$result" | jq -r '.data'
            else
                echo "ERROR [$(echo "$result" | jq -r '.source')]: $(echo "$result" | jq -r '.error')" >&2
            fi
        done
    fi

    # Optional: JSONL Output
    if [[ -n "$OUTPUT" ]]; then
        # Füge false als Marker hinzu
        all_results+=("false")
        write_jsonl "${all_results[@]}"
        echo "Results written to: $OUTPUT" >&2
    fi

    # Exit code
    if [[ $failed -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Starte Hauptprogramm
main "$@"
