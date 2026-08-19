#!/bin/bash
# json_batch_processor.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).

# Globale Variablen
HAS_JQ=false
HAS_PYDANTIC=false
REPAIR=true
WORKERS=4
OUTPUT=""
SUMMARY=false
JSONL_MODE=false

# Prüfe Abhängigkeiten
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=true
fi

# Farben für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Hilfsfunktionen
log_error() {
    echo -e "${RED}ERROR${NC}: $*" >&2
}

log_success() {
    echo -e "${GREEN}SUCCESS${NC}: $*"
}

# JSON parsen mit optionaler Reparatur
parse_json() {
    local content="$1"
    local repair="${2:-true}"
    
    if [[ "$repair" == true ]] && [[ "$HAS_JQ" == true ]]; then
        echo "$content" | jq -R -r 'capture("(?<json>.*)"; null) | .json' 2>/dev/null || echo "$content"
        if echo "$content" | jq empty 2>/dev/null; then
            echo "$content"
        else
            # Versuche einfache Reparaturen
            local repaired
            repaired=$(echo "$content" | sed 's/\bTrue\b/true/g; s/\bFalse\b/false/g; s/\bNone\b/null/g')
            if echo "$repaired" | jq empty 2>/dev/null; then
                echo "$repaired"
            else
                echo "$content"
            fi
        fi
    else
        echo "$content"
    fi
}

# Prüft ob jq verfügbar ist und funktioniert
check_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not installed"
        exit 1
    fi
}

# Liest JSON-Lines Datei zeilenweise
read_jsonl() {
    local file_path="$1"
    local line_num=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$line" ]]; then
            continue
        fi
        
        echo "$line_num|$line"
    done < "$file_path"
}

# Verarbeitet eine einzelne JSON-Datei
process_single_file() {
    local file_path="$1"
    local idx="$2"
    local repair="${3:-$REPAIR}"
    
    if [[ ! -f "$file_path" ]]; then
        echo "{\"index\":$idx,\"source\":\"$file_path\",\"success\":false,\"error\":\"File not found\"}"
        return
    fi
    
    local content
    content=$(cat "$file_path") || {
        echo "{\"index\":$idx,\"source\":\"$file_path\",\"success\":false,\"error\":\"Cannot read file\"}"
        return
    }
    
    local parsed
    parsed=$(parse_json "$content" "$repair")
    
    if echo "$parsed" | jq empty 2>/dev/null; then
        echo "{\"index\":$idx,\"source\":\"$file_path\",\"success\":true,\"data\":$(echo "$parsed" | jq -c .)}"
    else
        echo "{\"index\":$idx,\"source\":\"$file_path\",\"success\":false,\"error\":\"Invalid JSON\"}"
    fi
}

# Verarbeitet mehrere JSON-Dateien parallel
process_file_batch() {
    local -a file_paths=("${!1}")
    local repair="${2:-$REPAIR}"
    local max_workers="${3:-$WORKERS}"
    local -a results=()
    
    # Temporäre Datei für Ergebnisse
    local temp_results
    temp_results=$(mktemp)
    
    # Parallel verarbeiten
    local i=0
    local pid
    local -a pids=()
    
    for file_path in "${file_paths[@]}"; do
        process_single_file "$file_path" "$i" "$repair" > "$temp_results.$$.$i" &
        pids+=($!)
        ((i++))
        
        # Limitieren auf max_workers
        if (( ${#pids[@]} >= max_workers )); then
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
        fi
    done
    
    # Warten auf alle verbleibenden Prozesse
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    # Ergebnisse sammeln und sortieren
    for ((j=0; j<i; j++)); do
        if [[ -f "$temp_results.$$.$j" ]]; then
            cat "$temp_results.$$.$j"
            rm -f "$temp_results.$$.$j"
        fi
    done | jq -s 'sort_by(.index)'
    
    rm -f "$temp_results"
}

# Verarbeitet eine JSON-Lines Datei
process_jsonl_file() {
    local file_path="$1"
    local repair="${2:-$REPAIR}"
    local line_num=0
    
    while IFS='|' read -r lnum line || [[ -n "$line" ]]; do
        ((line_num++))
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$line" ]]; then
            continue
        fi
        
        local parsed
        parsed=$(parse_json "$line" "$repair")
        
        if echo "$parsed" | jq empty 2>/dev/null; then
            echo "{\"index\":$line_num,\"source\":\"$file_path:$line_num\",\"success\":true,\"data\":$(echo "$parsed" | jq -c .)}"
        else
            echo "{\"index\":$line_num,\"source\":\"$file_path:$line_num\",\"success\":false,\"error\":\"Invalid JSON\"}"
        fi
    done < <(read_jsonl "$file_path")
}

# Schreibt Ergebnisse als JSON-Lines
write_jsonl() {
    local results="$1"
    local output_path="$2"
    local only_successful="${3:-true}"
    
    if [[ "$only_successful" == true ]]; then
        echo "$results" | jq -c 'select(.success)' > "$output_path"
    else
        echo "$results" | jq -c '.' > "$output_path"
    fi
}

# Zeigt Zusammenfassung
show_summary() {
    local results="$1"
    local total processed failed
    
    total=$(echo "$results" | jq -s 'length')
    processed=$(echo "$results" | jq -s '[.[] | select(.success)] | length')
    failed=$((total - processed))
    
    echo "Processed: $total"
    echo "Successful: $processed"
    echo "Failed: $failed"
}

# Hauptfunktion
main() {
    local -a inputs=()
    local arg
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
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
                echo "  --jsonl, -l          Treat inputs as JSON-Lines files"
                echo "  --repair, -r         Enable JSON repair (default)"
                echo "  --no-repair          Disable JSON repair"
                echo "  --workers N, -w N    Number of parallel workers (default: 4)"
                echo "  --output FILE, -o FILE Write results to JSON-Lines file"
                echo "  --summary, -s        Show summary only"
                echo "  --help, -h           Show this help"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                inputs+=("$1")
                shift
                ;;
        esac
    done
    
    if [[ ${#inputs[@]} -eq 0 ]]; then
        log_error "No input files specified"
        exit 1
    fi
    
    local results=""
    
    if [[ "$JSONL_MODE" == true ]]; then
        # JSON-Lines Modus
        for input in "${inputs[@]}"; do
            if [[ ! -f "$input" ]]; then
                log_error "File not found: $input"
                continue
            fi
            results+=$(process_jsonl_file "$input" "$REPAIR")
            results+=$'\n'
        done
    else
        # Standard JSON Batch
        local -a file_paths=()
        for input in "${inputs[@]}"; do
            if [[ ! -f "$input" ]]; then
                log_error "File not found: $input"
                continue
            fi
            file_paths+=("$input")
        done
        
        if [[ ${#file_paths[@]} -gt 0 ]]; then
            results=$(process_file_batch file_paths[@] "$REPAIR" "$WORKERS")
        fi
    fi
    
    # Ausgabe
    local total=0
    local successful=0
    local failed=0
    
    if [[ -n "$results" ]]; then
        total=$(echo "$results" | jq -s 'length')
        successful=$(echo "$results" | jq -s '[.[] | select(.success)] | length')
        failed=$((total - successful))
        
        if [[ "$SUMMARY" == true ]]; then
            show_summary "$results"
        else
            echo "$results" | jq -c '.[]' | while read -r result; do
                if [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                    echo "$result" | jq -r '.data'
                else
                    echo "ERROR [$(echo "$result" | jq -r '.source')]: $(echo "$result" | jq -r '.error')" >&2
                fi
            done
        fi
    fi
    
    # Optional: JSONL Output
    if [[ -n "$OUTPUT" ]]; then
        write_jsonl "$results" "$OUTPUT" false
        log_success "Results written to: $OUTPUT"
    fi
    
    # Exit code
    if [[ $failed -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Skript starten
main "$@"
