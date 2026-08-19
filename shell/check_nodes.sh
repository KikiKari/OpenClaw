#!/bin/bash
# check_nodes.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node-Status Checker - Prüft Verfügbarkeit aller Nodes

# Node-Konfiguration (sollte aus config file geladen werden)
declare -A NODES_CONFIG=(
    [node1]="always_available:true,capacity:medium,priority:2,description:Gateway-Master"
    [node2]="always_available:true,capacity:medium,priority:3,description:Stable Worker"
    [node3]="always_available:false,capacity:medium,priority:4,description:Bald verfügbar (nach Reorganisation)"
    [node5]="always_available:false,capacity:low,priority:5,device:Redmi Note 11S,description:Mobile (bei Internet verfügbar)"
    [node7]="always_available:true,capacity:high,priority:1,description:Docker Hauptarbeitspferd (bald verfügbar)"
)

check_node_status() {
    local node_id="$1"
    local response=""
    local is_online=false
    local always_available=false
    
    # Parse config
    IFS=',' read -ra CONFIG_PAIRS <<< "${NODES_CONFIG[$node_id]}"
    for pair in "${CONFIG_PAIRS[@]}"; do
        IFS=':' read -r key value <<< "$pair"
        if [[ "$key" == "always_available" ]] && [[ "$value" == "true" ]]; then
            always_available=true
            break
        fi
    done
    
    # Check node status
    if response=$(timeout 5 openclaw nodes status "$node_id" 2>&1); then
        if [[ "$response" =~ [Oo][Nn][Ll][Ii][Nn][Ee] ]] || [[ "$response" =~ [Aa][Cc][Tt][Ii][Vv][Ee] ]]; then
            is_online=true
        fi
    else
        if [[ "$?" == "124" ]]; then
            response="Timeout"
        else
            response="Error: $response"
        fi
    fi
    
    # Truncate response to 100 chars
    if [[ ${#response} -gt 100 ]]; then
        response="${response:0:100}"
    fi
    
    echo "$node_id|$is_online|$always_available|$response"
}

print_table() {
    local nodes_status=("$@")
    
    echo ""
    printf "%s\n" "$(printf '=%.0s' {1..90})"
    printf "%-8s %-12s %-12s %-10s %-10s %s\n" "Node" "Status" "Verfügbar" "Kapazität" "Priorität" "Gerät/Beschreibung"
    printf "%s\n" "$(printf '=%.0s' {1..90})"
    
    for line in "${nodes_status[@]}"; do
        IFS='|' read -r node_id is_online available response <<< "$line"
        
        # Parse config
        declare -A config=()
        IFS=',' read -ra CONFIG_PAIRS <<< "${NODES_CONFIG[$node_id]}"
        for pair in "${CONFIG_PAIRS[@]}"; do
            IFS=':' read -r key value <<< "$pair"
            config["$key"]="$value"
        done
        
        local status_icon="🔴 Offline"
        [[ "$is_online" == "true" ]] && status_icon="🟢 Online"
        
        local avail_icon="📱 Bedingt"
        [[ "$available" == "true" ]] && avail_icon="✅ Immer"
        
        local capacity="${config[capacity]:-unknown}"
        local priority="${config[priority]:--}"
        local device="${config[device]:-${config[description]:-}}"
        
        printf "%-8s %-12s %-12s %-10s %-10s %s\n" "$node_id" "$status_icon" "$avail_icon" "$capacity" "$priority" "$device"
    done
    
    printf "%s\n" "$(printf '=%.0s' {1..90})"
    echo ""
    echo "Geprüft am: $(date '+%Y-%m-%d %H:%M:%S')"
}

print_json() {
    local nodes_status=("$@")
    local timestamp=$(date -Iseconds)
    
    echo "{"
    echo "  \"timestamp\": \"$timestamp\","
    echo "  \"nodes\": {"
    
    local first_node=true
    for line in "${nodes_status[@]}"; do
        if [[ "$first_node" != "true" ]]; then
            echo ","
        fi
        first_node=false
        
        IFS='|' read -r node_id is_online available response <<< "$line"
        
        echo "    \"$node_id\": {"
        echo "      \"status\": {"
        echo "        \"id\": \"$node_id\","
        echo "        \"online\": $is_online,"
        echo "        \"available\": $available,"
        echo "        \"response\": \"$(echo "$response" | sed 's/"/\\"/g')\""
        echo "      },"
        echo "      \"config\": {"
        
        # Parse config
        declare -A config=()
        IFS=',' read -ra CONFIG_PAIRS <<< "${NODES_CONFIG[$node_id]}"
        local first_item=true
        for pair in "${CONFIG_PAIRS[@]}"; do
            if [[ "$first_item" != "true" ]]; then
                echo ","
            fi
            first_item=false
            
            IFS=':' read -r key value <<< "$pair"
            echo -n "        \"$key\": "
            if [[ "$value" =~ ^[0-9]+$ ]]; then
                echo -n "$value"
            else
                echo -n "\"$value\""
            fi
        done
        echo ""
        echo "      }"
        echo "    }"
    done
    
    echo ""
    echo "  }"
    echo "}"
}

save_to_file() {
    local nodes_status=("$@")
    local filename="$1"
    shift
    local timestamp=$(date -Iseconds)
    
    {
        echo "{"
        echo "  \"timestamp\": \"$timestamp\","
        echo "  \"nodes\": {"
        
        local first_node=true
        for line in "${nodes_status[@]}"; do
            if [[ "$first_node" != "true" ]]; then
                echo ","
            fi
            first_node=false
            
            IFS='|' read -r node_id is_online available response <<< "$line"
            echo "    \"$node_id\": {"
            echo "      \"id\": \"$node_id\","
            echo "      \"online\": $is_online,"
            echo "      \"available\": $available,"
            echo "      \"response\": \"$(echo "$response" | sed 's/"/\\"/g')\""
            echo "    }"
        done
        
        echo ""
        echo "  }"
        echo "}"
    } > "$filename"
}

main() {
    local format="table"
    local save_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --format|-f)
                format="$2"
                shift 2
                ;;
            --save|-s)
                save_file="$2"
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
    local sorted_nodes=($(printf '%s\n' "${!NODES_CONFIG[@]}" | sort))
    
    for node_id in "${sorted_nodes[@]}"; do
        echo -n "  → $node_id... "
        local status_line=$(check_node_status "$node_id")
        nodes_status+=("$status_line")
        IFS='|' read -r _ is_online _ _ <<< "$status_line"
        if [[ "$is_online" == "true" ]]; then
            echo "✓"
        else
            echo "✗"
        fi
    done
    
    # Ausgabe
    if [[ "$format" == "table" ]]; then
        print_table "${nodes_status[@]}"
    else
        print_json "${nodes_status[@]}"
    fi
    
    # Speichern
    if [[ -n "$save_file" ]]; then
        save_to_file "${nodes_status[@]}" "$save_file"
        echo ""
        echo "💾 Gespeichert: $save_file"
    fi
    
    # Zusammenfassung
    local online_count=0
    for line in "${nodes_status[@]}"; do
        IFS='|' read -r _ is_online _ _ <<< "$line"
        if [[ "$is_online" == "true" ]]; then
            ((online_count++))
        fi
    done
    
    echo ""
    echo "📊 Zusammenfassung: $online_count/${#nodes_status[@]} Nodes online"
}

main "$@"
