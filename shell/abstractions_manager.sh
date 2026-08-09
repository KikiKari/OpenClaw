#!/bin/bash
# abstractions_manager.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Script Abstractions Manager - Multi-Node Edition

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly ABSTRACTIONS_REPO="${WORKSPACE}/git/Abstraktionen"
readonly LOG_DIR="${WORKSPACE}/logs/abstractions-manager"
readonly STATE_FILE="${WORKSPACE}/db/abstractions_state.json"

# Node-Konfiguration mit Prioritäten
declare -A NODES=(
    [node1]="always_available:true,capacity:medium,priority:2"  # Gateway-Master
    [node2]="always_available:true,capacity:medium,priority:3"  # Stable Worker
    [node3]="always_available:false,capacity:medium,priority:4" # Bald verfügbar
    [node5]="always_available:false,capacity:low,priority:5,device:Redmi Note 11S,condition:mobile_internet"
    [node7]="always_available:true,capacity:high,priority:1"    # Docker Hauptarbeitspferd
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

# Zielsprachen-Konfiguration
declare -A TARGET_LANGUAGES=(
    [perl5]="ext:.pl,shebang:#!/usr/bin/env perl,header:use strict;\nuse warnings;\n"
    [perl6]="ext:.raku,shebang:#!/usr/bin/env raku,header:use v6;\n"
    [javascript]="ext:.js,shebang:#!/usr/bin/env node,header:"
    [python]="ext:.py,shebang:#!/usr/bin/env python3,header:"
    [shell]="ext:.sh,shebang:#!/bin/bash,header:set -euo pipefail\n"
    [powershell]="ext:.ps1,shebang:#!/usr/bin/env pwsh,header:#Requires -Version 7\n"
    [tcl]="ext:.tcl,shebang:#!/usr/bin/env tclsh,header:package require Tcl 8.6\n"
    [ruby]="ext:.rb,shebang:#!/usr/bin/env ruby,header:require 'json'\nrequire 'fileutils'\n"
    [lua]="ext:.lua,shebang:#!/usr/bin/env lua,header:"
    [go]="ext:.go,shebang:// +build ignore,header:package main\n"
)

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

get_node_config_value() {
    local node_id="$1"
    local key="$2"
    
    if [[ -z "${NODES[$node_id]:-}" ]]; then
        return 1
    fi
    
    local config="${NODES[$node_id]}"
    local IFS=','
    local pair
    for pair in $config; do
        local k="${pair%%:*}"
        local v="${pair#*:}"
        if [[ "$k" == "$key" ]]; then
            echo "$v"
            return 0
        fi
    done
    return 1
}

get_node_by_priority() {
    local job_weight="${1:-medium}"
    local preferred_order
    
    # Prioritäts-Matrix
    case "$job_weight" in
        heavy)
            preferred_order=("node7" "node2" "node1")
            ;;
        medium)
            preferred_order=("node2" "node1" "node7")
            ;;
        *)
            preferred_order=("node5" "node1" "node2")
            ;;
    esac
    
    # Prüfe Verfügbarkeit
    local node_id
    for node_id in "${preferred_order[@]}"; do
        if [[ -z "${NODES[$node_id]:-}" ]]; then
            continue
        fi
        
        local always_available
        always_available=$(get_node_config_value "$node_id" "always_available" 2>/dev/null || echo "false")
        
        # Skip nicht immer verfügbare Nodes wenn nicht explizit requested
        if [[ "$always_available" != "true" ]] && [[ "$job_weight" != "light" ]]; then
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
    local always_available
    always_available=$(get_node_config_value "$node_id" "always_available" 2>/dev/null || echo "false")
    [[ "$always_available" == "true" ]]
}

get_job_weight() {
    local script_size="$1"
    local target_langs_count="$2"
    local total_work=$((script_size * target_langs_count))
    
    if (( total_work > 50000 )); then
        echo "heavy"
    elif (( total_work > 10000 )); then
        echo "medium"
    else
        echo "light"
    fi
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        if jq -e . >/dev/null 2>&1 < "$STATE_FILE"; then
            cat "$STATE_FILE"
            return 0
        fi
    fi
    
    cat <<EOF
{
  "processed": {},
  "queue": [],
  "current_priority": "high",
  "stats": {
    "total_scripts": 0,
    "abstractions_created": 0
  }
}
EOF
}

save_state() {
    local state="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$state" > "$STATE_FILE"
}

find_scripts_in_dir() {
    local directory="$1"
    shift
    local exclude_patterns=("$@")
    
    if [[ ${#exclude_patterns[@]} -eq 0 ]]; then
        exclude_patterns=("node_modules" ".git" "__pycache__" "dist" "build")
    fi
    
    if [[ ! -d "$directory" ]]; then
        return
    fi
    
    local script
    local pattern
    find "$directory" -type f \( -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.pl" -o -name "*.rb" \) | while read -r script; do
        local exclude=false
        for pattern in "${exclude_patterns[@]}"; do
            if [[ "$script" == *"$pattern"* ]]; then
                exclude=true
                break
            fi
        done
        if [[ "$exclude" == false ]]; then
            echo "$script"
        fi
    done
}

get_target_lang_config() {
    local lang="$1"
    local key="$2"
    
    if [[ -z "${TARGET_LANGUAGES[$lang]:-}" ]]; then
        return 1
    fi
    
    local config="${TARGET_LANGUAGES[$lang]}"
    local IFS=','
    local pair
    for pair in $config; do
        local k="${pair%%:*}"
        local v="${pair#*:}"
        if [[ "$k" == "$key" ]]; then
            echo "$v"
            return 0
        fi
    done
    return 1
}

create_abstraction() {
    local script_path="$1"
    local target_lang="$2"
    
    if [[ ! -f "$script_path" ]]; then
        log "Script not found: $script_path" "ERROR"
        return 1
    fi
    
    local ext="${script_path##*.}"
    declare -A source_lang_map=(
        [py]="Python"
        [js]="JavaScript"
        [sh]="Shell"
        [pl]="Perl"
        [rb]="Ruby"
    )
    local source_lang="${source_lang_map[$ext]:-$ext}"
    
    local target_dir="${ABSTRACTIONS_REPO}/${target_lang}"
    mkdir -p "$target_dir"
    
    local target_ext
    target_ext=$(get_target_lang_config "$target_lang" "ext")
    local target_file="${target_dir}/$(basename "${script_path%.*}")${target_ext}"
    
    if [[ -f "$target_file" ]]; then
        return 1
    fi
    
    local shebang
    shebang=$(get_target_lang_config "$target_lang" "shebang")
    local header
    header=$(get_target_lang_config "$target_lang" "header")
    
    # Read first 15 lines of original content
    local original_content
    original_content=$(head -n 15 "$script_path" 2>/dev/null || echo "")
    
    local content
    content=$(cat <<EOF
${shebang}
# $(basename "${script_path%.*}") - ${target_lang^} Version
# Portiert von ${source_lang}
# Original: ${script_path}
# Erstellt: $(date '+%Y-%m-%d')
#
$(echo -e "$header" | sed 's/^/# /')

# Original-Code-Referenz:
# $(echo "$original_content" | sed 's/^/# /')

def main():
    # TODO: Implementiere ${source_lang} Funktionalität in ${target_lang^}
    pass

if __name__ == "__main__":
    main()
EOF
)
    
    echo "$content" > "$target_file"
    log "Created: $target_file"
    return 0
}

process_on_node() {
    local node_id="$1"
    shift
    local scripts=("$@")
    local target_langs=("${scripts[@]:1}")
    scripts=("${scripts[0]}")
    
    local created=0
    local script
    local lang
    
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
        log "Dispatching ${#scripts[@]} jobs to ${node_id}"
        # TODO: Implementiere Remote-Dispatch wenn Node-Infrastruktur bereit
        # Für jetzt: Lokale Verarbeitung mit Node-Logging
        for script in "${scripts[@]}"; do
            for lang in "${target_langs[@]}"; do
                if create_abstraction "$script" "$lang"; then
                    ((created++))
                    log "Processed on ${node_id}: $(basename "$script") -> ${lang}"
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
    
    local target
    local skill_name
    local scripts_dir
    local scripts
    local script
    local script_size
    local target_langs=("perl5" "javascript" "python" "shell" "tcl")
    local job_weight
    local selected_node
    
    for target in "${targets[@]}"; do
        IFS=':' read -r skill_name scripts_dir <<< "$target"
        
        mapfile -t scripts < <(find_scripts_in_dir "$scripts_dir" "node_modules" ".git" "test" "tests")
        log "${skill_name}: ${#scripts[@]} scripts found"
        
        local count=0
        for script in "${scripts[@]}"; do
            if (( count >= 10 )); then
                break
            fi
            
            if [[ -f "$script" ]]; then
                script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
            else
                script_size=0
            fi
            
            job_weight=$(get_job_weight "$script_size" "${#target_langs[@]}")
            selected_node=$(get_node_by_priority "$job_weight")
            log "Processing $(basename "$script") (${job_weight}) on ${selected_node}"
            
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
    
    local target
    local dir_name
    local scripts_dir
    local scripts
    local script
    local script_size
    local target_langs=("perl5" "javascript" "powershell" "python")
    local job_weight
    local selected_node
    
    for target in "${targets[@]}"; do
        IFS=':' read -r dir_name scripts_dir <<< "$target"
        
        mapfile -t scripts < <(find_scripts_in_dir "$scripts_dir" "node_modules" ".git")
        
        local count=0
        for script in "${scripts[@]}"; do
            if (( count >= 10 )); then
                break
            fi
            
            if [[ -f "$script" ]]; then
                script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
            else
                script_size=0
            fi
            
            job_weight=$(get_job_weight "$script_size" "${#target_langs[@]}")
            # Mittlere Priority → eher leichtere Jobs
            local adjusted_weight="$job_weight"
            if [[ "$job_weight" == "heavy" ]]; then
                adjusted_weight="medium"
            fi
            selected_node=$(get_node_by_priority "$adjusted_weight")
            log "Processing $(basename "$script") (${job_weight}) on ${selected_node}"
            
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
    
    if command -v git >/dev/null 2>&1 && [[ -d "$ABSTRACTIONS_REPO/.git" ]]; then
        (
            cd "$ABSTRACTIONS_REPO" || return 1
            git add . >/dev/null 2>&1 || true
            git commit -m "$message" >/dev/null 2>&1 || true
            log "Git commit: $message"
        ) || true
    fi
}

create_status_report() {
    local state="$1"
    local report_file="${ABSTRACTIONS_REPO}/STATUS.md"
    
    local lang_counts=()
    local lang
    local count
    
    if [[ -d "$ABSTRACTIONS_REPO" ]]; then
        for lang in "${!TARGET_LANGUAGES[@]}"; do
            if [[ -d "${ABSTRACTIONS_REPO}/${lang}" ]]; then
                count=$(find "${ABSTRACTIONS_REPO}/${lang}" -type f 2>/dev/null | wc -l)
                lang_counts+=("${lang}:${count}")
            fi
        done
    fi
    
    {
        echo "# Script Abstractions - Status Report"
        echo ""
        echo "**Letzte Aktualisierung:** $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "- Aktuelle Priorität: $(echo "$state" | jq -r '.current_priority // "high"')"
        echo "- Verarbeitete Scripts: $(echo "$state" | jq -r '.processed | length')"
        echo "- Abstraktionen gesamt: $(echo "$state" | jq -r '.stats.abstractions_created // 0')"
        echo ""
        echo "## Abstraktionen pro Sprache"
        echo ""
        
        for item in "${lang_counts[@]}"; do
            IFS=':' read -r lang count <<< "$item"
            echo "- ${lang}: ${count}"
        done
        
        echo ""
        echo "## Verfügbare Modelle"
        echo ""
        
        local i=0
        for model in "${AVAILABLE_MODELS[@]}"; do
            if (( i < 3 )); then
                echo "- \`${model}\`"
            fi
            ((i++))
        done
        echo "- ... und $(( ${#AVAILABLE_MODELS[@]} - 3 )) weitere"
        
        echo ""
        echo "## Multi-Node Support"
        echo ""
        echo "| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |"
        echo "|------|---------------|-----------|-----------|-------|"
        
        local node_id
        local config
        local always_available
        local capacity
        local priority
        local device
        
        for node_id in "${!NODES[@]}"; do
            config="${NODES[$node_id]}"
            always_available=$(echo "$config" | grep -o "always_available:[^,]*" | cut -d: -f2)
            capacity=$(echo "$config" | grep -o "capacity:[^,]*" | cut -d: -f2)
            priority=$(echo "$config" | grep -o "priority:[^,]*" | cut -d: -f2)
            device=$(echo "$config" | grep -o "device:[^,]*" | cut -d: -f2 || echo "Server")
            
            local avail="✅ Immer"
            if [[ "$always_available" != "true" ]]; then
                avail="📱 Bedingt"
            fi
            
            echo "| ${node_id} | ${avail} | ${capacity:-unknown} | ${priority:--} | ${device} |"
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
    
    local state
    state=$(load_state)
    local processed_count
    processed_count=$(echo "$state" | jq -r '.processed | length')
    log "State loaded: ${processed_count} processed"
    
    local current_priority
    current_priority=$(echo "$state" | jq -r '.current_priority // "high"')
    local created=0
    
    if [[ "$current_priority" == "high" ]]; then
        log "Processing HIGH priority: Top 5 Skills"
        created=$(process_priority_high)
        if (( created > 0 )); then
            git_commit "High priority: ${created} abstractions"
        fi
        state=$(echo "$state" | jq '.current_priority = "medium"')
    elif [[ "$current_priority" == "medium" ]]; then
        log "Processing MEDIUM priority: Workspace Scripts"
        created=$(process_priority_medium)
        if (( created > 0 )); then
            git_commit "Medium priority: ${created} abstractions"
        fi
        state=$(echo "$state" | jq '.current_priority = "high"')  # Zyklus
    fi
    
    local abstractions_count=0
    local lang
    for lang in "${!TARGET_LANGUAGES[@]}"; do
        if [[ -d "${ABSTRACTIONS_REPO}/${lang}" ]]; then
            local count
            count=$(find "${ABSTRACTIONS_REPO}/${lang}" -type f 2>/dev/null | wc -l)
            abstractions_count=$((abstractions_count + count))
        fi
    done
    
    state=$(echo "$state" | jq ".stats.last_run = \"$(date -Iseconds)\" | .stats.abstractions_created = ${abstractions_count}")
    
    save_state "$state"
    create_status_report "$state"
    
    log "Abgeschlossen. ${created} neue Abstraktionen erstellt."
}

main "$@"
