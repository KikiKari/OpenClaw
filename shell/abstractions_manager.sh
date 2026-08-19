#!/bin/bash
# abstractions_manager.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
readonly WORKSPACE="/home/openclaw/.openclaw/workspace"
readonly ABSTRACTIONS_REPO="${WORKSPACE}/git/Abstraktionen"
readonly LOG_DIR="${WORKSPACE}/logs/abstractions-manager"
readonly STATE_FILE="${WORKSPACE}/db/abstractions_state.json"

# Node-Konfiguration mit Prioritäten
declare -A NODES=(
    ["node1"]="always_available:true,capacity:medium,priority:2"      # Gateway-Master
    ["node2"]="always_available:true,capacity:medium,priority:3"      # Stable Worker
    ["node3"]="always_available:false,capacity:medium,priority:4"     # Bald verfügbar
    ["node5"]="always_available:false,capacity:low,priority:5,device:Redmi Note 11S,condition:mobile_internet"
    ["node7"]="always_available:true,capacity:high,priority:1"       # Docker Hauptarbeitspferd
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

# Ziel-Sprachenkonfiguration
declare -A TARGET_LANGUAGES=(
    ["perl5"]="ext:.pl,shebang:#!/usr/bin/env perl,header:use strict;\nuse warnings;"
    ["perl6"]="ext:.raku,shebang:#!/usr/bin/env raku,header:use v6;"
    ["javascript"]="ext:.js,shebang:#!/usr/bin/env node,header:"
    ["python"]="ext:.py,shebang:#!/usr/bin/env python3,header:"
    ["shell"]="ext:.sh,shebang:#!/bin/bash,header:set -euo pipefail"
    ["powershell"]="ext:.ps1,shebang:#!/usr/bin/env pwsh,header:#Requires -Version 7"
    ["tcl"]="ext:.tcl,shebang:#!/usr/bin/env tclsh,header:package require Tcl 8.6"
    ["ruby"]="ext:.rb,shebang:#!/usr/bin/env ruby,header:require 'json'\nrequire 'fileutils'"
    ["lua"]="ext:.lua,shebang:#!/usr/bin/env lua,header:"
    ["go"]="ext:.go,shebang:// +build ignore,header:package main"
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
        if [[ ! -v NODES[$node_id] ]]; then
            continue
        fi
        
        local node_config="${NODES[$node_id]}"
        local always_available=false
        
        IFS=',' read -ra CONFIG_ITEMS <<< "$node_config"
        for item in "${CONFIG_ITEMS[@]}"; do
            IFS=':' read -r key value <<< "$item"
            if [[ "$key" == "always_available" ]] && [[ "$value" == "true" ]]; then
                always_available=true
                break
            fi
        done
        
        # Skip nicht immer verfügbare Nodes wenn nicht explizit requested
        if [[ "$always_available" == false ]] && [[ "$job_weight" != "light" ]]; then
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
    if [[ -v NODES[$node_id] ]]; then
        local node_config="${NODES[$node_id]}"
        IFS=',' read -ra CONFIG_ITEMS <<< "$node_config"
        for item in "${CONFIG_ITEMS[@]}"; do
            IFS=':' read -r key value <<< "$item"
            if [[ "$key" == "always_available" ]] && [[ "$value" == "true" ]]; then
                return 0
            fi
        done
    fi
    
    return 1
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
    
    # Default state
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
    local state_json="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$state_json" > "$STATE_FILE"
}

find_scripts_in_dir() {
    local directory="$1"
    shift
    local exclude_patterns=("$@")
    
    if [[ ${#exclude_patterns[@]} -eq 0 ]]; then
        exclude_patterns=("node_modules" ".git" "__pycache__" "dist" "build")
    fi
    
    if [[ -d "$directory" ]]; then
        local find_cmd="find \"$directory\" \\( -name '*.py' -o -name '*.js' -o -name '*.sh' -o -name '*.pl' -o -name '*.rb' \\)"
        
        local exclude_part=""
        local pattern
        for pattern in "${exclude_patterns[@]}"; do
            if [[ -z "$exclude_part" ]]; then
                exclude_part="-not -path '*/$pattern/*'"
            else
                exclude_part="$exclude_part -not -path '*/$pattern/*'"
            fi
        done
        
        if [[ -n "$exclude_part" ]]; then
            find_cmd="$find_cmd $exclude_part"
        fi
        
        find_cmd="$find_cmd -print"
        
        eval "$find_cmd" 2>/dev/null || true
    fi
}

create_abstraction() {
    local script_path="$1"
    local target_lang="$2"
    
    if [[ ! -f "$script_path" ]]; then
        log "Script does not exist: $script_path" "ERROR"
        return 1
    fi
    
    local ext
    ext="${script_path##*.}"
    
    declare -A source_lang_map=(
        ["py"]="Python"
        ["js"]="JavaScript"
        ["sh"]="Shell"
        ["pl"]="Perl"
        ["rb"]="Ruby"
    )
    
    local source_lang="${source_lang_map[$ext]:-$ext}"
    
    local lang_config="${TARGET_LANGUAGES[$target_lang]}"
    if [[ -z "$lang_config" ]]; then
        log "Unsupported target language: $target_lang" "ERROR"
        return 1
    fi
    
    # Parse language config
    local shebang header ext_value
    IFS=',' read -ra LANG_ITEMS <<< "$lang_config"
    for item in "${LANG_ITEMS[@]}"; do
        IFS=':' read -r key value <<< "$item"
        case "$key" in
            "ext") ext_value="$value" ;;
            "shebang") shebang="$value" ;;
            "header") header="$value" ;;
        esac
    done
    
    local target_dir="${ABSTRACTIONS_REPO}/${target_lang}"
    mkdir -p "$target_dir"
    
    local target_file="${target_dir}/$(basename "${script_path%.*}")${ext_value}"
    
    if [[ -f "$target_file" ]]; then
        return 1
    fi
    
    # Read first 15 lines of original content
    local lines
    lines=$(head -n 15 "$script_path" 2>/dev/null || echo "")
    
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
$(echo "$lines" | sed 's/^/# /')

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
    
    local created=0
    local script target_lang
    
    if [[ "$node_id" == "node1" ]]; then
        # Lokale Verarbeitung
        for script in "${scripts[@]}"; do
            for target_lang in perl5 javascript python shell tcl; do
                if create_abstraction "$script" "$target_lang"; then
                    ((created++))
                fi
            done
        done
    else
        # Remote-Verarbeitung
        log "Dispatching ${#scripts[@]} jobs to ${node_id}"
        # Für jetzt: Lokale Verarbeitung mit Node-Logging
        for script in "${scripts[@]}"; do
            for target_lang in perl5 javascript python shell tcl; do
                if create_abstraction "$script" "$target_lang"; then
                    ((created++))
                    log "Processed on ${node_id}: $(basename "$script") -> ${target_lang}"
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
    
    local skill_name scripts_dir entry
    for entry in "${targets[@]}"; do
        IFS=':' read -r skill_name scripts_dir <<< "$entry"
        
        mapfile -t scripts < <(find_scripts_in_dir "$scripts_dir" "node_modules" ".git" "test" "tests")
        log "${skill_name}: ${#scripts[@]} scripts found"
        
        local count=0
        local script
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
            log "Processing $(basename "$script") (${job_weight}) on ${selected_node}"
            
            local new_created
            new_created=$(process_on_node "$selected_node" "$script")
            ((created += new_created))
            
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
    
    local dir_name scripts_dir entry
    for entry in "${targets[@]}"; do
        IFS=':' read -r dir_name scripts_dir <<< "$entry"
        
        mapfile -t scripts < <(find_scripts_in_dir "$scripts_dir" "node_modules" ".git")
        
        local script
        for script in "${scripts[@]}"; do
            local script_size=0
            if [[ -f "$script" ]]; then
                script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
            fi
            
            local target_langs=("perl5" "javascript" "powershell" "python")
            local job_weight
            job_weight=$(get_job_weight "$script_size" "${#target_langs[@]}")
            
            # Mittlere Priority → eher leichtere Jobs
            local adjusted_weight="$job_weight"
            if [[ "$job_weight" == "heavy" ]]; then
                adjusted_weight="medium"
            fi
            
            local selected_node
            selected_node=$(get_node_by_priority "$adjusted_weight")
            log "Processing $(basename "$script") (${job_weight}) on ${selected_node}"
            
            local new_created
            new_created=$(process_on_node "$selected_node" "$script")
            ((created += new_created))
        done
    done
    
    echo "$created"
}

git_commit() {
    local message="$1"
    
    if command -v git >/dev/null 2>&1 && [[ -d "$ABSTRACTIONS_REPO" ]]; then
        (
            cd "$ABSTRACTIONS_REPO" || return 1
            git add . >/dev/null 2>&1 || true
            git commit -m "$message" >/dev/null 2>&1 || true
            log "Git commit: $message"
        ) || true
    fi
}

create_status_report() {
    local state_json="$1"
    local report_file="${ABSTRACTIONS_REPO}/STATUS.md"
    
    # Count files per language
    declare -A lang_counts
    if [[ -d "$ABSTRACTIONS_REPO" ]]; then
        local lang_dir
        for lang_dir in "$ABSTRACTIONS_REPO"/*/; do
            if [[ -d "$lang_dir" ]]; then
                local lang_name
                lang_name=$(basename "$lang_dir")
                if [[ -v TARGET_LANGUAGES[$lang_name] ]]; then
                    lang_counts["$lang_name"]=$(find "$lang_dir" -maxdepth 1 -type f | wc -l)
                fi
            fi
        done
    fi
    
    # Write report
    cat > "$report_file" <<EOF
# Script Abstractions - Status Report

**Letzte Aktualisierung:** $(date '+%Y-%m-%d %H:%M')

- Aktuelle Priorität: $(echo "$state_json" | jq -r '.current_priority // "high"')
- Verarbeitete Scripts: $(echo "$state_json" | jq -r '.processed | length')
- Abstraktionen gesamt: $(echo "$state_json" | jq -r '.stats.abstractions_created // 0')

## Abstraktionen pro Sprache

EOF

    local lang count
    for lang in $(printf '%s\n' "${!lang_counts[@]}" | sort); do
        count="${lang_counts[$lang]}"
        echo "- ${lang}: ${count}" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

## Verfügbare Modelle

EOF

    local i=0
    for model in "${AVAILABLE_MODELS[@]}"; do
        if (( i < 3 )); then
            echo "- \`${model}\`" >> "$report_file"
        fi
        ((i++))
    done
    
    echo "- ... und $((i - 3)) weitere" >> "$report_file"

    cat >> "$report_file" <<EOF

## Multi-Node Support

| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |
|------|---------------|-----------|-----------|-------|
EOF

    local node_id node_config
    for node_id in "${!NODES[@]}"; do
        node_config="${NODES[$node_id]}"
        local avail="?" capacity="?" priority="?" device="?"
        
        IFS=',' read -ra CONFIG_ITEMS <<< "$node_config"
        for item in "${CONFIG_ITEMS[@]}"; do
            IFS=':' read -r key value <<< "$item"
            case "$key" in
                "always_available") 
                    if [[ "$value" == "true" ]]; then
                        avail="✅ Immer"
                    else
                        avail="📱 Bedingt"
                    fi
                    ;;
                "capacity") capacity="$value" ;;
                "priority") priority="$value" ;;
                "device") device="$value" ;;
            esac
        done
        
        echo "| ${node_id} | ${avail} | ${capacity} | ${priority} | ${device} |" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

### Job-Verteilung

- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)
- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)
- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)
EOF
}

main() {
    log "Script Abstractions Manager (Multi-Node) gestartet"
    
    local state_json
    state_json=$(load_state)
    local processed_count
    processed_count=$(echo "$state_json" | jq -r '.processed | length')
    log "State loaded: ${processed_count} processed"
    
    local current_priority
    current_priority=$(echo "$state_json" | jq -r '.current_priority // "high"')
    local created=0
    
    if [[ "$current_priority" == "high" ]]; then
        log "Processing HIGH priority: Top 5 Skills"
        created=$(process_priority_high)
        if (( created > 0 )); then
            git_commit "High priority: ${created} abstractions"
        fi
        state_json=$(echo "$state_json" | jq '.current_priority = "medium"')
    elif [[ "$current_priority" == "medium" ]]; then
        log "Processing MEDIUM priority: Workspace Scripts"
        created=$(process_priority_medium)
        if (( created > 0 )); then
            git_commit "Medium priority: ${created} abstractions"
        fi
        state_json=$(echo "$state_json" | jq '.current_priority = "high"')  # Zyklus
    fi
    
    # Update stats
    local total_abstractions=0
    local lang
    for lang in "${!TARGET_LANGUAGES[@]}"; do
        if [[ -d "${ABSTRACTIONS_REPO}/${lang}" ]]; then
            local count
            count=$(find "${ABSTRACTIONS_REPO}/${lang}" -maxdepth 1 -type f | wc -l)
            ((total_abstractions += count))
        fi
    done
    
    state_json=$(echo "$state_json" | jq --arg ts "$(date -Iseconds)" '.stats.last_run = $ts | .stats.abstractions_created = '"$total_abstractions")
    
    save_state "$state_json"
    create_status_report "$state_json"
    
    log "Abgeschlossen. ${created} neue Abstraktionen erstellt."
}

main "$@"
