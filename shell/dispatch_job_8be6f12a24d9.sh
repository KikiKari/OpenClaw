#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "2b2a52d95a8b4e8a2a94d8bfb69075525775eef2585b61bdaf79cb71ff62fe92", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "shell"}
# dispatch_job.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Job Dispatcher - Verteilt Jobs auf passende Nodes

# Node-Konfiguration
declare -A NODES=(
    ["node1"]="always_available:true,capacity:medium,priority:3,description:Gateway"
    ["node2"]="always_available:false,capacity:high,priority:1,description:ARM Server"
    ["node3"]="always_available:false,capacity:medium,priority:4,description:AMD Server"
    ["node4"]="always_available:false,capacity:low,priority:5,device:Redmi Note 11S"
    ["node5"]="always_available:false,capacity:high,priority:2,device:Lenovo"
    ["node6"]="always_available:false,device:Lenovo (Docker)"
)

declare -A NODE_NAMES=(
    ["node2"]="openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122"
    ["node3"]="openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125"
    ["node4"]="openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39"
    ["node5"]="openclaw-node5 windows node (lenovo-7)"
    ["node6"]="openclaw-node6"
)

_job_weight_bytes() {
    local script_path="$1"
    local target_langs_count="$2"
    
    # Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen
    local size
    size=$(stat -c%s "$script_path" 2>/dev/null || echo "0")
    echo $((size * target_langs_count))
}

fetch_node_status() {
    # Return mapped OpenClaw connection states; None indicates lookup failure
    local output
    if ! output=$(timeout 10 openclaw nodes status --json 2>/dev/null); then
        return 1
    fi
    
    # Parse JSON using jq
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required for JSON parsing" >&2
        return 1
    fi
    
    # Initialize all nodes as false
    declare -A states
    for node in "${!NODE_NAMES[@]}"; do
        states["$node"]=false
    done
    
    # Parse the JSON response
    local connected_nodes
    connected_nodes=$(echo "$output" | jq -r '.nodes[] | select(.connected == true) | .displayName, .nodeId, .remoteIp' 2>/dev/null || echo "")
    
    # Check each connected node against our known names
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
        
        for node in "${!NODE_NAMES[@]}"; do
            local aliases=${NODE_NAMES[$node]}
            if [[ " $aliases " =~ " $name " ]]; then
                states["$node"]=true
            fi
        done
    done <<< "$connected_nodes"
    
    # Set node1 as true if we successfully got the status
    states["node1"]=true
    
    # Output results
    for node in "${!states[@]}"; do
        echo "$node:${states[$node]}"
    done
}

get_job_weight() {
    local script_path="$1"
    local target_langs_count="${2:-1}"
    
    # Bewertet Job-Gewicht
    if [[ ! -f "$script_path" ]]; then
        echo "medium"
        return
    fi
    
    local total_work
    total_work=$(_job_weight_bytes "$script_path" "$target_langs_count")
    
    if ((total_work > 50000)); then  # > 50KB
        echo "heavy"
    elif ((total_work > 10000)); then  # > 10KB
        echo "medium"
    else
        echo "light"
    fi
}

select_node() {
    local job_weight="$1"
    local preferred_nodes=""
    
    # Wählt besten Node basierend auf Job-Gewicht
    case "$job_weight" in
        heavy)
            preferred_nodes=("node1" "node2" "node5" "node6")
            ;;
        medium)
            preferred_nodes=("node1" "node2" "node3" "node6")
            ;;
        light)
            preferred_nodes=("node2" "node1" "node3" "node4")
            ;;
        *)
            echo "Unknown job weight: $job_weight" >&2
            return 1
            ;;
    esac
    
    # Get node status
    local states_output
    if ! states_output=$(fetch_node_status 2>/dev/null); then
        echo "none"
        return 0
    fi
    
    # Convert states to associative array
    declare -A states
    while IFS=: read -r node status; do
        states["$node"]="$status"
    done <<< "$states_output"
    
    # Find first available node from preferred list
    for node_id in "${preferred_nodes[@]}"; do
        if [[ "${states[$node_id]:-false}" == "true" ]]; then
            echo "$node_id"
            return 0
        fi
    done
    
    echo "none"
}

check_node_available() {
    local node_id="$1"
    
    # Use the live connection state rather than static availability
    local states_output
    if ! states_output=$(fetch_node_status 2>/dev/null); then
        return 1
    fi
    
    declare -A states
    while IFS=: read -r node status; do
        states["$node"]="$status"
    done <<< "$states_output"
    
    [[ "${states[$node_id]:-false}" == "true" ]]
}

_check_mobile_online() {
    # Check Node4 (Redmi)
    check_node_available "node4"
}

dispatch() {
    local job_script="$1"
    local target_langs_str="${2:-perl5}"
    local source_text="${3:-}"
    local source_language="${4:-}"
    
    # Convert comma-separated languages to array
    IFS=',' read -ra target_langs <<< "$target_langs_str"
    
    # Dispatched Job und gibt Info zurück
    local weight
    weight=$(get_job_weight "$job_script" "${#target_langs[@]}")
    
    local selected_node
    selected_node=$(select_node "$weight")
    
    # Output dispatch information
    echo "📦 Job Dispatch Information"
    echo "=================================================="
    echo "Job: $job_script"
    echo "Size: $(stat -c%s "$job_script" 2>/dev/null || echo "0") bytes"
    echo "Target langs: ${target_langs[*]}"
    echo "Job weight: $weight"
    echo "Selected node: $selected_node"
    echo "=================================================="
    
    if [[ "$selected_node" == "none" ]]; then
        echo "Status: unavailable"
    else
        echo "Status: selected"
    fi
}

execute_translation() {
    local job_json="$1"
    local transport="$2"
    
    # Execute via a supplied transport and verify its result belongs to the job
    if [[ -z "$transport" ]]; then
        echo "no verified node or authorized translation transport" >&2
        return 1
    fi
    
    # This would need implementation of actual transport mechanism
    echo "Translation execution not implemented" >&2
    return 1
}

dispatch_abstraction_job() {
    local job_script="$1"
    local target_langs="$2"
    
    # Erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag
    dispatch "$job_script" "$target_langs"
}

main() {
    local job=""
    local langs="perl5"
    local weight=""
    local execute=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --job|-j)
                job="$2"
                shift 2
                ;;
            --langs|-l)
                langs="$2"
                shift 2
                ;;
            --weight|-w)
                weight="$2"
                shift 2
                ;;
            --execute|-x)
                execute=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Dispatch job to optimal node"
                echo ""
                echo "Options:"
                echo "  -j, --job JOB       Path to job script"
                echo "  -l, --langs LANGS   Comma-separated target languages (default: perl5)"
                echo "  -w, --weight WEIGHT Force job weight (light|medium|heavy)"
                echo "  -x, --execute       Actually execute on selected node"
                echo "  -h, --help          Show this help"
                return 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
    
    if [[ -z "$job" ]]; then
        echo "❌ Job path is required (--job)" >&2
        return 1
    fi
    
    if [[ ! -f "$job" ]]; then
        echo "❌ Job not found: $job" >&2
        return 1
    fi
    
    # Determine weight
    if [[ -n "$weight" ]]; then
        local job_weight="$weight"
    else
        local job_weight
        job_weight=$(get_job_weight "$job" "$(echo "$langs" | tr ',' '\n' | wc -l)")
    fi
    
    # Select node
    local selected_node
    selected_node=$(select_node "$job_weight")
    
    # Output
    echo "📦 Job Dispatch Information"
    echo "=================================================="
    echo "Job: $job"
    echo "Size: $(stat -c%s "$job") bytes"
    echo "Target langs: $langs"
    echo "Job weight: $job_weight"
    echo "Selected node: $selected_node"
    echo "=================================================="
    
    if [[ "$execute" == true ]]; then
        echo "" >&2
        echo "Translation dispatch on $selected_node is not implemented." >&2
        return 1
    else
        echo ""
        echo "💡 To execute: $0 --job $job --execute"
    fi
    
    return 0
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
