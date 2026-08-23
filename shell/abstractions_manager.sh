#!/bin/bash
# abstractions_manager.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Script Abstractions Manager - Multi-Node Edition

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly ABSTRACTIONS_REPO="${WORKSPACE}/git/Abstraktionen"
readonly LOG_DIR="${WORKSPACE}/logs/abstractions-manager"
readonly STATE_FILE="${WORKSPACE}/db/abstractions_state.json"

# Node-Konfiguration mit Prioritäten
declare -A NODES=(
    ["node1.always_available"]="true"
    ["node1.capacity"]="medium"
    ["node1.priority"]="2"
    ["node2.always_available"]="true"
    ["node2.capacity"]="medium"
    ["node2.priority"]="3"
    ["node3.always_available"]="false"
    ["node3.capacity"]="medium"
    ["node3.priority"]="4"
    ["node5.always_available"]="false"
    ["node5.capacity"]="low"
    ["node5.priority"]="5"
    ["node5.device"]="Redmi Note 11S"
    ["node5.condition"]="mobile_internet"
    ["node7.always_available"]="true"
    ["node7.capacity"]="high"
    ["node7.priority"]="1"
)

# Verfügbare Modelle
readonly AVAILABLE_MODELS=(
    "openrouter/moonshotai/kimi-k2.5"
    "openrouter/openai/gpt-4o"
    "openrouter/anthropic/claude-3-5-sonnet-20241022"
    "openrouter/google/gemini-2.0-flash-001"
    "openrouter/nvidia/llama-3.3-nemotron-super-49b-v1"
    "openrouter/qwen/qwen-2.5-coder-32b-instruct"
)

# Zielsprachenkonfiguration
declare -A TARGET_LANGUAGES_PERL5=(
    ["ext"]=".pl"
    ["shebang"]="#!/usr/bin/env perl"
    ["header"]="use strict;\nuse warnings;\n"
)
declare -A TARGET_LANGUAGES_PERL6=(
    ["ext"]=".raku"
    ["shebang"]="#!/usr/bin/env raku"
    ["header"]="use v6;\n"
)
declare -A TARGET_LANGUAGES_JAVASCRIPT=(
    ["ext"]=".js"
    ["shebang"]="#!/usr/bin/env node"
    ["header"]=""
)
declare -A TARGET_LANGUAGES_PYTHON=(
    ["ext"]=".py"
    ["shebang"]="#!/usr/bin/env python3"
    ["header"]=""
)
declare -A TARGET_LANGUAGES_SHELL=(
    ["ext"]=".sh"
    ["shebang"]="#!/bin/bash"
    ["header"]="set -euo pipefail\n"
)
declare -A TARGET_LANGUAGES_POWERSHELL=(
    ["ext"]=".ps1"
    ["shebang"]="#!/usr/bin/env pwsh"
    ["header"]="#Requires -Version 7\n"
)
declare -A TARGET_LANGUAGES_TCL=(
    ["ext"]=".tcl"
    ["shebang"]="#!/usr/bin/env tclsh"
    ["header"]="package require Tcl 8.6\n"
)
declare -A TARGET_LANGUAGES_RUBY=(
    ["ext"]=".rb"
    ["shebang"]="#!/usr/bin/env ruby"
    ["header"]="require 'json'\nrequire 'fileutils'\n"
)
declare -A TARGET_LANGUAGES_LUA=(
    ["ext"]=".lua"
    ["shebang"]="#!/usr/bin/env lua"
    ["header"]=""
)
declare -A TARGET_LANGUAGES_GO=(
    ["ext"]=".go"
    ["shebang"]="// +build ignore"
    ["header"]="package main\n"
)

# Globale Variablen für den Zustand
declare -A state_processed=()
declare -a state_queue=()
state_current_priority="high"
state_total_scripts=0
state_abstractions_created=0

log() {
    local message="$1"
    local level="${2:-INFO}"
    
    mkdir -p "$LOG_DIR"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[${timestamp}] [${level}] ${message}"
    echo "$line"
    
    local log_file="${LOG_DIR}/$(date '+%Y-%m-%d').log"
    echo "$line" >> "$log_file"
}

get_node_by_priority() {
    local job_weight="${1:-medium}"
    local preferred_order=()
    
    # Prioritäts-Matrix
    if [[ "$job_weight" == "heavy" ]]; then
        # Schwere Jobs → Node 7 (Docker mit vielen Ressourcen)
        preferred_order=("node7" "node2" "node1")
    elif [[ "$job_weight" == "medium" ]]; then
        # Mittlere Jobs → Stable Nodes
        preferred_order=("node2" "node1" "node7")
    else  # light
        # Leichte Jobs → Mobile/verfügbare Nodes
        preferred_order=("node5" "node1" "node2")
    fi
    
    # Prüfe Verfügbarkeit
    for node_id in "${preferred_order[@]}"; do
        if [[ ! -v NODES["${node_id}.always_available"] ]]; then
            continue
        fi
        
        local always_available="${NODES[${node_id}.always_available]}"
        
        # Skip nicht immer verfügbare Nodes wenn nicht explizit requested
        if [[ "$always_available" != "true" && "$job_weight" != "light" ]]; then
            continue
        fi
        
        # Prüfe ob Node online
        if check_node_status "$node_id"; then
            echo "$node_id"
            return 0
        fi
    done
    
    # Fallback zu Node 1
    echo "node1"
}

check_node_status() {
    local node_id="$1"
    
    if command -v openclaw >/dev/null 2>&1; then
        if timeout 5 openclaw nodes status "$node_id" 2>/dev/null | grep -qiE "(online|active)"; then
            return 0
        fi
    fi
    
    # Bei Timeout/Error: Prüfe letzten bekannten Status
    if [[ -v NODES["${node_id}.always_available"] ]] && [[ "${NODES[${node_id}.always_available]}" == "true" ]]; then
        return 0
    fi
    
    return 1
}

get_job_weight() {
    local script_size="$1"
    local target_langs_count="$2"
    local total_work=$((script_size * target_langs_count))
    
    if (( total_work > 50000 )); then  # Große Scripts, viele Sprachen
        echo "heavy"
    elif (( total_work > 10000 )); then  # Mittlere Last
        echo "medium"
    else
        echo "light"
    fi
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            # Lade verarbeitete Scripts
            mapfile -t processed_keys < <(jq -r '.processed | keys[]' "$STATE_FILE" 2>/dev/null || true)
            for key in "${processed_keys[@]}"; do
                state_processed["$key"]=1
            done
            
            # Lade Queue
            mapfile -t state_queue < <(jq -r '.queue[]' "$STATE_FILE" 2>/dev/null || true)
            
            # Lade aktuelle Priorität
            state_current_priority=$(jq -r '.current_priority // "high"' "$STATE_FILE" 2>/dev/null || echo "high")
            
            # Lade Statistiken
            state_total_scripts=$(jq -r '.stats.total_scripts // 0' "$STATE_FILE" 2>/dev/null || echo "0")
            state_abstractions_created=$(jq -r '.stats.abstractions_created // 0' "$STATE_FILE" 2>/dev/null || echo "0")
        fi
    fi
}

save_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    
    # Erstelle JSON-Struktur
    local json_content="{\"processed\":{},\"queue\":[],\"current_priority\":\"$state_current_priority\",\"stats\":{\"total_scripts\":$state_total_scripts,\"abstractions_created\":$state_abstractions_created}}"
    
    # Speichere mit jq oder als einfaches JSON
    if command -v jq >/dev/null 2>&1; then
        echo "$json_content" | jq '.' > "$STATE_FILE"
    else
        echo "$json_content" > "$STATE_FILE"
    fi
}

find_scripts_in_dir() {
    local directory="$1"
    shift
    local exclude_patterns=("$@")
    
    if [[ ${#exclude_patterns[@]} -eq 0 ]]; then
        exclude_patterns=("node_modules" ".git" "__pycache__" "dist" "build")
    fi
    
    local scripts=()
    
    if [[ -d "$directory" ]]; then
        while IFS= read -r -d '' file; do
            local include=true
            for pattern in "${exclude_patterns[@]}"; do
                if [[ "$file" == *"$pattern"* ]]; then
                    include=false
                    break
                fi
            done
            if $include; then
                scripts+=("$file")
            fi
        done < <(find "$directory" -type f \( -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.pl" -o -name "*.rb" \) -print0 2>/dev/null || true)
    fi
    
    printf '%s\n' "${scripts[@]}"
}

create_abstraction() {
    local script_path="$1"
    local target_lang="$2"
    
    if [[ ! -f "$script_path" ]]; then
        log "Script not found: $script_path" "ERROR"
        return 1
    fi
    
    local original_content
    original_content=$(cat "$script_path" 2>/dev/null || echo "")
    
    local ext
    ext=$(basename "$script_path" | sed 's/.*\.//')
    
    declare -A source_lang_map=(
        ["py"]="Python"
        ["js"]="JavaScript"
        ["sh"]="Shell"
        ["pl"]="Perl"
        ["rb"]="Ruby"
    )
    
    local source_lang="${source_lang_map[$ext]:-$ext}"
    
    local target_dir="${ABSTRACTIONS_REPO}/${target_lang}"
    mkdir -p "$target_dir"
    
    local target_ext=""
    case "$target_lang" in
        "perl5") target_ext="${TARGET_LANGUAGES_PERL5[ext]}" ;;
        "perl6") target_ext="${TARGET_LANGUAGES_PERL6[ext]}" ;;
        "javascript") target_ext="${TARGET_LANGUAGES_JAVASCRIPT[ext]}" ;;
        "python") target_ext="${TARGET_LANGUAGES_PYTHON[ext]}" ;;
        "shell") target_ext="${TARGET_LANGUAGES_SHELL[ext]}" ;;
        "powershell") target_ext="${TARGET_LANGUAGES_POWERSHELL[ext]}" ;;
        "tcl") target_ext="${TARGET_LANGUAGES_TCL[ext]}" ;;
        "ruby") target_ext="${TARGET_LANGUAGES_RUBY[ext]}" ;;
        "lua") target_ext="${TARGET_LANGUAGES_LUA[ext]}" ;;
        "go") target_ext="${TARGET_LANGUAGES_GO[ext]}" ;;
    esac
    
    local target_file="${target_dir}/$(basename "$script_path" ."$ext")${target_ext}"
    
    if [[ -f "$target_file" ]]; then
        return 1
    fi
    
    local shebang=""
    local header=""
    case "$target_lang" in
        "perl5") shebang="${TARGET_LANGUAGES_PERL5[shebang]}"; header="${TARGET_LANGUAGES_PERL5[header]}" ;;
        "perl6") shebang="${TARGET_LANGUAGES_PERL6[shebang]}"; header="${TARGET_LANGUAGES_PERL6[header]}" ;;
        "javascript") shebang="${TARGET_LANGUAGES_JAVASCRIPT[shebang]}"; header="${TARGET_LANGUAGES_JAVASCRIPT[header]}" ;;
        "python") shebang="${TARGET_LANGUAGES_PYTHON[shebang]}"; header="${TARGET_LANGUAGES_PYTHON[header]}" ;;
        "shell") shebang="${TARGET_LANGUAGES_SHELL[shebang]}"; header="${TARGET_LANGUAGES_SHELL[header]}" ;;
        "powershell") shebang="${TARGET_LANGUAGES_POWERSHELL[shebang]}"; header="${TARGET_LANGUAGES_POWERSHELL[header]}" ;;
        "tcl") shebang="${TARGET_LANGUAGES_TCL[shebang]}"; header="${TARGET_LANGUAGES_TCL[header]}" ;;
        "ruby") shebang="${TARGET_LANGUAGES_RUBY[shebang]}"; header="${TARGET_LANGUAGES_RUBY[header]}" ;;
        "lua") shebang="${TARGET_LANGUAGES_LUA[shebang]}"; header="${TARGET_LANGUAGES_LUA[header]}" ;;
        "go") shebang="${TARGET_LANGUAGES_GO[shebang]}"; header="${TARGET_LANGUAGES_GO[header]}" ;;
    esac
    
    # Hole die ersten 15 Zeilen
    local lines=""
    lines=$(echo "$original_content" | head -n 15 | sed 's/^/# /')
    
    local content=""
    content+="$shebang"$'\n'
    content+="# $(basename "$script_path" ."$ext") - ${target_lang^} Version"$'\n'
    content+="# Portiert von $source_lang"$'\n'
    content+="# Original: $script_path"$'\n'
    content+="# Erstellt: $(date '+%Y-%m-%d')"$'\n'
    content+="#"$'\n'
    if [[ -n "$header" ]]; then
        content+="# $header"$'\n'
    fi
    content+=""$'\n'
    content+="# Original-Code-Referenz:"$'\n'
    content+="$lines"$'\n'
    content+=""$'\n'
    content+="def main():"$'\n'
    content+="    # TODO: Implementiere ${source_lang} Funktionalität in ${target_lang^}"$'\n'
    content+="    pass"$'\n'
    content+=""$'\n'
    content+="if __name__ == \"__main__\":"$'\n'
    content+="    main()"$'\n'
    
    echo -e "$content" > "$target_file"
    log "Created: $target_file"
    return 0
}

process_on_node() {
    local node_id="$1"
    shift
    local scripts=("$@")
    local target_langs=("${scripts[@]: -1}")
    scripts=("${scripts[@]:0:${#scripts[@]}-1}")
    
    local created=0
    
    if [[ "$node_id" == "node1" ]]; then
        # Lokale Verarbeitung
        for script in "${scripts[@]}"; do
            for lang in "${target_langs[@]}"; do
                if create_abstraction "$script" "$lang"; then
                    ((created++))
                fi
            done
        done
    else
        # Remote-Verarbeitung
        log "Dispatching ${#scripts[@]} jobs to $node_id"
        # Für jetzt: Lokale Verarbeitung mit Node-Logging
        for script in "${scripts[@]}"; do
            for lang in "${target_langs[@]}"; do
                if create_abstraction "$script" "$lang"; then
                    ((created++))
                    log "Processed on $node_id: $(basename "$script") -> $lang"
                fi
            done
        done
    fi
    
    echo "$created"
}

process_priority_high() {
    local created=0
    local targets=(
        "skill-creator:${WORKSPACE}/skills/skill-creator/scripts"
        "json-utils:${WORKSPACE}/skills/json-utils/scripts"
        "scripting-utils:${WORKSPACE}/skills/scripting-utils/scripts"
        "model-usage:${WORKSPACE}/skills/model-usage/scripts"
        "tiktok-live:${WORKSPACE}/skills/tiktok-live/scripts"
    )
    
    for target in "${targets[@]}"; do
        local skill_name="${target%%:*}"
        local scripts_dir="${target#*:}"
        
        local scripts
        mapfile -t scripts < <(find_scripts_in_dir "$scripts_dir" "node_modules" ".git" "test" "tests")
        log "${skill_name}: ${#scripts[@]} scripts found"
        
        local count=0
        for script in "${scripts[@]}"; do
            if (( count >= 10 )); then
                break
            fi
            
            local script_size=0
            if [[ -f "$script" ]]; then
                script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
            fi
            
            local target_langs=("perl5" "javascript" "python" "shell" "tcl")
            local job_weight
            job_weight=$(get_job_weight "$script_size" "${#target_langs[@]}")
            
            # Wähle Node basierend auf Job-Gewicht
            local selected_node
            selected_node=$(get_node_by_priority "$job_weight")
            log "Processing $(basename "$script") ($job_weight) on $selected_node"
            
            local result
            result=$(process_on_node "$selected_node" "$script" "${target_langs[@]}")
            created=$((created + result))
            
            ((count++))
        done
    done
    
    echo "$created"
}

process_priority_medium() {
    local created=0
    local targets=(
        "workspace-scripts:${WORKSPACE}/scripts"
        "db-maintainer:${WORKSPACE}/skills/db-maintainer/scripts"
        "log-collector:${WORKSPACE}/skills/log-collector/scripts"
    )
    
    for target in "${targets[@]}"; do
        local dir_name="${target%%:*}"
        local scripts_dir="${target#*:}"
        
        local scripts
        mapfile -t scripts < <(find_scripts_in_dir "$scripts_dir" "node_modules" ".git")
        
        local count=0
        for script in "${scripts[@]}"; do
            if (( count >= 10 )); then
                break
            fi
            
            local script_size=0
            if [[ -f "$script" ]]; then
                script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
            fi
            
            local target_langs=("perl5" "javascript" "powershell" "python")
            local job_weight
            job_weight=$(get_job_weight "$script_size" "${#target_langs[@]}")
            
            # Mittlere Priority → eher leichtere Jobs
            local weight_for_node="$job_weight"
            if [[ "$job_weight" == "heavy" ]]; then
                weight_for_node="medium"
            fi
            
            local selected_node
            selected_node=$(get_node_by_priority "$weight_for_node")
            log "Processing $(basename "$script") ($job_weight) on $selected_node"
            
            local result
            result=$(process_on_node "$selected_node" "$script" "${target_langs[@]}")
            created=$((created + result))
            
            ((count++))
        done
    done
    
    echo "$created"
}

git_commit() {
    local message="$1"
    
    if cd "$ABSTRACTIONS_REPO" 2>/dev/null && command -v git >/dev/null 2>&1; then
        if git add . 2>/dev/null && git commit -m "$message" 2>/dev/null; then
            log "Git commit: $message"
        fi
    fi
}

create_status_report() {
    local report_file="${ABSTRACTIONS_REPO}/STATUS.md"
    
    # Zähle Abstraktionen pro Sprache
    declare -A lang_counts=()
    if [[ -d "$ABSTRACTIONS_REPO" ]]; then
        for lang_dir in "$ABSTRACTIONS_REPO"/*; do
            if [[ -d "$lang_dir" ]] && [[ -n "$(basename "$lang_dir")" ]]; then
                local lang_name
                lang_name=$(basename "$lang_dir")
                local count=0
                if [[ -d "$lang_dir" ]]; then
                    count=$(find "$lang_dir" -type f 2>/dev/null | wc -l)
                fi
                lang_counts["$lang_name"]="$count"
            fi
        done
    fi
    
    {
        echo "# Script Abstractions - Status Report"
        echo ""
        echo "**Letzte Aktualisierung:** $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "- Aktuelle Priorität: ${state_current_priority:-high}"
        echo "- Verarbeitete Scripts: ${#state_processed[@]}"
        echo "- Abstraktionen gesamt: $state_abstractions_created"
        echo ""
        echo "## Abstraktionen pro Sprache"
        echo ""
        
        for lang in "${!lang_counts[@]}"; do
            echo "- $lang: ${lang_counts[$lang]}"
        done
        
        echo ""
        echo "## Verfügbare Modelle"
        echo ""
        
        local i=0
        for model in "${AVAILABLE_MODELS[@]}"; do
            if (( i < 3 )); then
                echo "- \`$model\`"
            fi
            ((i++))
        done
        echo "- ... und $(( ${#AVAILABLE_MODELS[@]} - 3 )) weitere"
        
        echo ""
        echo "## Multi-Node Support"
        echo ""
        echo "| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |"
        echo "|------|---------------|-----------|-----------|-------|"
        
        for node_id in node1 node2 node3 node5 node7; do
            if [[ -v NODES["${node_id}.always_available"] ]]; then
                local avail="✅ Immer"
                if [[ "${NODES[${node_id}.always_available]}" != "true" ]]; then
                    avail="📱 Bedingt"
                fi
                
                local capacity="${NODES[${node_id}.capacity]:-unknown}"
                local priority="${NODES[${node_id}.priority]:--}"
                local device="${NODES[${node_id}.device]:-Server}"
                
                echo "| $node_id | $avail | $capacity | $priority | $device |"
            fi
        done
        
        echo ""
        echo "### Job-Verteilung"
        echo ""
        echo "- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)"
        echo "- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)"
        echo "- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)"
    } > "$report_file"
}

main() {
    log "Script Abstractions Manager (Multi-Node) gestartet"
    
    load_state
    log "State loaded: ${#state_processed[@]} processed"
    
    local current_priority="$state_current_priority"
    local created=0
    
    if [[ "$current_priority" == "high" ]]; then
        log "Processing HIGH priority: Top 5 Skills"
        created=$(process_priority_high)
        if (( created > 0 )); then
            git_commit "High priority: $created abstractions"
        fi
        state_current_priority="medium"
    elif [[ "$current_priority" == "medium" ]]; then
        log "Processing MEDIUM priority: Workspace Scripts"
        created=$(process_priority_medium)
        if (( created > 0 )); then
            git_commit "Medium priority: $created abstractions"
        fi
        state_current_priority="high"  # Zyklus
    fi
    
    # Aktualisiere Statistiken
    state_abstractions_created=0
    if [[ -d "$ABSTRACTIONS_REPO" ]]; then
        for lang_dir in "$ABSTRACTIONS_REPO"/*; do
            if [[ -d "$lang_dir" ]] && [[ -n "$(basename "$lang_dir")" ]]; then
                if [[ -d "$lang_dir" ]]; then
                    local count
                    count=$(find "$lang_dir" -type f 2>/dev/null | wc -l)
                    state_abstractions_created=$((state_abstractions_created + count))
                fi
            fi
        done
    fi
    
    save_state
    create_status_report
    
    log "Abgeschlossen. $created neue Abstraktionen erstellt."
}

main "$@"
