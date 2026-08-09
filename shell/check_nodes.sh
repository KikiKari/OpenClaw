#!/usr/bin/env bash
# check_nodes.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Node-Status Checker - Prüft Verfügbarkeit aller Nodes

# Node-Konfiguration (sollte aus config file geladen werden)
declare -A NODES=(
    [node1]="always_available:true,capacity:medium,priority:2,description:Gateway-Master"
    [node2]="always_available:true,capacity:medium,priority:3,description:Stable Worker"
    [node3]="always_available:false,capacity:medium,priority:4,description:Bald verfügbar (nach Reorganisation)"
    [node5]="always_available:false,capacity:low,priority:5,device:Redmi Note 11S,description:Mobile (bei Internet verfügbar)"
    [node7]="always_available:true,capacity:high,priority:1,description:Docker Hauptarbeitspferd (bald verfügbar)"
)

# Globale Variablen
FORMAT="table"
SAVE_FILE=""

# Funktion zum Parsen der Node-Konfiguration
parse_config() {
    local node_id="$1"
    local config="${NODES[$node_id]}"
    local key_value
    declare -A parsed_config

    IFS=',' read -ra key_values <<< "$config"
    for kv in "${key_values[@]}"; do
        IFS=':' read -r key value <<< "$kv"
        parsed_config["$key"]="$value"
    done

    echo "${parsed_config[@]}"
}

# Funktion zum Abrufen eines Konfigurationswerts
get_config_value() {
    local node_id="$1"
    local key="$2"
    local default="$3"
    local config="${NODES[$node_id]}"
    
    # Extrahiere den Wert für den gegebenen Schlüssel
    local pattern="$key:"
    if [[ "$config" == *"$pattern"* ]]; then
        local temp="${config##*$pattern}"
        echo "${temp%%,*}"
    else
        echo "$default"
    fi
}

# Prüft Status eines einzelnen Nodes
check_node_status() {
    local node_id="$1"
    local stdout=""
    local returncode=0
    local is_online=false
    local response="No response"
    local always_available
    always_available=$(get_config_value "$node_id" "always_available" "false")

    # Führe den Befehl aus und fange Ausgabe und Returncode ein
    if stdout=$(timeout 5 openclaw nodes status "$node_id" 2>&1); then
        returncode=$?
    else
        returncode=$?
    fi

    # Prüfe ob der Node online ist
    if [[ $returncode -eq 0 ]] && (echo "$stdout" | grep -qi "online\|active"); then
        is_online=true
    fi

    # Kürze die Antwort auf maximal 100 Zeichen
    if [[ ${#stdout} -gt 100 ]]; then
        response="${stdout:0:100}"
    elif [[ -n "$stdout" ]]; then
        response="$stdout"
    fi

    # Gebe das Ergebnis als assoziatives Array zurück (serialisiert)
    echo "id:$node_id,online:$is_online,available:$always_available,response:${response//,/\\,}"
}

# Gibt Node-Status als Tabelle aus
print_table() {
    local nodes_status=("$@")
    printf "\n%s\n" "$(printf "%0.s=" $(seq 1 90))"
    printf "%-8s %-12s %-12s %-10s %-10s %s\n" "Node" "Status" "Verfügbar" "Kapazität" "Priorität" "Gerät/Beschreibung"
    printf "%s\n" "$(printf "%0.s=" $(seq 1 90))"

    local status_entry
    for status_serialized in "${nodes_status[@]}"; do
        # Deserialisiere den Status-Eintrag
        declare -A status
        IFS=',' read -ra pairs <<< "$status_serialized"
        for pair in "${pairs[@]}"; do
            # Behandlung von escaped Kommas
            pair="${pair//\\,/,}"
            IFS=':' read -r key value <<< "$pair"
            status["$key"]="$value"
        done
        
        local node_id="${status[id]}"
        local config_capacity
        local config_priority
        local config_device
        local config_description
        config_capacity=$(get_config_value "$node_id" "capacity" "unknown")
        config_priority=$(get_config_value "$node_id" "priority" "-")
        config_device=$(get_config_value "$node_id" "device" "")
        config_description=$(get_config_value "$node_id" "description" "")

        local status_icon="🔴 Offline"
        [[ "${status[online]}" == "true" ]] && status_icon="🟢 Online"
        
        local avail_icon="📱 Bedingt"
        [[ "${status[available]}" == "true" ]] && avail_icon="✅ Immer"
        
        local device_info="$config_device"
        [[ -z "$device_info" ]] && device_info="$config_description"

        printf "%-8s %-12s %-12s %-10s %-10s %s\n" \
            "$node_id" "$status_icon" "$avail_icon" "$config_capacity" "$config_priority" "$device_info"
    done

    printf "%s\n" "$(printf "%0.s=" $(seq 1 90))"
    printf "\nGeprüft am: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
}

# Gibt Node-Status als JSON aus
print_json() {
    local nodes_status=("$@")
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    echo "{"
    echo "  \"timestamp\": \"$timestamp\","
    echo "  \"nodes\": {"
    
    local first_node=true
    local status_serialized
    for status_serialized in "${nodes_status[@]}"; do
        # Deserialisiere den Status-Eintrag
        declare -A status
        IFS=',' read -ra pairs <<< "$status_serialized"
        for pair in "${pairs[@]}"; do
            # Behandlung von escaped Kommas
            pair="${pair//\\,/,}"
            IFS=':' read -r key value <<< "$pair"
            status["$key"]="$value"
        done
        
        local node_id="${status[id]}"
        local config="${NODES[$node_id]}"
        
        if [[ "$first_node" != true ]]; then
            echo "    ,"
        fi
        first_node=false
        
        echo "    \"$node_id\": {"
        echo "      \"status\": {"
        echo "        \"id\": \"${status[id]}\","
        echo "        \"online\": ${status[online]},"
        echo "        \"available\": ${status[available]},"
        echo "        \"response\": \"${status[response]}\""
        echo "      },"
        echo "      \"config\": {"
        
        # Parse config und gib sie als JSON aus
        local first_item=true
        IFS=',' read -ra items <<< "$config"
        local item
        for item in "${items[@]}"; do
            # Behandlung von escaped Kommas
            item="${item//\\,/,}"
            IFS=':' read -r key value <<< "$item"
            
            if [[ "$first_item" != true ]]; then
                echo "        ,"
            fi
            first_item=false
            
            # Bestimme ob der Wert ein String oder Boolean/Number ist
            if [[ "$value" == "true" || "$value" == "false" || "$value" =~ ^[0-9]+$ ]]; then
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

# Speichert die Ausgabe in eine Datei
save_to_file() {
    local save_path="$1"
    local nodes_status=("${@:2}")
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    
    {
        echo "{"
        echo "  \"timestamp\": \"$timestamp\","
        echo "  \"nodes\": {"
        
        local first=true
        local status_serialized
        for status_serialized in "${nodes_status[@]}"; do
            # Deserialisiere den Status-Eintrag
            declare -A status
            IFS=',' read -ra pairs <<< "$status_serialized"
            for pair in "${pairs[@]}"; do
                # Behandlung von escaped Kommas
                pair="${pair//\\,/,}"
                IFS=':' read -r key value <<< "$pair"
                status["$key"]="$value"
            done
            
            local node_id="${status[id]}"
            
            if [[ "$first" != true ]]; then
                echo "    ,"
            fi
            first=false
            
            echo "    \"$node_id\": {"
            echo "      \"id\": \"${status[id]}\","
            echo "      \"online\": ${status[online]},"
            echo "      \"available\": ${status[available]},"
            echo "      \"response\": \"${status[response]}\""
            echo "    }"
        done
        echo "  }"
        echo "}"
    } > "$save_path"
    
    printf "\n💾 Gespeichert: %s\n" "$save_path"
}

# Hauptfunktion
main() {
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -s|--save)
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
    local sorted_keys=($(printf '%s\n' "${!NODES[@]}" | sort))
    local node_id
    for node_id in "${sorted_keys[@]}"; do
        printf "  → %s... " "$node_id"
        local status_result
        status_result=$(check_node_status "$node_id")
        nodes_status+=("$status_result")
        
        # Prüfe ob der Node online ist
        if [[ "$status_result" == *"online:true"* ]]; then
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
        save_to_file "$SAVE_FILE" "${nodes_status[@]}"
    fi

    # Zusammenfassung
    local online_count=0
    local status_serialized
    for status_serialized in "${nodes_status[@]}"; do
        if [[ "$status_serialized" == *"online:true"* ]]; then
            ((online_count++))
        fi
    done
    printf "\n📊 Zusammenfassung: %d/%d Nodes online\n" "$online_count" "${#nodes_status[@]}"
}

# Skript ausführen
main "$@"
