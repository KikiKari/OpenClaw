#!/usr/bin/env bash
# tiktok-check-profile.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# TikTok Live Status Checker
# Prüft ausschließlich profilgebundene Live-Indikatoren.
# Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
# Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
# via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).

# Prüfe ob curl und jq installiert sind
if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    echo '{"error":true,"message":"curl and jq are required"}' >&2
    exit 1
fi

# Username aus Argumenten holen und normalisieren
if [[ $# -eq 0 ]]; then
    echo '{"error":true,"message":"Usage: tiktok-check-profile.sh <username>"}' >&2
    exit 1
fi

username="${1#@}"
if [[ -z "$username" ]]; then
    echo '{"error":true,"message":"Username must not be empty"}' >&2
    exit 1
fi

# Funktion zur Lastprüfung
reject_busy_node() {
    local limit="${TIKTOK_MAX_LOAD_PER_CPU:-}"
    if [[ -z "$limit" ]] || ! [[ "$limit" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$limit <= 0" | bc -l) )); then
        return 0
    fi

    local cpu_count
    cpu_count=$(nproc 2>/dev/null || echo 1)
    cpu_count=$((cpu_count > 0 ? cpu_count : 1))
    
    local load_avg
    load_avg=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || uptime | awk -F'load averages?:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    load_avg=${load_avg:-0}
    
    local normalized_load
    normalized_load=$(echo "scale=2; $load_avg / $cpu_count" | bc -l)
    
    if (( $(echo "$normalized_load > $limit" | bc -l) )); then
        echo "{\"error\":true,\"message\":\"NODE_BUSY normalizedLoad=$normalized_load limit=$limit\"}" >&2
        exit 75
    fi
}

reject_busy_node

# Hauptfunktion zur Live-Status-Prüfung
check_live_status() {
    local user="$1"
    local url="https://www.tiktok.com/@$user"
    local temp_dir
    temp_dir=$(mktemp -d)
    local html_file="$temp_dir/page.html"
    local headers_file="$temp_dir/headers.txt"
    local cookies_file="$temp_dir/cookies.txt"
    
    # Cleanup-Funktion
    cleanup() {
        rm -rf "$temp_dir"
    }
    trap cleanup EXIT
    
    # User-Agent setzen
    local user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    # Seite herunterladen
    if ! curl -s -L \
        -H "User-Agent: $user_agent" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -H "Connection: keep-alive" \
        -H "Upgrade-Insecure-Requests: 1" \
        --cookie-jar "$cookies_file" \
        --cookie "$cookies_file" \
        -D "$headers_file" \
        -o "$html_file" \
        "$url"; then
        echo "{\"error\":true,\"message\":\"Failed to fetch profile page\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >&2
        return 1
    fi
    
    # Warten für JavaScript-Ladezeit
    sleep 3
    
    # HTML parsen und Indikatoren suchen
    local content
    content=$(cat "$html_file")
    
    # Indikatoren prüfen
    local live_icon=false
    local live_badge=false
    local has_live_border=false
    local has_live_link=false
    local live_indicator=false
    
    # Method 1: data-e2e="live-icon"
    if [[ "$content" == *"data-e2e=\"live-icon\""* ]]; then
        live_icon=true
    fi
    
    # Method 2: LIVE text/badge
    if echo "$content" | grep -qiE "(<[^>]*>[[:space:]]*LIVE[[:space:]]*</|\"text\":\"LIVE\")"; then
        live_badge=true
    fi
    
    # Method 3: Roter Rahmen (vereinfacht)
    if echo "$content" | grep -qiE "(border-color.*255|border-color.*red|border-color.*fe2c|box-shadow.*255|box-shadow.*254)"; then
        has_live_border=true
    fi
    
    # Method 4: Live-Link
    if [[ "$content" == *"/@$user/live"* ]]; then
        has_live_link=true
    fi
    
    # Method 5: Live-Indikator-Klassen
    if echo "$content" | grep -qiE "(live-indicator|LiveBadge)"; then
        live_indicator=true
    fi
    
    local is_live=false
    if [[ "$live_icon" == true ]] || [[ "$live_badge" == true ]] || [[ "$has_live_border" == true ]] || [[ "$has_live_link" == true ]] || [[ "$live_indicator" == true ]]; then
        is_live=true
    fi
    
    # Ergebnis ausgeben
    cat <<EOF
{
  "username": "$user",
  "isLive": $is_live,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "indicators": {
    "liveIcon": $live_icon,
    "liveBadge": $live_badge,
    "liveBorder": $has_live_border,
    "liveLink": $has_live_link,
    "liveIndicator": $live_indicator
  }
}
EOF
    
    # Rückgabe des Status
    if [[ "$is_live" == true ]]; then
        return 0
    else
        return 1
    fi
}

# Hauptprogramm ausführen
if check_live_status "$username"; then
    exit 0
else
    exit 1
fi
