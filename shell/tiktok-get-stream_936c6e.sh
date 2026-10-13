#!/usr/bin/env bash
# tiktok-get-stream.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Basic TikTok LIVE URL extractor.
#
# Accepts only observed HTTPS TikTok-CDN .flv responses with HTTP 2xx.
# Success writes one naked URL to stdout. Offline/no URL exits 1, dependency
# or technical failure exits 2, and preflight overload exits 75.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_LIB="$SCRIPT_DIR/tiktok-common.bash"

if [[ ! -f "$COMMON_LIB" ]]; then
    echo '{"error":true,"status":"dependency_missing","method":"bash_network_basic","message":"Common library missing","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
    exit 2
fi

# shellcheck source=./tiktok-common.bash
source "$COMMON_LIB"

# Check arguments
if [[ $# -lt 1 ]]; then
    echo 'Usage: tiktok-get-stream.sh <username>' >&2
    echo 'Invalid argument count' >&2
    exit 64
fi

username=$(normalize_username "$1")
enforce_load_limit "bash_network_basic"
json_output=false
for arg in "$@"; do
    if [[ "$arg" == "--json" ]]; then
        json_output=true
        break
    fi
done

if forced_offline "bash_network_basic" "$username"; then
    exit 1
fi

# Check dependencies
if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo '{"error":true,"status":"dependency_missing","method":"bash_network_basic","message":"curl or jq missing","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
    exit 2
fi

# Create temporary files
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
cookies_file="$temp_dir/cookies.txt"
headers_file="$temp_dir/headers.txt"
html_file="$temp_dir/page.html"

# User-Agent
readonly USER_AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

# Fetch live page
url="https://www.tiktok.com/@${username}/live"
http_code=$(curl -s -L -D "$headers_file" -c "$cookies_file" -o "$html_file" \
    -w "%{http_code}" \
    -H "User-Agent: $USER_AGENT" \
    --connect-timeout 30 \
    --max-time 90 \
    "$url")

if [[ "$http_code" -ge 400 ]]; then
    echo '{"success":false,"status":"offline","method":"bash","username":"'"$username"'","isLive":false,"error":"HTTP '"$http_code"'","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
    exit 1
fi

# Wait a bit for JS to load and potential redirects
sleep 8

# Extract stream URLs from HTML content
# Look for patterns that might contain stream URLs
stream_urls=()

# Method 1: Look for m3u8/flv URLs directly in HTML
while IFS= read -r line; do
    # Match flv URLs
    if [[ "$line" =~ https://[^[:space:]\"\'\)]*\.flv[^[:space:]\"\'\)]* ]]; then
        matches=$(echo "$line" | grep -oE 'https://[^[:space:]"]*\.flv[^[:space:]"]*' | sort -u)
        while IFS= read -r match; do
            if [[ -n "$match" ]] && is_successful_stream_response 200 "$match"; then
                stream_urls+=("$match")
            fi
        done <<< "$matches"
    fi
    
    # Also check for any CDN stream URLs
    if [[ "$line" =~ (tiktokcdn\.com|tiktok\.com)/.*stream|live] ]]; then
        urls=$(echo "$line" | grep -oE 'https://[^[:space:]"]*(tiktokcdn\.com|tiktok\.com)[^[:space:]"]*' | sort -u)
        while IFS= read -r u; do
            if [[ -n "$u" ]] && [[ "$u" == *.flv* ]] && is_successful_stream_response 200 "$u"; then
                stream_urls+=("$u")
            fi
        done <<< "$urls"
    fi
done < "$html_file"

# Remove duplicates
readarray -t unique_streams < <(printf '%s\n' "${stream_urls[@]}" | sort -u)

if [[ ${#unique_streams[@]} -eq 0 ]]; then
    echo '{"success":false,"status":"offline","method":"bash","username":"'"$username"'","isLive":false,"error":"No stream URLs found - user may not be live","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
    exit 1
fi

# Sort by quality (look for resolution indicators like 720p, 1080p)
# We'll create an array of url-quality pairs
declare -a quality_sorted
for stream_url in "${unique_streams[@]}"; do
    quality=""
    if [[ "$stream_url" =~ ([0-9]+)p ]]; then
        quality="${BASH_REMATCH[1]}"
    else
        quality="0"
    fi
    quality_sorted+=("$quality|$stream_url")
done

# Sort by quality descending
IFS=$'\n' quality_sorted=($(sort -r -n <<<"${quality_sorted[*]}"))
unset IFS

# Rebuild sorted URL list
sorted_urls=()
for item in "${quality_sorted[@]}"; do
    url="${item#*|}"
    sorted_urls+=("$url")
done

# Take top 10
top_urls=()
count=0
for url in "${sorted_urls[@]}"; do
    if (( count >= 10 )); then
        break
    fi
    top_urls+=("$url")
    ((count++))
done

# Output result
best_url="${sorted_urls[0]}"

if [[ "$json_output" == true ]]; then
    # Build JSON manually since we're avoiding external tools beyond jq
    streams_json="["
    first=true
    for u in "${top_urls[@]}"; do
        quality_key=$(quality_key_from_url "$u")
        if [[ "$first" == true ]]; then
            streams_json+="{\"url\":\"$u\",\"quality\":\"$quality_key\"}"
            first=false
        else
            streams_json+=",{\"url\":\"$u\",\"quality\":\"$quality_key\"}"
        fi
    done
    streams_json+="]"
    
    echo "{\"success\":true,\"status\":\"live\",\"method\":\"bash\",\"username\":\"$username\",\"isLive\":true,\"streamCount\":${#top_urls[@]},\"streams\":$streams_json,\"url\":\"$best_url\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
else
    echo "$best_url"
fi

exit 0
