#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "5d44595d49d1c86e87cf7553ecbcb9431cdb8e7ac1e36b5a6da773e7444d036d", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "shell"}
# dispatch_job.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Job Dispatcher - Verteilt Jobs auf passende Nodes

# Globale Variablen für Node-Konfiguration
declare -A NODE_CONFIG
declare -A NODE_NAMES

# Initialisiere Node-Konfiguration
init_nodes() {
    # Node-Konfiguration als JSON-ähnliche Struktur
    NODE_CONFIG["node1_always_available"]="true"
    NODE_CONFIG["node1_capacity"]="medium"
    NODE_CONFIG["node1_priority"]="3"
    NODE_CONFIG["node1_description"]="Gateway"
    
    NODE_CONFIG["node2_always_available"]="false"
    NODE_CONFIG["node2_capacity"]="high"
    NODE_CONFIG["node2_priority"]="1"
    NODE_CONFIG["node2_description"]="ARM Server"
    
    NODE_CONFIG["node3_always_available"]="false"
    NODE_CONFIG["node3_capacity"]="medium"
    NODE_CONFIG["node3_priority"]="4"
    NODE_CONFIG["node3_description"]="AMD Server"
    
    NODE_CONFIG["node4_always_available"]="false"
    NODE_CONFIG["node4_capacity"]="low"
    NODE_CONFIG["node4_priority"]="5"
    NODE_CONFIG["node4_device"]="Redmi Note 11S"
    
    NODE_CONFIG["node5_always_available"]="false"
    NODE_CONFIG["node5_capacity"]="high"
    NODE_CONFIG["node5_priority"]="2"
    NODE_CONFIG["node5_device"]="Lenovo"
    
    NODE_CONFIG["node6_always_available"]="false"
    NODE_CONFIG["node6_device"]="Lenovo (Docker)"
    
    # Node-Namen
    NODE_NAMES["node2"]="openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122"
    NODE_NAMES["node3"]="openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125"
    NODE_NAMES["node4"]="openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39"
    NODE_NAMES["node5"]="openclaw-node5 windows node (lenovo-7)"
    NODE_NAMES["node6"]="openclaw-node6"
}

# Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen
job_weight_bytes() {
    local script_path="$1"
    local target_langs_count="$2"
    
    if [[ ! -f "$script_path" ]]; then
        echo 0
        return
    fi
    
    local size
    size=$(stat -c %s "$script_path" 2>/dev/null || stat -f %z "$script_path" 2>/dev/null)
    echo $((size * target_langs_count))
}

# Return mapped OpenClaw connection states; leeres Array indicates lookup failure
fetch_node_status() {
    local -A states
    local result
    local payload
    local node
    local names_line
    local name
    
    # Initialize all nodes as disconnected
    for node in "${!NODE_NAMES[@]}"; do
        states["$node"]="false"
    done
    
    # Try to get node status
    if ! result=$(timeout 10 openclaw nodes status --json 2>/dev/null); then
        return 1
    fi
    
    # Parse JSON (simple approach - would need jq for robust parsing)
    if ! echo "$result" | grep -q '"nodes"'; then
        return 1
    fi
    
    # Simple parsing of node connections
    local connected_nodes=()
    local i=0
    while IFS= read -r line; do
        if [[ "$line" =~ \"connected\".*true ]]; then
            # Extract names from this node entry
            local names=""
            if [[ "$line" =~ \"displayName\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                names+=" ${BASH_REMATCH[1],,}"
            fi
            if [[ "$line" =~ \"nodeId\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                names+=" ${BASH_REMATCH[1],,}"
            fi
            if [[ "$line" =~ \"remoteIp\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                names+=" ${BASH_REMATCH[1],,}"
            fi
            
            # Check each node against its aliases
            for node in "${!NODE_NAMES[@]}"; do
                local aliases="${NODE_NAMES[$node]}"
                for name in $names; do
                    if [[ " $aliases " =~ " $name " ]]; then
                        states["$node"]="true"
                        break
                    fi
                done
            done
        fi
        ((i++))
    done < <(echo "$result" | grep -A 5 -B 5 connected)
    
    # Gateway is always available if status request succeeded
    states["node1"]="true"
    
    # Output results
    for node in "${!states[@]}"; do
        echo "$node:${states[$node]}"
    done
}

# Bewertet Job-Gewicht
get_job_weight() {
    local script_path="$1"
    local target_langs_count="${2:-1}"
    
    if [[ ! -f "$script_path" ]]; then
        echo "medium"
        return
    fi
    
    local total_work
    total_work=$(job_weight_bytes "$script_path" "$target_langs_count")
    
    if ((total_work > 50000)); then  # > 50KB
        echo "heavy"
    elif ((total_work > 10000)); then  # > 10KB
        echo "medium"
    else
        echo "light"
    fi
}

# Wählt besten Node basierend auf Job-Gewicht
select_node() {
    local job_weight="$1"
    local -a preferred
    local -A node_states
    local node_state_line
    local node_id
    local node_status
    
    case "$job_weight" in
        heavy)
            preferred=("node1" "node2" "node5" "node6")
            ;;
        medium)
            preferred=("node1" "node2" "node3" "node6")
            ;;
        light)
            preferred=("node2" "node1" "node3" "node4")
            ;;
        *)
            echo "Unknown job weight: $job_weight" >&2
            return 1
            ;;
    esac
    
    # Get node statuses
    while IFS=':' read -r node_id node_status; do
        node_states["$node_id"]="$node_status"
    done < <(fetch_node_status 2>/dev/null || true)
    
    # Find first available preferred node
    for node_id in "${preferred[@]}"; do
        if [[ "${node_states[$node_id]:-false}" == "true" ]]; then
            echo "$node_id"
            return 0
        fi
    done
    
    # No verified reachable node
    return 1
}

# Use the live connection state rather than static availability
check_node_available() {
    local node_id="$1"
    local node_state_line
    local node_status
    
    while IFS=':' read -r _node_id _node_status; do
        if [[ "$_node_id" == "$node_id" ]]; then
            node_status="$_node_status"
            break
        fi
    done < <(fetch_node_status 2>/dev/null || true)
    
    [[ "${node_status:-false}" == "true" ]]
}

# Check Node4 (Redmi)
check_mobile_online() {
    check_node_available "node4"
}

# Dispatched Job und gibt Info zurück
dispatch() {
    local job_script="$1"
    local target_langs_str="${2:-perl5}"
    local source_text="${3:-}"
    local source_language="${4:-}"
    
    local -a target_langs
    IFS=',' read -ra target_langs <<< "$target_langs_str"
    
    local weight
    weight=$(get_job_weight "$job_script" "${#target_langs[@]}")
    
    local selected_node=""
    if selected_node=$(select_node "$weight" 2>/dev/null); then
        : # Success
    else
        selected_node="" # No node available
    fi
    
    # Output results as JSON-like structure
    cat <<EOF
{
  "job": "$job_script",
  "weight": "$weight",
  "selected_node": "$selected_node",
  "target_langs": [$(printf '"%s",' "${target_langs[@]}" | sed 's/,$//')],
  "status": "$([[ -n "$selected_node" ]] && echo "selected" || echo "unavailable")"
}
EOF
}

# Hauptfunktion
main() {
    local job_path=""
    local langs="perl5"
    local weight=""
    local execute=false
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --job|-j)
                job_path="$2"
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
            *)
                echo "Unbekannte Option: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Validierung
    if [[ -z "$job_path" ]]; then
        echo "❌ Job-Pfad ist erforderlich" >&2
        return 1
    fi
    
    if [[ ! -f "$job_path" ]]; then
        echo "❌ Job nicht gefunden: $job_path" >&2
        return 1
    fi
    
    local job_size
    job_size=$(stat -c %s "$job_path" 2>/dev/null || stat -f %z "$job_path" 2>/dev/null)
    
    # Gewicht bestimmen
    if [[ -z "$weight" ]]; then
        local target_langs_count
        IFS=',' read -ra target_langs <<< "$langs"
        target_langs_count="${#target_langs[@]}"
        weight=$(get_job_weight "$job_path" "$target_langs_count")
    fi
    
    # Node auswählen
    local selected_node=""
    if selected_node=$(select_node "$weight" 2>/dev/null); then
        : # Success
    else
        selected_node="" # No node available
    fi
    
    # Ausgabe
    echo "📦 Job Dispatch Information"
    echo "=================================================="
    echo "Job: $job_path"
    echo "Size: $job_size bytes"
    echo "Target langs: $langs"
    echo "Job weight: $weight"
    echo "Selected node: $selected_node"
    echo "=================================================="
    
    if [[ "$execute" == true ]]; then
        echo "" >&2
        echo "Translation dispatch on $selected_node is not implemented." >&2
        return 1
    else
        echo ""
        echo "💡 To execute: $0 --job $job_path --execute"
    fi
    
    return 0
}

# Initialisierung und Start
init_nodes
main "$@"
