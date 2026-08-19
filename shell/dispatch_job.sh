#!/usr/bin/env bash
# dispatch_job.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node-Konfiguration
declare -A NODES_node1=(["always_available"]=1 ["capacity"]="medium" ["priority"]=2)
declare -A NODES_node2=(["always_available"]=1 ["capacity"]="medium" ["priority"]=3)
declare -A NODES_node3=(["always_available"]=0 ["capacity"]="medium" ["priority"]=4)
declare -A NODES_node5=(["always_available"]=0 ["capacity"]="low" ["priority"]=5 ["device"]="Redmi Note 11S")
declare -A NODES_node7=(["always_available"]=1 ["capacity"]="high" ["priority"]=1)

# Funktion zum Abrufen der Knotenkonfiguration
get_node_config() {
    local node_id="$1"
    case "$node_id" in
        node1) declare -n node=NODES_node1 ;;
        node2) declare -n node=NODES_node2 ;;
        node3) declare -n node=NODES_node3 ;;
        node5) declare -n node=NODES_node5 ;;
        node7) declare -n node=NODES_node7 ;;
        *) echo "Unbekannter Knoten: $node_id" >&2; return 1 ;;
    esac
    echo "${node[@]}"
}

# Bewertet Job-Gewicht
get_job_weight() {
    local script_path="$1"
    local target_langs_count="${2:-1}"
    
    if [[ ! -f "$script_path" ]]; then
        echo "medium"
        return
    fi
    
    local script_size
    script_size=$(stat -c%s "$script_path" 2>/dev/null || stat -f%z "$script_path" 2>/dev/null)
    local total_work=$((script_size * target_langs_count))
    
    if (( total_work > 50000 )); then  # > 50KB
        echo "heavy"
    elif (( total_work > 10000 )); then  # > 10KB
        echo "medium"
    else
        echo "light"
    fi
}

# Prüft ob Redmi (Node 5) Internet hat
_check_mobile_online() {
    if command -v openclaw >/dev/null 2>&1; then
        if timeout 5 openclaw nodes status node5 2>/dev/null | grep -qi "online"; then
            return 0
        fi
    fi
    return 1
}

# Prüft ob Node erreichbar ist
check_node_available() {
    local node_id="$1"
    local node_ref
    node_ref=$(get_node_config "$node_id") || return 1
    
    # Extrahiere always_available aus der Konfiguration
    local always_available=0
    case "$node_ref" in
        *always_available=1*) always_available=1 ;;
    esac
    
    # Nicht immer-verfügbare Nodes nur wenn explizit requested
    if [[ $always_available -eq 0 ]]; then
        # Für light-jobs prüfen wir ob online
        if [[ "$node_id" == "node5" ]]; then  # Redmi
            _check_mobile_online
            return $?
        fi
        return 1
    fi
    
    # Für immer-verfügbare Nodes: prüfe ob wirklich online
    if command -v openclaw >/dev/null 2>&1; then
        if timeout 3 openclaw nodes status "$node_id" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return $always_available
}

# Wählt besten Node basierend auf Job-Gewicht
select_node() {
    local job_weight="$1"
    local preferred_nodes=()
    
    case "$job_weight" in
        heavy)
            # Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
            preferred_nodes=("node7" "node2" "node1")
            ;;
        medium)
            # Mittlere Jobs → Stable Nodes
            preferred_nodes=("node2" "node1" "node7")
            ;;
        *)
            # Leichte Jobs → Mobile/verfügbare Nodes
            preferred_nodes=("node5" "node1" "node2")
            ;;
    esac
    
    # Prüfe Verfügbarkeit
    for node_id in "${preferred_nodes[@]}"; do
        if check_node_available "$node_id"; then
            echo "$node_id"
            return
        fi
    done
    
    # Fallback
    echo "node1"
}

# Dispatched Job und gibt Info zurück
dispatch() {
    local job_script="$1"
    shift
    local target_langs=("$@")
    
    if [[ ${#target_langs[@]} -eq 0 ]]; then
        target_langs=("perl5")
    fi
    
    local weight
    weight=$(get_job_weight "$job_script" "${#target_langs[@]}")
    local selected_node
    selected_node=$(select_node "$weight")
    
    cat <<EOF
{
  "job": "$job_script",
  "weight": "$weight",
  "selected_node": "$selected_node",
  "target_langs": ["$(IFS='","'; echo "${target_langs[*]}")"],
  "status": "dispatched"
}
EOF
}

# Hauptprogramm
main() {
    local job=""
    local langs="perl5"
    local weight=""
    local execute=false
    
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
                echo "Usage: $0 --job JOB [--langs LANGS] [--weight WEIGHT] [--execute]"
                return 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
    
    if [[ -z "$job" ]]; then
        echo "❌ Job argument is required"
        return 1
    fi
    
    if [[ ! -f "$job" ]]; then
        echo "❌ Job not found: $job"
        return 1
    fi
    
    # Bestimme Gewicht
    if [[ -z "$weight" ]]; then
        weight=$(get_job_weight "$job" "$(echo "$langs" | tr ',' '\n' | wc -l)")
    fi
    
    # Wähle Knoten
    local selected_node
    selected_node=$(select_node "$weight")
    
    # Ausgabe
    echo "📦 Job Dispatch Information"
    echo "=================================================="
    echo "Job: $job"
    local size
    size=$(stat -c%s "$job" 2>/dev/null || stat -f%z "$job" 2>/dev/null)
    echo "Size: $size bytes"
    echo "Target langs: $langs"
    echo "Job weight: $weight"
    echo "Selected node: $selected_node"
    echo "=================================================="
    
    if [[ "$execute" == true ]]; then
        echo ""
        echo "🚀 Executing on $selected_node..."
        # TODO: Implement remote execution
        echo "(Remote execution not yet implemented)"
    else
        echo ""
        echo "💡 To execute: $0 --job $job --execute"
    fi
}

# Skriptstart
main "$@"
