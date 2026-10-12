#!/usr/bin/env bash
# tiktok-check-profile.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Basic TikTok LIVE profile checker.
#
# Scopes every signal to the requested account and ignores unrelated sidebar
# LIVE labels. This profile-only checker does not classify restricted LIVE;
# use the enhanced checker or dispatcher for that distinction.
#
# Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
# failure, 75 = overloaded before startup.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_FILE="${SCRIPT_DIR}/tiktok-common.sh"

if [[ ! -f "$COMMON_FILE" ]]; then
    echo '{"error":true,"status":"dependency_missing","message":"tiktok-common.sh not found"}' >&2
    exit 2
fi

# shellcheck source=./tiktok-common.sh
source "$COMMON_FILE"

# Check arguments
if [[ $# -ne 1 ]]; then
    echo 'Usage: tiktok-check-profile.sh <username>' >&2
    echo '{"error":true,"message":"Usage: tiktok-check-profile.sh <username>"}' >&2
    exit 64
fi

username="$1"
normalize_username "$username" || {
    echo 'Usage: tiktok-check-profile.sh <username>' >&2
    echo '{"error":true,"message":"Invalid username format"}' >&2
    exit 64
}
username="$normalized_username"

# Enforce load limit
enforce_load_limit "curl_basic"

# Check dependencies
if ! command -v curl >/dev/null 2>&1; then
    echo '{"error":true,"status":"dependency_missing","method":"curl_basic","message":"curl not available"}' >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo '{"error":true,"status":"dependency_missing","method":"curl_basic","message":"jq not available"}' >&2
    exit 2
fi

# Function to generate JSON error response
generate_error_json() {
    local message="$1"
    local status="${2:-technical_error}"
    cat <<EOF
{
  "error": true,
  "status": "$status",
  "message": "$message",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Main checking function
check_live_status() {
    local username="$1"
    local url="https://www.tiktok.com/@${username}"
    local temp_dir
    local html_file
    local response_code
    
    temp_dir=$(mktemp -d)
    html_file="${temp_dir}/profile.html"
    
    # Cleanup function
    cleanup() {
        rm -rf "$temp_dir"
    }
    trap cleanup EXIT
    
    # Fetch profile page with proper headers
    if ! curl -s -L \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -H "Connection: keep-alive" \
        -H "Upgrade-Insecure-Requests: 1" \
        --compressed \
        --connect-timeout 30 \
        --max-time 60 \
        -w "%{http_code}" \
        -o "$html_file" \
        "$url" > "${temp_dir}/response_code.txt"; then
        
        generate_error_json "Failed to fetch profile page" >&2
        return 1
    fi
    
    response_code=$(cat "${temp_dir}/response_code.txt")
    
    # Check HTTP response code
    if [[ "$response_code" -eq 404 ]]; then
        echo "{\"username\":\"$username\",\"isLive\":false,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"indicators\":{\"reason\":\"Profile not found\"}}" | jq .
        return 1
    elif [[ "$response_code" -ge 400 ]]; then
        generate_error_json "HTTP error $response_code when fetching profile" >&2
        return 1
    fi
    
    # Check if file was downloaded successfully
    if [[ ! -f "$html_file" ]] || [[ ! -s "$html_file" ]]; then
        generate_error_json "Empty or missing HTML response" >&2
        return 1
    fi
    
    # Save debug screenshot if DEBUG=1
    if [[ "${DEBUG:-}" == "1" ]]; then
        cp "$html_file" "/tmp/tiktok-${username}.html" 2>/dev/null || true
    fi
    
    # Check for LIVE indicators in the HTML content
    
    # Method 1: Check for live links specific to this user
    local live_link_pattern="/@${username}/live"
    local has_live_link=false
    if grep -qi "href=[\"'][^\"']*$live_link_pattern" "$html_file" 2>/dev/null; then
        has_live_link=true
    fi
    
    # Method 2: Check for LIVE badges/text
    local live_badge_patterns=(
        ">LIVE<"
        "class=\"[^\"]*LiveBadge[^\"]*\""
        "data-e2e=\"live-icon\""
        "class=\"[^\"]*live-indicator[^\"]*\""
    )
    
    local live_icon_visible=false
    local live_badge_visible=false
    local live_indicator_visible=false
    
    for pattern in "${live_badge_patterns[@]}"; do
        if grep -qi "$pattern" "$html_file" 2>/dev/null; then
            if [[ "$pattern" == *"live-icon"* ]] || [[ "$pattern" == *"live-indicator"* ]]; then
                live_icon_visible=true
                live_indicator_visible=true
            else
                live_badge_visible=true
            fi
        fi
    done
    
    # Method 3: Check for CSS classes indicating live state
    local css_live_patterns=(
        "live-streaming"
        "live-status"
        "on-live"
        "live-now"
    )
    
    local has_css_live=false
    for pattern in "${css_live_patterns[@]}"; do
        if grep -qi "class=\"[^\"]*$pattern" "$html_file" 2>/dev/null; then
            has_css_live=true
            break
        fi
    done
    
    # Determine final live status
    local is_live=false
    if [[ "$has_live_link" == true ]] || [[ "$live_icon_visible" == true ]] || [[ "$live_badge_visible" == true ]] || [[ "$live_indicator_visible" == true ]] || [[ "$has_css_live" == true ]]; then
        is_live=true
    fi
    
    # Generate output JSON
    cat <<EOF
{
  "username": "$username",
  "isLive": $is_live,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "indicators": {
    "liveIcon": $live_icon_visible,
    "liveBadge": $live_badge_visible,
    "liveLink": $has_live_link,
    "liveIndicator": $live_indicator_visible,
    "cssLive": $has_css_live
  }
}
EOF
    
    # Return appropriate exit code
    if [[ "$is_live" == true ]]; then
        return 0  # Live
    else
        return 1  # Offline
    fi
}

# Execute main function and handle errors
if ! result=$(check_live_status "$username"); then
    exit 2
fi

echo "$result" | jq . 2>/dev/null || echo "$result"
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    # Check if actually live from the result
    if echo "$result" | jq -r '.isLive' 2>/dev/null | grep -q '^true$'; then
        exit 0
    else
        exit 1
    fi
else
    exit $exit_code
fi
