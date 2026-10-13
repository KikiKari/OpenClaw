#!/usr/bin/env bash
# tiktok-common.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Shared TikTok LIVE safety contract: handle normalization, per-CPU load
# preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
# validation, and normalized extractor statuses.

DEFAULT_MAX_LOAD_PER_CPU=1.5
USERNAME_PATTERN='^[A-Za-z0-9._]\{1,24\}$'
FAILURE_STATUSES=("offline" "restricted" "overloaded" "dependency_missing" "technical_error")

normalizeUsername() {
    local raw="$1"
    local username
    username=$(echo "$raw" | sed 's/^@\+//' | xargs)
    if ! [[ "$username" =~ $USERNAME_PATTERN ]]; then
        echo "Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores" >&2
        return 1
    fi
    echo "$username"
}

loadState() {
    local cpuCount observed maximum
    cpuCount=$(nproc 2>/dev/null || echo 1)
    if [ "$cpuCount" -lt 1 ]; then cpuCount=1; fi
    
    if [ "${TIKTOK_TEST_LOAD_PER_CPU:-}" != "" ]; then
        observed=$(printf "%.6f" "$TIKTOK_TEST_LOAD_PER_CPU" 2>/dev/null) || {
            echo "Invalid TIKTOK_TEST_LOAD_PER_CPU value" >&2
            return 1
        }
    else
        if command -v uptime >/dev/null 2>&1; then
            observed=$(uptime | awk '{print $(NF-2)}' | sed 's/,$//' | awk "{printf \"%.6f\", \$1/$cpuCount}")
        else
            observed=0
        fi
    fi
    
    if [ "${TIKTOK_MAX_LOAD_PER_CPU:-}" != "" ]; then
        maximum=$(printf "%.6f" "$TIKTOK_MAX_LOAD_PER_CPU" 2>/dev/null) || {
            echo "Invalid TIKTOK_MAX_LOAD_PER_CPU value" >&2
            return 1
        }
    else
        maximum=$DEFAULT_MAX_LOAD_PER_CPU
    fi
    
    local overloaded
    if awk "BEGIN {exit !($observed > $maximum)}" 2>/dev/null; then
        overloaded=true
    else
        overloaded=false
    fi
    
    if ! awk "BEGIN {exit !(isfinite($observed) && isfinite($maximum) && $maximum > 0)}" 2>/dev/null; then
        echo "Invalid TikTok load configuration" >&2
        return 1
    fi
    
    echo "$overloaded|$observed|$maximum"
}

enforceLoadLimit() {
    local method="$1"
    local state load_result
    state=$(loadState) || return $?
    IFS='|' read -r overloaded loadPerCpu maximum <<<"$state"
    
    if [ "$overloaded" = "false" ]; then
        return 0
    fi
    
    cat <<EOF >&2
{"status":"overloaded","method":"$method","loadPerCpu":$(printf "%.3f" "$loadPerCpu"),"maximum":$maximum,"message":"Host is overloaded; retry on another node or later"}
EOF
    exit 75
}

liveHrefSelectors() {
    local username="$1"
    local href="/@$username/live"
    echo "a[href=\"$href\"] a[href^=\"$href?\"]"
}

isAllowedStreamUrl() {
    local value="$1"
    local url hostname pathname protocol
    
    # Basic URL parsing using parameter expansion and regex
    if [[ "$value" =~ ^https://([^/]+)(.*)$ ]]; then
        hostname="${BASH_REMATCH[1],,}"
        pathname="${BASH_REMATCH[2],,}"
        protocol="https:"
    else
        return 1
    fi
    
    if [ "$protocol" != "https:" ]; then
        return 1
    fi
    
    if [[ "$pathname" != *.flv* ]]; then
        return 1
    fi
    
    if [[ "$hostname" =~ (^|\.)tiktokcdn(-[a-z0-9-]+)?\.com$ ]]; then
        return 0
    else
        return 1
    fi
}

isSuccessfulStreamResponse() {
    local status="$1"
    local value="$2"
    
    if ! [[ "$status" =~ ^[0-9]+$ ]] || [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
        return 1
    fi
    
    isAllowedStreamUrl "$value"
}

qualityKeyFromUrl() {
    local value="$1"
    local pathname
    
    # Extract pathname from URL-like string
    if [[ "$value" =~ ^https?://[^/]+(/.*)$ ]]; then
        pathname="${BASH_REMATCH[1],,}"
    else
        echo ""
        return 0
    fi
    
    # Order matters: longer keys first so _uhd_60 never matches as hd_60/hd
    case "$pathname" in
        *_uhd_60.*)
            echo "uhd_60"
            ;;
        *hd_60.*)
            echo "hd_60"
            ;;
        *origin.*)
            echo "origin"
            ;;
        *hd.*)
            echo "hd"
            ;;
        *sd.*)
            echo "sd"
            ;;
        *ld.*)
            echo "ld"
            ;;
        *ao.*)
            echo "ao"
            ;;
        *)
            echo ""
            ;;
    esac
}

normalizeExtractorResult() {
    local json_input="$1"
    local method="$2"
    local username="$3"
    
    # Check if input is valid JSON object
    if ! jq -e 'type == "object"' <<<"$json_input" >/dev/null 2>&1; then
        cat <<EOF
{"success":false,"status":"technical_error","method":"$method","username":"$username","message":"invalid extractor result"}
EOF
        return 0
    fi
    
    local success
    success=$(jq -r '.success' <<<"$json_input" 2>/dev/null)
    
    if [ "$success" = "true" ]; then
        local status url
        status=$(jq -r '.status // empty' <<<"$json_input" 2>/dev/null)
        url=$(jq -r '.url // empty' <<<"$json_input" 2>/dev/null)
        
        if [ "$status" = "live" ] && isAllowedStreamUrl "$url"; then
            jq ". + {\"success\":true,\"status\":\"live\"}" <<<"$json_input"
            return 0
        else
            cat <<EOF
{"success":false,"status":"technical_error","method":"$method","username":"$username","message":"invalid extractor result"}
EOF
            return 0
        fi
    elif [ "$success" = "false" ]; then
        local current_status current_method current_username
        current_status=$(jq -r '.status // "technical_error"' <<<"$json_input" 2>/dev/null)
        current_method=$(jq -r '.method // "'"$method"'"' <<<"$json_input" 2>/dev/null)
        current_username=$(jq -r '.username // "'"$username"'"' <<<"$json_input" 2>/dev/null)
        
        # Validate status against allowed failure statuses
        local valid_status="technical_error"
        for s in "${FAILURE_STATUSES[@]}"; do
            if [ "$s" = "$current_status" ]; then
                valid_status="$current_status"
                break
            fi
        done
        
        # Build result without url, streams, allUrls
        local base_result
        base_result=$(jq '{
            "success": false,
            "status": "'"$valid_status"'",
            "method": "'"$current_method"'",
            "username": "'"$current_username"'"
        }' <<<"$json_input")
        
        echo "$base_result"
        return 0
    else
        cat <<EOF
{"success":false,"status":"technical_error","method":"$method","username":"$username","message":"invalid extractor result"}
EOF
        return 0
    fi
}

classifyFinalFailure() {
    local results_json="$1"
    local status_list=()
    
    # Extract unique statuses from results
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            status_list+=("$line")
        fi
    done < <(jq -r 'map(.status) | unique | .[]' <<<"$results_json" 2>/dev/null | grep -F -f <(printf '%s\n' "${FAILURE_STATUSES[@]}"))
    
    # Priority order check
    for priority in "overloaded" "restricted" "technical_error" "offline" "dependency_missing"; do
        for s in "${status_list[@]}"; do
            if [ "$s" = "$priority" ]; then
                echo "$priority"
                return 0
            fi
        done
    done
    
    echo "technical_error"
}

exitCodeForResult() {
    local result_json="$1"
    local success status
    
    success=$(jq -r '.success // empty' <<<"$result_json" 2>/dev/null)
    status=$(jq -r '.status // empty' <<<"$result_json" 2>/dev/null)
    
    if [ "$success" = "true" ] && [ "$status" = "live" ]; then
        return 0
    elif [ "$status" = "overloaded" ]; then
        return 75
    elif [ "$status" = "offline" ] || [ "$status" = "restricted" ]; then
        return 1
    else
        return 2
    fi
}

classifyDirectLiveState() {
    local username="$1"
    local currentPath="$2"
    local title="$3"
    local bodyText="$4"
    local successfulStreamResponse="$5"
    
    local expectedPath="/@$username/live"
    
    if [ "$currentPath" != "$expectedPath" ]; then
        cat <<EOF
{"status":"offline","reason":"target live page redirected"}
EOF
        return 0
    fi
    
    if [ "$successfulStreamResponse" = "true" ]; then
        cat <<EOF
{"status":"live","reason":"successful TikTok CDN stream response"}
EOF
        return 0
    fi
    
    local normalizedBody normalizedTitle accountLiveTitle
    normalizedBody=$(echo "$bodyText" | tr -s '[:space:]' ' ' | tr '[:upper:]' '[:lower:]')
    normalizedTitle=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    accountLiveTitle=$(echo "$normalizedTitle" | grep -i "(@${username,,}) is live" >/dev/null && echo "true" || echo "false")
    
    local endedMarkers=(
        "live has ended"
        "das live ist beendet"
        "live wurde beendet"
        "dieses live ist beendet"
        "stream has ended"
    )
    
    local marker
    for marker in "${endedMarkers[@]}"; do
        if echo "$normalizedBody" | grep -i "$marker" >/dev/null; then
            cat <<EOF
{"status":"offline","reason":"target live page reports ended stream"}
EOF
            return 0
        fi
    done
    
    local restrictionMarkers=(
        "dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten"
        "melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen"
        "bei tiktok anmelden"
        "melde dich an für das volle live-erlebnis"
        "melde dich an für das vollständige erlebnis"
        "this live may contain content that could be uncomfortable"
        "log in to tiktok"
        "log in for the full live experience"
        "mature content"
        "age-restricted"
        "viewer discretion"
    )
    
    if [ "$accountLiveTitle" = "true" ]; then
        for marker in "${restrictionMarkers[@]}"; do
            if echo "$normalizedBody" | grep -i "$marker" >/dev/null; then
                cat <<EOF
{"status":"restricted","reason":"target live page requires authentication"}
EOF
                return 0
            fi
        done
        
        cat <<EOF
{"status":"restricted","reason":"target is live but no accessible media response was available"}
EOF
        return 0
    fi
    
    cat <<EOF
{"status":"offline","reason":"no account-specific live signal"}
EOF
}

forcedOffline() {
    local method="$1"
    local username="$2"
    
    if [ "${TIKTOK_TEST_OFFLINE:-}" != "1" ]; then
        return 1
    fi
    
    cat <<EOF >&2
{"success":false,"status":"offline","method":"$method","username":"$username","message":"forced offline test mode"}
EOF
    return 0
}
