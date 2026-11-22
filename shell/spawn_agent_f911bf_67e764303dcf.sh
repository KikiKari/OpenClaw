#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "a2f77b7bdfcfeb5715b32529bbb62fa380284e98261c51befcf8c2f08f79d962", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "shell"}
# spawn_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sub-Agent spawner - Einfache CLI für sessions_spawn

WORKSPACE="/home/openclaw/.openclaw/workspace"

# Füge WORKSPACE zum PYTHONPATH hinzu, falls noch nicht vorhanden
if [[ ":$PYTHONPATH:" != *":$WORKSPACE:"* ]]; then
    export PYTHONPATH="$WORKSPACE:$PYTHONPATH"
fi

# Lade verfügbare Modelle über Python
readarray -t MODELS < <(python3 -c "
import sys
sys.path.insert(0, '$WORKSPACE')
try:
    from openclaw_models import configured_models
    models = configured_models()
    for model in models:
        print(model)
except Exception as e:
    print(f'Modellkonfiguration kann nicht geladen werden: {e}', file=sys.stderr)
    sys.exit(1)
")

# Hilfsfunktion zur Überprüfung, ob ein Modell gültig ist
is_valid_model() {
    local model="$1"
    for m in "${MODELS[@]}"; do
        [[ "$m" == "$model" ]] && return 0
    done
    return 1
}

# Funktion zur Erstellung der Konfiguration
get_spawn_config() {
    local task="$1"
    local label="$2"
    local model="$3"
    local thinking="$4"
    local timeout="$5"
    local thread="$6"
    local mode="$7"
    
    local config="{\"task\":\"$task\""
    
    if [[ -n "$label" ]]; then
        config="$config,\"label\":\"$label\""
    fi
    
    if [[ -n "$model" ]] && is_valid_model "$model"; then
        config="$config,\"model\":\"$model\""
    fi
    
    if [[ -n "$thinking" ]]; then
        config="$config,\"thinking\":\"$thinking\""
    fi
    
    if [[ -n "$timeout" ]]; then
        config="$config,\"runTimeoutSeconds\":$timeout"
    fi
    
    if [[ "$thread" == "true" ]]; then
        config="$config,\"thread\":true"
        if [[ "$mode" == "run" ]]; then
            mode="session"
        fi
    fi
    
    config="$config,\"mode\":\"$mode\"}"
    echo "$config"
}

# Funktion zur Ausgabe des Tool-Kommandos
print_spawn_command() {
    local config="$1"
    
    echo ""
    echo "🛠️  Tool-Aufruf:"
    echo "=================================================="
    echo "sessions_spawn("
    
    # Parse JSON und gib Key-Value-Paare aus
    python3 -c "
import json
config = json.loads('$config')
for key, value in config.items():
    if isinstance(value, str):
        print(f'    {key}=\"{value}\"')
    else:
        print(f'    {key}={value}')
"
    
    echo ")"
    echo "=================================================="
}

# Funktion zur Ausgabe des Slash-Kommandos
print_slash_command() {
    local config="$1"
    
    # Extrahiere Werte aus dem JSON
    local task label model thinking
    task=$(echo "$config" | python3 -c "import sys, json; print(json.load(sys.stdin).get('task', ''))")
    label=$(echo "$config" | python3 -c "import sys, json; print(json.load(sys.stdin).get('label', 'agent'))")
    model=$(echo "$config" | python3 -c "import sys, json; print(json.load(sys.stdin).get('model', ''))")
    thinking=$(echo "$config" | python3 -c "import sys, json; print(json.load(sys.stdin).get('thinking', ''))")
    
    local cmd="/subagents spawn $label \"$task\""
    if [[ -n "$model" ]]; then
        cmd="$cmd --model $model"
    fi
    if [[ -n "$thinking" ]]; then
        cmd="$cmd --thinking $thinking"
    fi
    
    echo ""
    echo "💬 Slash Command:"
    echo "=================================================="
    echo "$cmd"
    echo "=================================================="
}

# Hauptfunktion
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
            --help)
                echo "Sub-Agent Spawn Helper"
                echo ""
                echo "Optionale Argumente:"
                echo "  --task TASK, -t TASK          Aufgabenbeschreibung"
                echo "  --label LABEL, -l LABEL       Optionaler Label"
                echo "  --model MODEL, -m MODEL       KI-Modell (${MODELS[*]})"
                echo "  --thinking {low,medium,high}  Thinking Level"
                echo "  --timeout TIMEOUT             Timeout in Sekunden (default: 900)"
                echo "  --thread                      Thread-Binding aktivieren"
                echo "  --mode {run,session}          Run mode"
                echo "  --output {tool,slash,json}, -o {tool,slash,json}"
                echo "                                Output format"
                echo ""
                echo "Beispiele:"
                echo "  $0 -t \"Analyze logs\""
                echo "  $0 -t \"Code review\" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800"
                echo "  $0 -t \"Batch process\" -l \"batch-worker\" --thread"
                exit 0
                ;;
            *)
                echo "Unbekanntes Argument: $1" >&2
                exit 1
                ;;
        esac
    done
    
    # Prüfe ob task angegeben wurde
    if [[ -z "$task" ]]; then
        echo "Fehler: --task ist erforderlich." >&2
        exit 1
    fi
    
    # Erstelle Konfiguration
    local config
    config=$(get_spawn_config "$task" "$label" "$model" "$thinking" "$timeout" "$thread" "$mode")
    
    echo "✅ Sub-Agent Konfiguration:"
    echo "$config" | python3 -m json.tool
    
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
            label_safe=${label_safe//\//-}  # Ersetze Schrägstriche durch Bindestriche
            local output_file="/tmp/subagent_$label_safe.json"
            echo "$config" > "$output_file"
            echo "💾 Gespeichert: $output_file"
            ;;
        *)
            echo "Unbekanntes Output-Format: $output" >&2
            exit 1
            ;;
    esac
}

# Starte das Skript
main "$@"
