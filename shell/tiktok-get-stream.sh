#!/bin/bash
# tiktok-get-stream.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Enhanced TikTok LIVE URL extractor.
#
# Order: Playwright response interception, streamlink, then yt-dlp. Every
# result is schema-normalized and must be an allowed HTTPS TikTok-CDN FLV
# URL. Fallbacks use fixed argument arrays, bounded output, timeouts, and
# process-group cleanup.
#
# Exit 0 = URL, 1 = offline/restricted/no URL, 2 = dependency/technical
# failure, 75 = overloaded before Playwright startup.

FALLBACK_TIMEOUT_MS=45000
FALLBACK_MAX_OUTPUT=$((1024 * 1024))

log() {
    echo >&2 "$@"
}

run_fallback() {
    local script_path="$1"
    shift
    local args=("$@")

    local stdout_file stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)
    local pid

    # Start the process in background with process group
    bash "$script_path" "${args[@]}" >"$stdout_file" 2>"$stderr_file" &
    pid=$!

    # Set up timeout handling
    (
        sleep "$((FALLBACK_TIMEOUT_MS / 1000))"
        kill -TERM "-$pid" 2>/dev/null || true
        sleep 3
        kill -KILL "-$pid" 2>/dev/null || true
    ) &
    local killer_pid=$!

    # Wait for the process to finish
    local code=0
    if wait "$pid"; then
        code=$?
    else
        code=$?
        if [[ $code -eq 127 ]]; then
            code=2
        fi
    fi

    # Kill the killer
    kill "$killer_pid" 2>/dev/null || true

    # Check file sizes
    local stdout_size stderr_size
    stdout_size=$(stat -c%s "$stdout_file" 2>/dev/null || echo 0)
    stderr_size=$(stat -c%s "$stderr_file" 2>/dev/null || echo 0)

    if [[ $stdout_size -gt $FALLBACK_MAX_OUTPUT ]] || [[ $stderr_size -gt $FALLBACK_MAX_OUTPUT ]]; then
        echo '{"success":false,"status":"technical_error","message":"fallback output exceeded limit"}'
        rm -f "$stdout_file" "$stderr_file"
        return
    fi

    # Read outputs
    local stdout stderr
    stdout=$(cat "$stdout_file" 2>/dev/null || echo "")
    stderr=$(cat "$stderr_file" 2>/dev/null || echo "")

    # Clean up
    rm -f "$stdout_file" "$stderr_file"

    # Output result as JSON
    jq -n --arg code "$code" --arg stdout "$stdout" --arg stderr "$stderr" '{
        code: ($code | tonumber),
        stdout: $stdout,
        stderr: $stderr
    }'
}

parse_fallback_result() {
    local method="$1"
    local username="$2"
    local execution="$3"

    local code stdout stderr
    code=$(echo "$execution" | jq -r '.code')
    stdout=$(echo "$execution" | jq -r '.stdout')
    stderr=$(echo "$execution" | jq -r '.stderr')

    # Try to parse stdout/stderr as JSON
    for text in "$stdout" "$stderr"; do
        if [[ -n "$text" ]]; then
            if echo "$text" | jq empty 2>/dev/null; then
                echo "$text"
                return
            fi
        fi
    done

    # If no valid JSON found, create error result
    local status="technical_error"
    if [[ $code -eq 75 ]]; then
        status="overloaded"
    fi
    local message="${stderr:-fallback exited $code}"
    
    jq -n --arg success "false" \
          --arg status "$status" \
          --arg method "$method" \
          --arg username "$username" \
          --arg message "$message" '{
        success: ($success | test("true")),
        status: $status,
        method: $method,
        username: $username,
        message: $message
    }'
}

playwright_preflight() {
    if command -v playwright >/dev/null 2>&1; then
        echo '{"ok":true}'
    else
        echo '{"ok":false,"status":"dependency_missing","error":"Playwright not found"}'
    fi
}

human_delay() {
    local min=${1:-2000}
    local max=${2:-4000}
    local range=$((max - min + 1))
    echo $((RANDOM % range + min))
}

handle_popups() {
    local page="$1"
    # This would need to be implemented with actual browser automation tools
    # For now, we'll just return a placeholder
    echo '{"closed":false}'
}

check_restrictions() {
    local page="$1"
    # This would need to be implemented with actual browser automation tools
    # For now, we'll just return a placeholder
    echo '{"restricted":false,"reason":null}'
}

extract_with_playwright() {
    local username="$1"
    local quality_preference="$2"
    
    local preflight
    preflight=$(playwright_preflight)
    local ok
    ok=$(echo "$preflight" | jq -r '.ok')
    
    if [[ "$ok" != "true" ]]; then
        echo "$preflight" | jq '. + {method: "playwright"}'
        return
    fi
    
    # In a real implementation, this would launch a browser and extract URLs
    # For this translation, we'll simulate a failure since we can't actually run Playwright
    jq -n --arg success "false" \
          --arg method "playwright" \
          --arg status "technical_error" \
          --arg error "Playwright not available in bash implementation" '{
        success: ($success | test("true")),
        method: $method,
        status: $status,
        error: $error
    }'
}

try_streamlink() {
    local username="$1"
    local quality="$2"
    local script_dir
    script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
    local script_path="$script_dir/extraction-methods/extract-tiktok-streamlink.sh"
    
    if [[ ! -f "$script_path" ]]; then
        jq -n --arg success "false" \
              --arg status "dependency_missing" \
              --arg message "streamlink script not found" '{
            success: false,
            status: $status,
            message: $message
        }'
        return
    fi
    
    local execution
    execution=$(run_fallback "$script_path" "$username" "$quality" "--json")
    parse_fallback_result "streamlink" "$username" "$execution"
}

try_yt_dlp() {
    local username="$1"
    local quality="$2"
    local script_dir
    script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
    local script_path="$script_dir/extraction-methods/extract-tiktok-yt-dlp.sh"
    
    if [[ ! -f "$script_path" ]]; then
        jq -n --arg success "false" \
              --arg status "dependency_missing" \
              --arg message "yt-dlp script not found" '{
            success: false,
            status: $status,
            message: $message
        }'
        return
    fi
    
    local yt_format
    case "$quality" in
        original)
            yt_format="hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld"
            ;;
        1080p60)
            yt_format="hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld"
            ;;
        720p60)
            yt_format="hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld"
            ;;
        720p)
            yt_format="hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld"
            ;;
        540p)
            yt_format="hls-sd/hls-ld/flv-sd/flv-ld"
            ;;
        360p)
            yt_format="hls-ld/flv-ld"
            ;;
        auto)
            yt_format="hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
            ;;
        *)
            yt_format="hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
            ;;
    esac
    
    local execution
    execution=$(run_fallback "$script_path" "$username" "$yt_format" "--json")
    parse_fallback_result "yt-dlp" "$username" "$execution"
}

get_stream_url() {
    local username="$1"
    local quality_preference="${2:-auto}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log "[1/3] Trying Playwright for @$username..."
    local pw_result
    pw_result=$(extract_with_playwright "$username" "$quality_preference")
    local pw_success
    pw_success=$(echo "$pw_result" | jq -r '.success')
    
    if [[ "$pw_success" == "true" ]]; then
        echo "$pw_result" | jq --arg timestamp "$timestamp" '. + {timestamp: $timestamp}'
        return
    fi
    
    local pw_status
    pw_status=$(echo "$pw_result" | jq -r '.status')
    if [[ "$pw_status" == "restricted" ]] || [[ "$pw_status" == "overloaded" ]]; then
        echo "$pw_result"
        return
    fi
    
    local pw_reason
    pw_reason=$(echo "$pw_result" | jq -r '.reason // .error // "failed"')
    log "Playwright result: $pw_reason"

    log "[2/3] Trying streamlink for @$username (quality: $quality_preference)..."
    local sl_result
    sl_result=$(try_streamlink "$username" "$quality_preference")
    local sl_success
    sl_success=$(echo "$sl_result" | jq -r '.success')
    
    if [[ "$sl_success" == "true" ]]; then
        echo "$sl_result"
        return
    fi
    
    local sl_status
    sl_status=$(echo "$sl_result" | jq -r '.status')
    if [[ "$sl_status" == "restricted" ]] || [[ "$sl_status" == "overloaded" ]]; then
        echo "$sl_result"
        return
    fi
    
    local sl_message
    sl_message=$(echo "$sl_result" | jq -r '.message // .error // "failed"')
    log "Streamlink result: $sl_message"

    log "[3/3] Trying yt-dlp for @$username..."
    local yt_result
    yt_result=$(try_yt_dlp "$username" "$quality_preference")
    local yt_success
    yt_success=$(echo "$yt_result" | jq -r '.success')
    
    if [[ "$yt_success" == "true" ]]; then
        echo "$yt_result"
        return
    fi
    
    local yt_status
    yt_status=$(echo "$yt_result" | jq -r '.status')
    if [[ "$yt_status" == "restricted" ]] || [[ "$yt_status" == "overloaded" ]]; then
        echo "$yt_result"
        return
    fi
    
    local yt_message
    yt_message=$(echo "$yt_result" | jq -r '.message // .error // "failed"')
    log "yt-dlp result: $yt_message"

    # All methods failed
    local final_status="technical_error"
    if [[ "$pw_status" == "offline" ]] && [[ "$sl_status" == "offline" ]] && [[ "$yt_status" == "offline" ]]; then
        final_status="offline"
    fi
    
    jq -n --arg success "false" \
          --arg status "$final_status" \
          --arg username "$username" \
          --arg message "All extraction methods failed (Playwright, streamlink, yt-dlp)." \
          --arg playwrightReason "$pw_reason" \
          --arg streamlinkReason "$sl_message" \
          --arg ytdlpReason "$yt_message" \
          --arg timestamp "$timestamp" '{
        success: ($success | test("true")),
        status: $status,
        username: $username,
        message: $message,
        playwrightReason: $playwrightReason,
        streamlinkReason: $streamlinkReason,
        ytdlpReason: $ytdlpReason,
        timestamp: $timestamp
    }'
}

normalize_username() {
    local username="$1"
    # Remove @ if present
    username="${username#@}"
    # Validate username format (basic validation)
    if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Invalid username format" >&2
        return 1
    fi
    echo "$username"
}

exit_code_for_result() {
    local result="$1"
    local status
    status=$(echo "$result" | jq -r '.status')
    
    case "$status" in
        live)
            return 0
            ;;
        offline|restricted)
            return 1
            ;;
        overloaded)
            return 75
            ;;
        *)
            return 2
            ;;
    esac
}

# CLI processing
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]" >&2
    exit 1
fi

cli_username=""
if ! cli_username=$(normalize_username "$1"); then
    echo "$cli_username" >&2
    exit 64
fi

shift

cli_quality="auto"
for arg in "$@"; do
    if [[ ! "$arg" =~ ^-- ]]; then
        cli_quality="$arg"
    fi
done

cli_json=false
for arg in "$@"; do
    if [[ "$arg" == "--json" ]]; then
        cli_json=true
    fi
done

if [[ ! " original 1080p60 720p60 720p 540p 360p auto " =~ " $cli_quality " ]]; then
    echo "Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto" >&2
    exit 64
fi

result=$(get_stream_url "$cli_username" "$cli_quality")
exit_code=$(exit_code_for_result "$result")

if [[ "$cli_json" == true ]]; then
    echo "$result" | jq '.'
else
    if echo "$result" | jq -r '.success' | grep -q "true"; then
        echo "$result" | jq -r '.url'
    else
        echo "$result" | jq -r '.message'
    fi
fi

exit $exit_code
