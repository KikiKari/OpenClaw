#!/usr/bin/env bash
# spawn_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sub-Agent spawner - Einfache CLI für sessions_spawn

# Lade Modellkonfiguration
load_models() {
    local config_path="${OPENCLAW_CONFIG:-/home/openclaw/.openclaw/openclaw.json}"
    local config_content
    local model_config
    local primary_model
    local fallback_models
    local -a candidates=()
    local -a unique_models=()
    local -A seen_models=()
    
    if [[ ! -f "$config_path" ]]; then
        echo "Fehler: Konfigurationsdatei nicht gefunden: $config_path" >&2
        exit 1
    fi
    
    config_content=$(cat "$config_path")
    
    # Extrahiere primary model
    primary_model=$(echo "$config_content" | jq -r '.agents.defaults.model.primary // empty' 2>/dev/null) || {
        echo "Fehler: Modellkonfiguration kann nicht geladen werden: $config_path" >&2
        exit 1
    }
    
    if [[ -n "$primary_model" ]]; then
        candidates+=("$primary_model")
    fi
    
    # Extrahiere fallback models
    while IFS= read -r model; do
        if [[ -n "$model" ]]; then
            candidates+=("$model")
        fi
    done < <(echo "$config_content" | jq -r '.agents.defaults.model.fallbacks[]? // empty' 2>/dev/null)
    
    # Filtere ungültige und doppelte Models
    for model in "${candidates[@]}"; do
        if [[ -n "$model" && "$model" != anthropic/* ]] && [[ -z "${seen_models[$model]:-}" ]]; then
            seen_models["$model"]=1
            unique_models+=("$model")
        fi
    done
    
    if [[ ${#unique_models[@]} -eq 0 ]]; then
        echo "Fehler: Keine allgemein verfügbaren Modelle in $config_path" >&2
        exit 1
    fi
    
    printf '%s\n' "${unique_models[@]}"
}

# Globale Variable für verfügbare Models
readarray -t MODELS < <(load_models)

# Hilfsfunktion zur Validierung ob ein Model gültig ist
is_valid_model() {
    local model="$1"
    for m in "${MODELS[@]}"; do
        if [[ "$m" == "$model" ]]; then
            return 0
        fi
    done
    return 1
}

# Erstellt Konfiguration für sessions_spawn
get_spawn_config() {
    local task="$1"
    local label="$2"
    local model="$3"
    local thinking="$4"
    local timeout="$5"
    local thread="$6"
    local mode="$7"
    
    local -A config=()
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
    
    if [[ "$thread" == "true" ]]; then
        config[thread]="true"
        if [[ "$mode" == "run" ]]; then
            config[mode]="session"  # thread requires session mode
        fi
    else
        config[mode]="$mode"
    fi
    
    # Konvertiere Array zu JSON
    local json="{"
    local first=true
    for key in "${!config[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            json+=", "
        fi
        if [[ "${config[$key]}" =~ ^[0-9]+$ ]]; then
            json+="\"$key\": ${config[$key]}"
        else
            json+="\"$key\": \"${config[$key]}\""
        fi
    done
    json+="}"
    
    echo "$json"
}

# Gibt das equivalente Tool-Kommando aus
print_spawn_command() {
    local config="$1"
    
    echo
    echo "🛠️  Tool-Aufruf:"
    echo "=================================================="
    echo "sessions_spawn("
    
    # Parse JSON und gib jedes Feld aus
    local keys
    keys=$(echo "$config" | jq -r 'keys[]' 2>/dev/null)
    
    while IFS= read -r key; do
        if [[ -n "$key" ]]; then
            local value
            value=$(echo "$config" | jq -r ".\"$key\"" 2>/dev/null)
            if [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
                echo "    $key=$value"
            else
                echo "    $key=\"$value\""
            fi
        fi
    done <<< "$keys"
    
    echo ")"
    echo "=================================================="
}

# Gibt das equivalente Slash-Kommando aus
print_slash_command() {
    local config="$1"
    
    local task
    local label
    local model
    local thinking
    
    task=$(echo "$config" | jq -r '.task // ""' 2>/dev/null)
    label=$(echo "$config" | jq -r '.label // "agent"' 2>/dev/null)
    model=$(echo "$config" | jq -r '.model // ""' 2>/dev/null)
    thinking=$(echo "$config" | jq -r '.thinking // ""' 2>/dev/null)
    
    local cmd="/subagents spawn $label \"$task\""
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
    local thread="false"
    local mode="run"
    local output="tool"
    
    # Hilfe anzeigen
    show_help() {
        cat << EOF
Sub-Agent Spawn Helper

Optionen:
  -t, --task TASK           Aufgabenbeschreibung (erforderlich)
  -l, --label LABEL         Optionaler Label
  -m, --model MODEL         KI-Modell (${MODELS[*]})
      --thinking LEVEL      Thinking Level (low, medium, high)
      --timeout SECONDS     Timeout in Sekunden (Standard: 900)
      --thread              Thread-Binding aktivieren
      --mode MODE           Run mode (run, session) (Standard: run)
  -o, --output FORMAT       Output format (tool, slash, json) (Standard: tool)
  -h, --help                Diese Hilfe anzeigen

Beispiele:
  $0 -t "Analyze logs" 
  $0 -t "Code review" -m openai/gpt-5.6-sol --timeout 1800
  $0 -t "Batch process" -l "batch-worker" --thread
EOF
    }
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--task)
                task="$2"
                shift 2
                ;;
            -l|--label)
                label="$2"
                shift 2
                ;;
            -m|--model)
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
            -o|--output)
                output="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unbekannte Option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # Task ist erforderlich
    if [[ -z "$task" ]]; then
        echo "Fehler: --task ist erforderlich" >&2
        show_help
        exit 1
    fi
    
    # Validierung des Models
    if [[ -n "$model" ]] && ! is_valid_model "$model"; then
        echo "Fehler: Ungültiges Model '$model'. Gültige Models sind: ${MODELS[*]}" >&2
        exit 1
    fi
    
    # Validierung von thinking
    if [[ -n "$thinking" ]] && [[ ! "$thinking" =~ ^(low|medium|high)$ ]]; then
        echo "Fehler: Ungültiger thinking Wert '$thinking'. Gültige Werte sind: low, medium, high" >&2
        exit 1
    fi
    
    # Validierung von mode
    if [[ ! "$mode" =~ ^(run|session)$ ]]; then
        echo "Fehler: Ungültiger mode Wert '$mode'. Gültige Werte sind: run, session" >&2
        exit 1
    fi
    
    # Validierung von output
    if [[ ! "$output" =~ ^(tool|slash|json)$ ]]; then
        echo "Fehler: Ungültiger output Wert '$output'. Gültige Werte sind: tool, slash, json" >&2
        exit 1
    fi
    
    # Konfiguration erstellen
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
            echo
            echo "📄 JSON:"
            echo "$config" | jq .
            
            # Speichere als Datei
            local safe_label
            safe_label=$(echo "${label:-spawn}" | sed 's/[^a-zA-Z0-9_-]/_/g')
            local output_file="/tmp/subagent_${safe_label}.json"
            echo "$config" | jq . > "$output_file"
            echo "💾 Gespeichert: $output_file"
            ;;
    esac
}

# Skript ausführen
main "$@"
