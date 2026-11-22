#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "1fd5512eb99150bb24d3d8b407dc34d310af7bc31306d384be05db47599abf5b", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "shell"}
# spawn_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sub-Agent spawner - Einfache CLI für sessions_spawn

# Funktion zum Laden der Modelle aus der Konfigurationsdatei
load_models() {
    local config_path="${OPENCLAW_CONFIG:-/home/openclaw/.openclaw/openclaw.json}"
    local models_json
    local primary_model
    local fallback_models
    local model_list=()

    # Versuche, die Konfigurationsdatei zu lesen und JSON zu parsen
    if [[ ! -r "$config_path" ]]; then
        echo "Fehler: Konfigurationsdatei nicht lesbar: $config_path" >&2
        return 1
    fi

    # Extrahiere primary und fallback Models
    primary_model=$(jq -er '.agents.defaults.model.primary // empty' "$config_path" 2>/dev/null || echo "")
    fallback_models=$(jq -er '.agents.defaults.model.fallbacks[] // empty' "$config_path" 2>/dev/null || echo "")

    # Füge primary Model hinzu, falls es nicht anthropic/ ist
    if [[ -n "$primary_model" && "$primary_model" != anthropic/* ]]; then
        model_list+=("$primary_model")
    fi

    # Füge fallback Models hinzu, falls sie nicht anthropic/ sind
    while IFS= read -r model; do
        if [[ -n "$model" && "$model" != anthropic/* ]]; then
            # Prüfe ob Model bereits in Liste ist (deduplizieren)
            local is_duplicate=false
            for existing in "${model_list[@]}"; do
                if [[ "$existing" == "$model" ]]; then
                    is_duplicate=true
                    break
                fi
            done
            if [[ "$is_duplicate" == false ]]; then
                model_list+=("$model")
            fi
        fi
    done < <(echo "$fallback_models")

    # Prüfe ob mindestens ein gültiges Modell gefunden wurde
    if [[ ${#model_list[@]} -eq 0 ]]; then
        echo "Fehler: Keine allgemein verfügbaren Modelle in $config_path" >&2
        return 1
    fi

    # Gebe Modelle zeilenweise aus
    printf '%s\n' "${model_list[@]}"
}

# Lade Modelle in ein Array
readarray -t MODELS < <(load_models)

# Hilfsfunktion zur Validierung von Modellen
is_valid_model() {
    local model="$1"
    for m in "${MODELS[@]}"; do
        if [[ "$m" == "$model" ]]; then
            return 0
        fi
    done
    return 1
}

# Funktion zur Erstellung der Spawn-Konfiguration
get_spawn_config() {
    local task="$1"
    local label="${2:-}"
    local model="${3:-}"
    local thinking="${4:-}"
    local timeout="${5:-}"
    local thread="${6:-false}"
    local mode="${7:-run}"

    # Erstelle assoziatives Array für die Konfiguration
    declare -A config
    config[task]="$task"

    if [[ -n "$label" ]]; then
        config[label]="$label"
    fi

    if [[ -n "$model" ]] && is_valid_model "$model"; then
        config[model]="$model"
    fi

    if [[ -n "$thinking" ]]; then
        config[thinking]="$thinking"
    fi

    if [[ -n "$timeout" ]]; then
        config[runTimeoutSeconds]="$timeout"
    fi

    if [[ "$thread" == true ]]; then
        config[thread]="true"
        if [[ "$mode" == "run" ]]; then
            config[mode]="session"  # thread benötigt session mode
        else
            config[mode]="$mode"
        fi
    else
        config[mode]="$mode"
    fi

    # Gebe Konfiguration als JSON aus
    echo "{"
    local first=true
    for key in "${!config[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo ","
        fi
        if [[ "${config[$key]}" =~ ^[0-9]+$ ]] || [[ "${config[$key]}" == "true" ]] || [[ "${config[$key]}" == "false" ]]; then
            echo -n "\"$key\": ${config[$key]}"
        else
            echo -n "\"$key\": \"${config[$key]}\""
        fi
    done
    echo
    echo "}"
}

# Funktion zur Ausgabe des equivalenten Tool-Kommandos
print_spawn_command() {
    local config_json="$1"
    echo
    echo "🛠️  Tool-Aufruf:"
    echo "=================================================="
    echo "sessions_spawn("
    
    # Parse JSON und gebe Key-Value-Paare aus
    echo "$config_json" | jq -r 'to_entries[] | "\(.key)=\(.value | if type == "string" then "\"\(.value)\"" else .value end)"' | \
    sed 's/^/    /'
    
    echo ")"
    echo "=================================================="
}

# Funktion zur Ausgabe des equivalenten Slash-Kommandos
print_slash_command() {
    local config_json="$1"
    local task label model thinking cmd

    task=$(echo "$config_json" | jq -r '.task // ""')
    label=$(echo "$config_json" | jq -r '.label // "agent"')
    model=$(echo "$config_json" | jq -r '.model // ""')
    thinking=$(echo "$config_json" | jq -r '.thinking // ""')

    cmd="/subagents spawn $label \"$task\""
    if [[ -n "$model" ]]; then
        cmd+=" --model $model"
    fi
    if [[ -n "$thinking" ]]; then
        cmd+=" --thinking $thinking"
    fi

    echo
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
    local thread=false
    local mode="run"
    local output="tool"
    local help=false

    # Parse Kommandozeilenargumente
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
                thread=true
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
            --help|-h)
                help=true
                shift
                ;;
            *)
                echo "Unbekanntes Argument: $1" >&2
                exit 1
                ;;
        esac
    done

    # Zeige Hilfe wenn angefordert
    if [[ "$help" == true ]]; then
        cat <<EOF
Sub-Agent Spawn Helper

Optionale Argumente:
  --task TASK, -t TASK     Aufgabenbeschreibung
  --label LABEL, -l LABEL Optionaler Label
  --model MODEL, -m MODEL  KI-Modell (${MODELS[*]})
  --thinking {low,medium,high}
                           Thinking Level
  --timeout TIMEOUT        Timeout in Sekunden (default: 900)
  --thread                 Thread-Binding aktivieren
  --mode {run,session}     Run mode
  --output {tool,slash,json}, -o {tool,slash,json}
                           Output format
  --help, -h               Diese Hilfe anzeigen

Beispiele:
  $0 -t "Analyze logs" 
  $0 -t "Code review" -m openai/gpt-5.6-sol --timeout 1800
  $0 -t "Batch process" -l "batch-worker" --thread
EOF
        exit 0
    fi

    # Prüfe ob Task angegeben wurde
    if [[ -z "$task" ]]; then
        echo "Fehler: --task/-t ist erforderlich" >&2
        exit 1
    fi

    # Prüfe ob Model gültig ist
    if [[ -n "$model" ]] && ! is_valid_model "$model"; then
        echo "Fehler: Ungültiges Modell: $model" >&2
        echo "Verfügbare Modelle: ${MODELS[*]}" >&2
        exit 1
    fi

    # Erstelle Konfiguration
    local config_json
    config_json=$(get_spawn_config "$task" "$label" "$model" "$thinking" "$timeout" "$thread" "$mode")

    echo "✅ Sub-Agent Konfiguration:"
    echo "$config_json" | jq '.'

    # Gebe entsprechend dem gewünschten Format aus
    case "$output" in
        tool)
            print_spawn_command "$config_json"
            ;;
        slash)
            print_slash_command "$config_json"
            ;;
        json)
            echo
            echo "📄 JSON:"
            echo "$config_json"
            
            # Speichere als Datei
            local output_file="/tmp/subagent_${label:-spawn}.json"
            echo "$config_json" > "$output_file"
            echo "💾 Gespeichert: $output_file"
            ;;
        *)
            echo "Fehler: Unbekanntes Output-Format: $output" >&2
            exit 1
            ;;
    esac
}

# Starte Hauptprogramm
main "$@"
