#!/usr/bin/env bash
# tiktok-get-stream.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# TikTok Stream URL Extractor
# Führt zuerst den profilgebundenen Status-Checker aus.
# Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
# Offline wird keine Stream-URL ausgegeben.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly USERNAME_RAW="${1:-}"
readonly USERNAME="${USERNAME_RAW#@}"

if [[ -z "$USERNAME" ]]; then
    echo "Usage: $0 <username>" >&2
    exit 1
fi

reject_busy_node() {
    local limit="${TIKTOK_MAX_LOAD_PER_CPU:-}"
    if [[ -z "$limit" ]] || ! [[ "$limit" =~ ^[0-9]+\.?[0-9]*$ ]] || (( $(echo "$limit <= 0" | bc -l) )); then
        return
    fi

    local cpu_count
    cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
    cpu_count=$((cpu_count > 0 ? cpu_count : 1))

    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

    local normalized_load
    normalized_load=$(echo "scale=2; $load_avg / $cpu_count" | bc -l)

    if (( $(echo "$normalized_load > $limit" | bc -l) )); then
        echo "NODE_BUSY normalizedLoad=$normalized_load limit=$limit" >&2
        exit 75
    fi
}

verify_live_status() {
    local user="$1"
    local checker_path="$SCRIPT_DIR/tiktok-check-profile.js"
    local output
    local exit_code=0

    if [[ ! -f "$checker_path" ]]; then
        echo '{"isLive":false,"error":"Checker script not found"}' >&2
        return 1
    fi

    output=$(timeout 60s node "$checker_path" "$user" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 124 ]]; then
        echo '{"isLive":false,"error":"Timeout checking live status"}' >&2
        return 1
    fi

    if [[ -n "$output" ]]; then
        if echo "$output" | jq -e '.isLive == true' >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

get_stream_url() {
    local user="$1"
    
    if ! verify_live_status "$user"; then
        jq -n --arg username "$user" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
            username: $username,
            isLive: false,
            error: "User is not currently live.",
            timestamp: $timestamp
        }' >&2
        return 1
    fi

    # Create temporary files
    local temp_dir
    temp_dir=$(mktemp -d)
    local har_file="$temp_dir/network.har"
    local log_file="$temp_dir/browser.log"
    
    trap 'rm -rf "$temp_dir"' EXIT

    # Start browser with HAR recording
    local browser_pid
    if ! timeout 90s chrome \
        --headless=new \
        --disable-gpu \
        --no-sandbox \
        --disable-background-timer-throttling \
        --disable-renderer-backgrounding \
        --disable-backgrounding-occluded-windows \
        --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --enable-logging=stderr \
        --log-level=0 \
        --dump-dom \
        --virtual-time-budget=30000 \
        "https://www.tiktok.com/@$user/live" \
        2>"$log_file" >"$har_file" & browser_pid=$!
    then
        jq -n --arg msg "Failed to start browser" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
            error: true,
            message: $msg,
            timestamp: $timestamp
        }' >&2
        return 1
    fi

    # Wait for browser to complete
    wait "$browser_pid" || {
        jq -n --arg msg "Browser process failed" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
            error: true,
            message: $msg,
            timestamp: $timestamp
        }' >&2
        return 1
    }

    # Extract URLs from HAR file or logs
    local urls=()
    if [[ -f "$har_file" ]] && [[ -s "$har_file" ]]; then
        # Try to extract FLV URLs from HAR content
        mapfile -t urls < <(grep -o 'https[^"]*\.flv\|https[^"]*pull-flv[^"]*' "$har_file" 2>/dev/null | sort -u)
    fi
    
    # If no URLs found in HAR, check log file
    if [[ ${#urls[@]} -eq 0 ]] && [[ -f "$log_file" ]]; then
        mapfile -t urls < <(grep -o 'https[^ ]*\.flv\|https[^ ]*pull-flv[^ ]*' "$log_file" 2>/dev/null | sort -u)
    fi

    if [[ ${#urls[@]} -gt 0 ]]; then
        # Create JSON structure for streams
        local streams_json=""
        local first=true
        for url in "${urls[@]}"; do
            if [[ -n "$url" ]]; then
                if [[ "$first" == true ]]; then
                    streams_json="{\"url\":\"$url\",\"type\":\"media\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
                    first=false
                else
                    streams_json="$streams_json,{\"url\":\"$url\",\"type\":\"media\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
                fi
            fi
        done
        
        if [[ -n "$streams_json" ]]; then
            local vlc_cmd="vlc \"${urls[0]}\""
            echo "{"
            echo "  \"username\": \"$user\","
            echo "  \"isLive\": true,"
            echo "  \"streamCount\": $(echo "$streams_json" | tr ',' '\n' | wc -l),"
            echo "  \"streams\": [$streams_json],"
            echo "  \"vlcCommand\": \"$vlc_cmd\","
            echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
            echo "}"
            return 0
        fi
    fi

    jq -n --arg username "$user" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
        username: $username,
        isLive: false,
        error: "No stream URLs found - user may not be live",
        timestamp: $timestamp
    }' >&2
    return 1
}

reject_busy_node

if get_stream_url "$USERNAME"; then
    exit 0
else
    exit 1
fi
