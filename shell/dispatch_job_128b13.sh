#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "f396ebf024457003a48e58ef463c141a83b9ca9cd90a2ccfc7c5ed91f08a5fea", "source_sha256": "128b137e5c7d86f81ea7fdb61718540c70e4ed38de4430ae6a23a5739962c024", "target_language": "shell"}
# dispatch_job.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node-Konfiguration
declare -A NODES_NODE1=(["always_available"]="true" ["capacity"]="medium" ["priority"]="2")
declare -A NODES_NODE2=(["always_available"]="true" ["capacity"]="medium" ["priority"]="3")
declare -A NODES_NODE3=(["always_available"]="false" ["capacity"]="medium" ["priority"]="4")
declare -A NODES_NODE5=(["always_available"]="false" ["capacity"]="low" ["priority"]="5" ["device"]="Redmi Note 11S")
declare -A NODES_NODE7=(["always_available"]="true" ["capacity"]="high" ["priority"]="1")

# Funktion zur Bestimmung des Job-Gewichts
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

# Funktion zur Auswahl des besten Nodes basierend auf dem Job-Gewicht
select_node() {
    local job_weight="$1"
    local preferred_nodes=()
    
    case "$job_weight" in
        heavy)
            preferred_nodes=("node7" "node2" "node1")
            ;;
        medium)
            preferred_nodes=("node2" "node1" "node7")
            ;;
        *)
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

# Funktion zur Prüfung, ob ein Node erreichbar ist
check_node_available() {
    local node_id="$1"
    local node_var="NODES_${node_id^^}"
    
    # Prüfe, ob Node existiert
    if ! declare -p "$node_var" &>/dev/null; then
        return 1
    fi
    
    # Extrahiere always_available-Wert
    local always_available
    eval "always_available=\${${node_var}[always_available]}"
    
    # Nicht immer-verfügbare Nodes nur wenn explizit requested
    if [[ "$always_available" != "true" ]]; then
        # Für light-jobs prüfen wir ob online
        if [[ "$node_id" == "node5" ]]; then  # Redmi
            _check_mobile_online && return 0 || return 1
        fi
        return 1
    fi
    
    # Für immer-verfügbare Nodes: prüfe ob wirklich online
    if command -v openclaw >/dev/null 2>&1; then
        if timeout 3 openclaw nodes status "$node_id" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        return 0  # Wenn openclaw nicht verfügbar ist, aber always_available=true
    fi
}

# Funktion zur Prüfung, ob Redmi (Node 5) Internet hat
_check_mobile_online() {
    if command -v openclaw >/dev/null 2>&1; then
        local output
        output=$(timeout 5 openclaw nodes status node5 2>&1)
        if [[ $? -eq 0 ]] && [[ "$output" == *"online"* ]]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Hauptfunktion zur Job-Verteilung
dispatch() {
    local job_script="$1"
    local target_langs="${2:-perl5}"
    
    local weight
    weight=$(get_job_weight "$job_script" "$(echo "$target_langs" | tr ',' '\n' | wc -l)")
    local selected_node
    selected_node=$(select_node "$weight")
    
    cat <<EOF
{
  "job": "$job_script",
  "weight": "$weight",
  "selected_node": "$selected_node",
  "target_langs": ["$(echo "$target_langs" | tr ',' '","')"],
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
    
    # Argumente parsen
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
            *)
                echo "Unbekannte Option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$job" ]]; then
        echo "❌ Job-Pfad ist erforderlich." >&2
        exit 1
    fi
    
    if [[ ! -f "$job" ]]; then
        echo "❌ Job nicht gefunden: $job" >&2
        exit 1
    fi
    
    local job_size
    job_size=$(stat -c%s "$job" 2>/dev/null || stat -f%z "$job" 2>/dev/null)
    
    # Gewicht bestimmen
    if [[ -z "$weight" ]]; then
        weight=$(get_job_weight "$job" "$(echo "$langs" | tr ',' '\n' | wc -l)")
    fi
    
    # Node auswählen
    local selected_node
    selected_node=$(select_node "$weight")
    
    # Ausgabe
    echo "📦 Job Dispatch Information"
    echo "=================================================="
    echo "Job: $job"
    echo "Size: $job_size bytes"
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

# Skript starten
main "$@"
