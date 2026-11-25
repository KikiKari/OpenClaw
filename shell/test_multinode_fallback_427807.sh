#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "080d17295c6557f43b1218d094864b909e3a3545ec906066642ec061329e21bc", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "shell"}
# test_multinode_fallback.py — portiert nach shell
# Quelle: python, workspace@local:scripts/test_multinode_fallback.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Testet Multi-Node Fallback-Logik des db-maintainer
# Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal

readonly WORKSPACE="/home/openclaw/.openclaw/workspace"

check_node_reachable() {
    local node_id="$1"
    local node_id_lower
    node_id_lower=$(echo "$node_id" | tr '[:upper:]' '[:lower:]')
    
    # Definiere Aliase für Node 2
    local node2_names=("openclaw-node2" "arm64-node" "v2202604104722449961" "v2202604104722449961.taild25fea.ts.net")
    local aliases=("$node_id_lower")
    
    # Prüfe ob node_id in node2_names enthalten ist
    local is_node2=false
    for name in "${node2_names[@]}"; do
        if [[ "$node_id_lower" == "$name" ]]; then
            is_node2=true
            break
        fi
    done
    
    if [[ "$is_node2" == true ]]; then
        # Füge alle node2_names zu aliases hinzu
        for name in "${node2_names[@]}"; do
            aliases+=("$name")
        done
    fi
    
    # Führe den Befehl aus und verarbeite JSON
    local output
    if ! output=$(timeout 10 openclaw nodes status --json 2>/dev/null); then
        return 1
    fi
    
    # Parse JSON mit jq (falls verfügbar) oder grep/sed
    local connected_nodes
    if command -v jq >/dev/null 2>&1; then
        connected_nodes=$(echo "$output" | jq -r '.nodes[] | select(.connected == true) | .displayName' 2>/dev/null || echo "")
    else
        # Alternative Implementierung ohne jq
        connected_nodes=$(echo "$output" | grep -i '"connected": *true' -B 5 | grep -i '"displayName"' | sed -E 's/.*"displayName"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/i')
    fi
    
    # Prüfe jeden connected node gegen aliases
    while IFS= read -r connected_node; do
        local connected_lower
        connected_lower=$(echo "$connected_node" | tr '[:upper:]' '[:lower:]')
        for alias in "${aliases[@]}"; do
            if [[ "$connected_lower" == "$alias" ]]; then
                return 0
            fi
        done
    done <<< "$(echo "$connected_nodes")"
    
    return 1
}

spawn_on_node() {
    local node_id="$1"
    local task="$2"
    echo "Versuche Task auf Node $node_id zu starten..."
    
    # Simuliere den Spawn-Befehl
    if echo "Spawned on $node_id: $task" >/dev/null 2>&1; then
        echo "✅ Erfolgreich delegiert an $node_id"
        return 0
    else
        echo "❌ Node $node_id nicht erreichbar: Kommando fehlgeschlagen"
        return 1
    fi
}

execute_locally() {
    local task="$1"
    echo "🔄 Fallback: Führe Task lokal aus..."
    
    case "$task" in
        db_maintainer)
            local script_path="$WORKSPACE/skills/db-maintainer/scripts/db_maintainer.py"
            if [[ ! -f "$script_path" ]]; then
                echo "❌ Skript nicht gefunden: $script_path"
                return 1
            fi
            
            local output stderr exit_code
            output=$(python3 "$script_path" 2> >(stderr=$(cat); echo "$stderr") || exit_code=$?)
            exit_code=${exit_code:-0}
            
            if [[ $exit_code -eq 0 ]]; then
                echo "✅ Lokale Ausführung erfolgreich"
                return 0
            else
                echo "❌ Fehler: ${stderr:0:200}"
                return 1
            fi
            ;;
        *)
            echo "❌ Unbekannter Task: $task"
            return 1
            ;;
    esac
}

main() {
    echo "============================================================"
    echo "MULTI-NODE FALLBACK TEST"
    echo "============================================================"
    echo
    
    # Konfiguration
    local primary_node="v2202604104722449961.taild25fea.ts.net"  # Node 2
    local task="db_maintainer"
    
    echo "Primärer Node: $primary_node"
    echo "Task: $task"
    echo
    
    # 1. Prüfe Node-Erreichbarkeit
    echo "--- 1. Prüfe Node-Erreichbarkeit ---"
    if check_node_reachable "$primary_node"; then
        echo "✅ Node $primary_node ist erreichbar"
        
        # 2. Versuche Delegation
        echo
        echo "--- 2. Versuche Delegation ---"
        if spawn_on_node "$primary_node" "$task"; then
            echo
            echo "✅ MULTI-NODE: Task erfolgreich delegiert"
            return 0
        else
            echo
            echo "⚠️ Delegation fehlgeschlagen, aktiviere Fallback..."
        fi
    else
        echo "❌ Node $primary_node nicht erreichbar"
        echo "🔄 Fallback wird aktiviert..."
    fi
    
    # 3. Lokale Ausführung (Fallback)
    echo
    echo "--- 3. Lokale Ausführung (Fallback) ---"
    if execute_locally "$task"; then
        echo
        echo "✅ FALLBACK: Task lokal erfolgreich ausgeführt"
        return 0
    else
        echo
        echo "❌ FEHLER: Weder Delegation noch Fallback erfolgreich"
        return 1
    fi
}

main "$@"
