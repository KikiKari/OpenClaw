#!/usr/bin/env bash
# json_processor.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# JSON Processor mit Bash 5
# Für robuste Verarbeitung von LLM-Outputs.

# Farbcodes für Ausgaben
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Fehlermeldungen
error() {
    echo -e "${RED}Error:${NC} $*" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}Warning:${NC} $*" >&2
}

# Prüfe ob jq installiert ist
if ! command -v jq &>/dev/null; then
    error "jq is required but not installed. Please install jq."
fi

# Globale Variablen
REPAIR_ENABLED=true
PRETTY_PRINT=false

# Repariert häufige JSON-Fehler aus LLM-Outputs
repair_json_string() {
    local raw_json="$1"
    local repaired

    # Entferne JavaScript-Kommentare
    repaired=$(echo "$raw_json" | sed 's|//.*||g' | sed 's|/\*.*\*/||g')

    # Entferne trailing commas vor ] oder }
    repaired=$(echo "$repaired" | sed 's/,\s*\([]}]\)/\1/g')

    # Ersetze einfache Anführungszeichen durch doppelte (nur für Schlüssel und String-Werte)
    # Dies ist eine vereinfachte Logik - vollständige Implementierung wäre komplexer
    echo "$repaired"
}

# Extrahiere JSON aus Markdown-Code-Blöcken
extract_from_markdown() {
    local input="$1"
    local extracted

    # Suche nach ```json ... ``` oder ``` ... ```
    if echo "$input" | grep -Eo '\`\`\`json[[:space:]]*{[^}]*}[[:space:]]*\`\`\`' >/dev/null; then
        extracted=$(echo "$input" | grep -Eo '\`\`\`json[[:space:]]*({[^}]*})[[:space:]]*\`\`\`' | sed 's/```json//' | sed 's/```//' | xargs)
    elif echo "$input" | grep -Eo '\`\`\`[[:space:]]*{[^}]*}[[:space:]]*\`\`\`' >/dev/null; then
        extracted=$(echo "$input" | grep -Eo '\`\`\`[[:space:]]*({[^}]*})[[:space:]]*\`\`\`' | sed 's/```//g' | xargs)
    elif echo "$input" | grep -Eo '\`\`\`[[:space:]]*\[[^]]*\][[:space:]]*\`\`\`' >/dev/null; then
        extracted=$(echo "$input" | grep -Eo '\`\`\`[[:space:]]*(\[[^]]*\])[[:space:]]*\`\`\`' | sed 's/```//g' | xargs)
    fi

    echo "${extracted:-$input}"
}

# Parst JSON-String mit optionaler automatischer Reparatur
parse_json() {
    local raw_input="$1"
    local repair="${2:-true}"
    local parsed

    raw_input=$(echo "$raw_input" | xargs) # strip whitespace

    # Versuche zuerst direktes Parsing
    if echo "$raw_input" | jq . &>/dev/null; then
        echo "$raw_input"
        return
    fi

    # Extrahiere JSON aus Markdown-Code-Blöcken
    if [[ "$raw_input" == *"\\\`\\\`\\\`"* ]]; then
        local extracted
        extracted=$(extract_from_markdown "$raw_input")
        if echo "$extracted" | jq . &>/dev/null; then
            echo "$extracted"
            return
        fi
    fi

    # Versuche Reparatur
    if [[ "$repair" == true ]]; then
        local repaired
        repaired=$(repair_json_string "$raw_input")
        if echo "$repaired" | jq . &>/dev/null; then
            echo "$repaired"
            return
        else
            error "Could not parse JSON even after repair"
        fi
    fi

    error "Could not parse JSON"
}

# Sicheres JSON-Parsing mit Fallback auf Default-Wert
safe_json_loads() {
    local raw_input="$1"
    local default="${2:-null}"
    local repair="${3:-true}"

    if parsed=$(parse_json "$raw_input" "$repair" 2>/dev/null); then
        echo "$parsed"
    else
        echo "$default"
    fi
}

# Extrahiert alle JSON-Objekte aus einem Text
extract_json_from_text() {
    local text="$1"
    local temp_file
    temp_file=$(mktemp)

    # Schreibe Text in temporäre Datei
    echo "$text" > "$temp_file"

    # Suche nach JSON-ähnlichen Mustern
    # Diese Regex sind vereinfacht und können verbessert werden
    grep -oE '\{[^{}]*\}' "$temp_file" 2>/dev/null | while read -r line; do
        if echo "$line" | jq . &>/dev/null; then
            echo "$line"
        fi
    done

    grep -oE '\[[^][]*\]' "$temp_file" 2>/dev/null | while read -r line; do
        if echo "$line" | jq . &>/dev/null; then
            echo "$line"
        fi
    done

    rm -f "$temp_file"
}

# Hauptfunktion
main() {
    local input=""
    local is_file=false
    local repair=true
    local pretty=false

    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
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
            --pretty|-p)
                pretty=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS] INPUT"
                echo "Options:"
                echo "  --file, -f         Input is a file path"
                echo "  --repair, -r       Enable JSON repair (default)"
                echo "  --no-repair        Disable JSON repair"
                echo "  --pretty, -p       Pretty print output"
                echo "  --help, -h         Show this help message"
                exit 0
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$input" ]]; then
        error "No input provided"
    fi

    local content
    if [[ "$is_file" == true ]]; then
        if [[ ! -f "$input" ]]; then
            error "File not found: $input"
        fi
        content=$(cat "$input")
    else
        content="$input"
    fi

    local result
    result=$(parse_json "$content" "$repair")

    if [[ "$pretty" == true ]]; then
        echo "$result" | jq '.'
    else
        echo "$result"
    fi
}

# Skript ausführen
main "$@"
