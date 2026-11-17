#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "35687f053bac6537e101468c25288f4f58e78421dd1eee75cbca08286487135d", "source_sha256": "5a841c728d9c1585b5c3191e88fdd38cf887a0d51560ce803b8c0172412bef3d", "target_language": "shell"}
# check_nodes.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node-Konfiguration (sollte aus config file geladen werden)
declare -A NODES=(
    [node1]="always_available:true,capacity:medium,priority:2,description:Gateway-Master"
    [node2]="always_available:true,capacity:medium,priority:3,description:Stable Worker"
    [node3]="always_available:false,capacity:medium,priority:4,description:Bald verfügbar (nach Reorganisation)"
    [node5]="always_available:false,capacity:low,priority:5,device:Redmi Note 11S,description:Mobile (bei Internet verfügbar)"
    [node7]="always_available:true,capacity:high,priority:1,description:Docker Hauptarbeitspferd (bald verfügbar)"
)

# Standard-Ausgabeformat
FORMAT="table"
SAVE_FILE=""

# Funktion zum Parsen der Konfiguration
parse_config() {
    local node_config="$1"
    local key="$2"
    echo "$node_config" | grep -o "${key}:[^,]*" | cut -d: -f2
}

# Prüft Status eines einzelnen Nodes
check_node_status() {
    local node_id="$1"
    local config="${NODES[$node_id]}"
    
    local is_online=false
    local response=""
    
    # Versuche den Node-Status abzurufen
    if timeout 5 openclaw nodes status "$node_id" >/dev/null 2>&1; then
        response=$(timeout 5 openclaw nodes status "$node_id" 2>/dev/null | head -c 100)
        if [[ "$response" =~ [Oo][Nn][Ll][Ii][Nn][Ee] ]] || [[ "$response" =~ [Aa][Cc][Tt][Ii][Vv][Ee] ]]; then
            is_online=true
        fi
    else
        response="Timeout"
    fi
    
    local always_available
    always_available=$(parse_config "$config" "always_available")
    
    echo "$node_id:$is_online:$always_available:$response"
}

# Gibt Node-Status als Tabelle aus
print_table() {
    local nodes_status=("$@")
    
    printf "\n%s\n" "=========================================================================================="
    printf "%-8s %-12s %-12s %-10s %-10s %s\n" "Node" "Status" "Verfügbar" "Kapazität" "Priorität" "Gerät/Beschreibung"
    printf "%s\n" "=========================================================================================="
    
    for status_line in "${nodes_status[@]}"; do
        IFS=':' read -r node_id is_online available response <<< "$status_line"
        
        local config="${NODES[$node_id]}"
        
        local status_icon="🔴 Offline"
        [[ "$is_online" == "true" ]] && status_icon="🟢 Online"
        
        local avail_icon="📱 Bedingt"
        [[ "$available" == "true" ]] && avail_icon="✅ Immer"
        
        local capacity
        capacity=$(parse_config "$config" "capacity")
        [[ -z "$capacity" ]] && capacity="unknown"
        
        local priority
        priority=$(parse_config "$config" "priority")
        [[ -z "$priority" ]] && priority="-"
        
        local device_desc
        device_desc=$(parse_config "$config" "device")
        if [[ -z "$device_desc" ]]; then
            device_desc=$(parse_config "$config" "description")
        fi
        
        printf "%-8s %-12s %-12s %-10s %-10s %s\n" "$node_id" "$status_icon" "$avail_icon" "$capacity" "$priority" "$device_desc"
    done
    
    printf "%s\n" "=========================================================================================="
    printf "\nGeprüft am: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
}

# Gibt Node-Status als JSON aus
print_json() {
    local nodes_status=("$@")
    
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"nodes\": {"
    
    local first=true
    for status_line in "${nodes_status[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "    ,"
        fi
        
        IFS=':' read -r node_id is_online available response <<< "$status_line"
        local config="${NODES[$node_id]}"
        
        echo "    \"$node_id\": {"
        echo "      \"status\": {"
        echo "        \"id\": \"$node_id\","
        echo "        \"online\": $is_online,"
        echo "        \"available\": $available,"
        echo "        \"response\": \"$response\""
        echo "      },"
        echo "      \"config\": {"
        
        # Parse config and output each field
        local fields=(${config//,/ })
        local cfg_first=true
        for field in "${fields[@]}"; do
            if [ "$cfg_first" = true ]; then
                cfg_first=false
            else
                echo "        ,"
            fi
            
            IFS=':' read -r key value <<< "$field"
            if [[ "$value" =~ ^[0-9]+$ ]]; then
                echo "        \"$key\": $value"
            else
                echo "        \"$key\": \"$value\""
            fi
        done
        
        echo "      }"
        echo "    }"
    done
    
    echo "  }"
    echo "}"
}

# Speichert Ergebnisse in eine Datei
save_results() {
    local save_file="$1"
    local nodes_status=("${@:2}")
    
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"nodes\": {"
        
        local first=true
        for status_line in "${nodes_status[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo "    ,"
            fi
            
            IFS=':' read -r node_id is_online available response <<< "$status_line"
            echo "    \"$node_id\": {"
            echo "      \"id\": \"$node_id\","
            echo "      \"online\": $is_online,"
            echo "      \"available\": $available,"
            echo "      \"response\": \"$response\""
            echo "    }"
        done
        
        echo "  }"
        echo "}"
    } > "$save_file"
    
    printf "\n💾 Gespeichert: %s\n" "$save_file"
}

# Zeigt Zusammenfassung an
print_summary() {
    local nodes_status=("$@")
    
    local total=${#nodes_status[@]}
    local online_count=0
    
    for status_line in "${nodes_status[@]}"; do
        IFS=':' read -r _ is_online _ _ <<< "$status_line"
        if [[ "$is_online" == "true" ]]; then
            ((online_count++))
        fi
    done
    
    printf "\n📊 Zusammenfassung: %d/%d Nodes online\n" "$online_count" "$total"
}

# Hauptfunktion
main() {
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --format|-f)
                FORMAT="$2"
                shift 2
                ;;
            --save|-s)
                SAVE_FILE="$2"
                shift 2
                ;;
            *)
                echo "Unbekanntes Argument: $1" >&2
                exit 1
                ;;
        esac
    done
    
    echo "🔍 Prüfe Node-Status..."
    
    # Prüfe alle Nodes
    local nodes_status=()
    local sorted_nodes=($(printf '%s\n' "${!NODES[@]}" | sort))
    
    for node_id in "${sorted_nodes[@]}"; do
        printf "  → %s... " "$node_id"
        local status
        status=$(check_node_status "$node_id")
        nodes_status+=("$status")
        if [[ $(echo "$status" | cut -d: -f2) == "true" ]]; then
            echo "✓"
        else
            echo "✗"
        fi
    done
    
    # Ausgabe
    if [[ "$FORMAT" == "table" ]]; then
        print_table "${nodes_status[@]}"
    else
        print_json "${nodes_status[@]}"
    fi
    
    # Speichern
    if [[ -n "$SAVE_FILE" ]]; then
        save_results "$SAVE_FILE" "${nodes_status[@]}"
    fi
    
    # Zusammenfassung
    print_summary "${nodes_status[@]}"
}

# Skript starten
main "$@"
