#!/bin/bash
# spawn_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sub-Agent spawner - Einfache CLI für sessions_spawn

WORKSPACE="/home/openclaw/.openclaw/workspace"
if [[ ":$PATH:" != *":$WORKSPACE:"* ]]; then
    export PATH="$WORKSPACE:$PATH"
fi

# Prüfe ob openclaw_models Modul verfügbar ist
if ! python3 -c "import openclaw_models" 2>/dev/null; then
    echo "Modellkonfiguration kann nicht geladen werden: openclaw_models Modul nicht gefunden" >&2
    exit 1
fi

# Lade verfügbare Modelle via Python
readarray -t MODELS < <(python3 -c "
try:
    from openclaw_models import configured_models
    models = configured_models()
    for m in models:
        print(m)
except Exception as e:
    import sys
    print(f'Modellkonfiguration kann nicht geladen werden: {e}', file=sys.stderr)
    sys.exit(1)
")

# Hilfsfunktion zur Überprüfung ob ein Wert in einem Array enthalten ist
contains_element() {
    local element="$1"
    shift
    local array=("$@")
    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            return 0
        fi
    done
    return 1
}

# Funktion zum Erstellen der Konfiguration für sessions_spawn
get_spawn_config() {
    local task="$1"
    local label="${2:-}"
    local model="${3:-}"
    local thinking="${4:-}"
    local timeout="${5:-}"
    local thread="${6:-false}"
    local mode="${7:-run}"

    local config=""
    config+="\"task\":\"$task\""

    if [[ -n "$label" ]]; then
        config+=",\"label\":\"$label\""
    fi

    if [[ -n "$model" ]] && contains_element "$model" "${MODELS[@]}"; then
        config+=",\"model\":\"$model\""
    fi

    if [[ -n "$thinking" ]]; then
        config+=",\"thinking\":\"$thinking\""
    fi

    if [[ -n "$timeout" ]]; then
        config+=",\"runTimeoutSeconds\":$timeout"
    fi

    if [[ "$thread" == "true" ]]; then
        config+=",\"thread\":true"
        if [[ "$mode" == "run" ]]; then
            mode="session"
        fi
    fi

    config+=",\"mode\":\"$mode\""

    echo "{$config}"
}

# Gibt das equivalente Tool-Kommando aus
print_spawn_command() {
    local config="$1"
    echo ""
    echo "🛠️  Tool-Aufruf:"
    echo "=================================================="
    echo "sessions_spawn("
    echo "$config" | jq -r 'to_entries[] | "    \(.key)=\(.value | if type == "string" then "\"\(.|tostring)\"" else . end)"'
    echo ")"
    echo "=================================================="
}

# Gibt das equivalente Slash-Kommando aus
print_slash_command() {
    local config="$1"
    local task label model thinking cmd

    task=$(echo "$config" | jq -r '.task // ""')
    label=$(echo "$config" | jq -r '.label // "agent"')
    model=$(echo "$config" | jq -r '.model // ""')
    thinking=$(echo "$config" | jq -r '.thinking // ""')

    cmd="/subagents spawn $label \"$task\""
    if [[ -n "$model" && "$model" != "null" ]]; then
        cmd+=" --model $model"
    fi
    if [[ -n "$thinking" && "$thinking" != "null" ]]; then
        cmd+=" --thinking $thinking"
    fi

    echo ""
    echo "💬 Slash Command:"
    echo "=================================================="
    echo "$cmd"
    echo "=================================================="
}

# Hauptprogramm
main() {
    local task=""
    local label=""
    local model=""
    local thinking=""
    local timeout="900"
    local thread="false"
    local mode="run"
    local output="tool"

    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --task|-t)
                task="$2"
                shift 2
                ;;
            --label|-l)
                label="$2"
                shift 2
                ;;
            --model|-m)
                model="$2"
                shift 2
                ;;
            --thinking)
                thinking="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --thread)
                thread="true"
                shift
                ;;
            --mode)
                mode="$2"
                shift 2
                ;;
            --output|-o)
                output="$2"
                shift 2
                ;;
            -h|--help)
                echo "Sub-Agent Spawn Helper"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --task, -t TASK         Aufgabenbeschreibung"
                echo "  --label, -l LABEL       Optionaler Label"
                echo "  --model, -m MODEL       KI-Modell (${MODELS[*]})"
                echo "  --thinking LEVEL        Thinking Level (low, medium, high)"
                echo "  --timeout SECONDS       Timeout in Sekunden (default: 900)"
                echo "  --thread                Thread-Binding aktivieren"
                echo "  --mode MODE             Run mode (run, session)"
                echo "  --output, -o FORMAT     Output format (tool, slash, json)"
                echo ""
                echo "Examples:"
                echo "  $0 -t \"Analyze logs\""
                echo "  $0 -t \"Code review\" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800"
                echo "  $0 -t \"Batch process\" -l \"batch-worker\" --thread"
                exit 0
                ;;
            *)
                echo "Unbekannte Option: $1" >&2
                exit 1
                ;;
        esac
    done

    # Task ist erforderlich
    if [[ -z "$task" ]]; then
        echo "Fehler: --task/-t ist erforderlich" >&2
        exit 1
    fi

    # Überprüfe ob das angegebene Modell gültig ist
    if [[ -n "$model" ]] && ! contains_element "$model" "${MODELS[@]}"; then
        echo "Ungültiges Modell: $model" >&2
        echo "Verfügbare Modelle: ${MODELS[*]}" >&2
        exit 1
    fi

    # Erstelle Konfiguration
    local config
    config=$(get_spawn_config "$task" "$label" "$model" "$thinking" "$timeout" "$thread" "$mode")

    echo "✅ Sub-Agent Konfiguration:"
    echo "$config" | jq .

    case "$output" in
        tool)
            print_spawn_command "$config"
            ;;
        slash)
            print_slash_command "$config"
            ;;
        json)
            echo ""
            echo "📄 JSON:"
            echo "$config"
            
            # Speichere als Datei
            local label_safe="${label:-spawn}"
            label_safe=${label_safe//[^a-zA-Z0-9_-]/_}
            local output_file="/tmp/subagent_${label_safe}.json"
            echo "$config" > "$output_file"
            echo "💾 Gespeichert: $output_file"
            ;;
        *)
            echo "Unbekanntes Ausgabeformat: $output" >&2
            exit 1
            ;;
    esac
}

main "$@"
