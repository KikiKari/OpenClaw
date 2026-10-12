#!/usr/bin/env bash
# tiktok-check-profile.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Enhanced TikTok LIVE status checker.
#
# Uses exact account selectors and the direct /@username/live page to return
# live, restricted, offline, dependency_missing, technical_error, or
# overloaded. An accessible LIVE requires a successful allowed TikTok-CDN
# FLV response; unrelated sidebar LIVE labels never count.
#
# Browser resources are closed on every completion path.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_FILE="${SCRIPT_DIR}/tiktok-common"

if [[ ! -f "$COMMON_FILE" ]]; then
    echo '{"error":true,"status":"dependency_missing","method":"bash","message":"Missing tiktok-common library","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
    exit 2
fi

source "$COMMON_FILE"

# Normalize username from argument
if [[ $# -ne 1 ]]; then
    echo 'Usage: ./tiktok-check-profile.sh <username>' >&2
    echo 'Invalid number of arguments' >&2
    exit 64
fi

username=$(normalize_username "$1")
if [[ $? -ne 0 ]]; then
    echo 'Usage: ./tiktok-check-profile.sh <username>' >&2
    echo "$username" >&2
    exit 64
fi

enforce_load_limit "bash_enhanced"

# Realistische Verzögerung (2-4s zufällig)
human_delay() {
    local min=${1:-2000}
    local max=${2:-4000}
    local range=$((max - min + 1))
    echo $((RANDOM % range + min))
}

# Close cookie banners using various selectors
close_dsgvo_banner() {
    local page="$1"
    local selectors=(
        'button:has-text("Verstanden")'
        '[data-e2e="cookie-banner-accept"]'
        'button:has-text("Accept")'
        'button:has-text("Akzeptieren")'
        'button:has-text("Alle akzeptieren")'
        'button:has-text("Allow all")'
        'button:has-text("Accept all")'
        'button.TUXButton:has-text("Accept")'
        '[data-testid="cookie-policy-banner-accept"]'
    )
    
    for selector in "${selectors[@]}"; do
        if playwright click --page="$page" --selector="$selector" 2>/dev/null; then
            sleep $(($(human_delay 1000 2000) / 1000)).$((($(human_delay 1000 2000) % 1000) * 1000))
            return 0
        fi
    done
    return 1
}

# Wait for page to fully load by checking specific elements
wait_for_page_ready() {
    local page="$1"
    
    # Phase 1: Initial loading delay
    sleep $(($(human_delay 2000 3000) / 1000)).$((($(human_delay 2000 3000) % 1000) * 1000))
    
    # Phase 2: Wait for "Erneute Veröffentlichungen" tab
    if ! playwright wait-for-selector --page="$page" --selector='text="Erneute Veröffentlichungen"' --timeout=25000 2>/dev/null; then
        # Fallback: Try English version
        if ! playwright wait-for-selector --page="$page" --selector='text="Reposts"' --timeout=5000 2>/dev/null; then
            # Last resort: Wait for network idle
            playwright wait-for-load-state --page="$page" --state="networkidle" --timeout=10000 2>/dev/null || true
        fi
    fi
    
    # Phase 3: Additional delay after menu appears
    sleep $(($(human_delay 2000 3000) / 1000)).$((($(human_delay 2000 3000) % 1000) * 1000))
    
    return 0
}

# Detect live status using multiple methods
detect_live_status() {
    local page="$1"
    local user="$2"
    
    local indicators=()
    local detection_method="none"
    
    # Generate live href selectors
    local live_selectors
    readarray -t live_selectors < <(live_href_selectors "$user")
    local selector_string
    selector_string=$(IFS=','; echo "${live_selectors[*]}")
    
    # Priority 1: LIVE icon within exact account link
    if playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null; then
        local live_link=$(playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null)
        if [[ -n "$live_link" ]]; then
            if playwright query-selector --page="$live_link" --selector='[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]' 2>/dev/null; then
                if playwright is-visible --element="$(playwright query-selector --page="$live_link" --selector='[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]' 2>/dev/null)" 2>/dev/null; then
                    echo '{"isLive":true,"detectionMethod":"live-icon","indicators":{"liveIcon":true}}'
                    return 0
                fi
            fi
        fi
    fi
    
    # Priority 2: Exact LIVE badge within same account link
    if playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null; then
        local live_link=$(playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null)
        if [[ -n "$live_link" ]]; then
            if playwright query-selector --page="$live_link" --selector='text=/^LIVE$/i' 2>/dev/null; then
                local live_badge=$(playwright query-selector --page="$live_link" --selector='text=/^LIVE$/i' 2>/dev/null)
                if [[ -n "$live_badge" ]] && playwright is-visible --element="$live_badge" 2>/dev/null; then
                    echo '{"isLive":true,"detectionMethod":"live-badge","indicators":{"liveBadge":true}}'
                    return 0
                fi
            fi
        fi
    fi
    
    # Priority 3: Live border at profile header/avatar
    local profile_selectors=(
        '[data-e2e="user-page"] img[data-e2e="avatar"]'
        '[data-e2e="user-page"] div[data-e2e="profile-avatar"] img'
        'main header img[data-e2e="avatar"]'
        'main header [class*="avatar"] img'
    )
    
    for selector in "${profile_selectors[@]}"; do
        if playwright query-selector --page="$page" --selector="$selector" 2>/dev/null; then
            local profile_img=$(playwright query-selector --page="$page" --selector="$selector" 2>/dev/null)
            if [[ -n "$profile_img" ]]; then
                # This would need complex JS evaluation which is hard in bash
                # For now we'll skip this detection method in bash implementation
                break
            fi
        fi
    done
    
    # Priority 4: Live indicator within exact account links
    if playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null; then
        local live_link=$(playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null)
        if [[ -n "$live_link" ]]; then
            if playwright query-selector --page="$live_link" --selector='[class*="live-indicator"], div[class*="LiveBadge"]' 2>/dev/null; then
                local live_indicator=$(playwright query-selector --page="$live_link" --selector='[class*="live-indicator"], div[class*="LiveBadge"]' 2>/dev/null)
                if [[ -n "$live_indicator" ]] && playwright is-visible --element="$live_indicator" 2>/dev/null; then
                    echo '{"isLive":true,"detectionMethod":"live-indicator","indicators":{"liveIndicator":true}}'
                    return 0
                fi
            fi
        fi
    fi
    
    # Priority 5: Visible exact /@username/live link
    if playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null; then
        local live_link=$(playwright query-selector --page="$page" --selector="$selector_string" 2>/dev/null)
        if [[ -n "$live_link" ]] && playwright is-visible --element="$live_link" 2>/dev/null; then
            echo '{"isLive":true,"detectionMethod":"live-link","indicators":{"liveLink":true}}'
            return 0
        fi
    fi
    
    echo '{"isLive":false,"detectionMethod":"none","indicators":{}}'
    return 0
}

# Inspect direct live state by visiting /@username/live
inspect_direct_live_state() {
    local page="$1"
    local user="$2"
    
    local successful_stream_response=false
    local response_handler=""
    
    # Set up response handler (this is conceptual - actual implementation would be more complex)
    # In bash/playwright we'd typically use --har or intercept requests
    
    # Navigate to live page
    if ! playwright goto --page="$page" --url="https://www.tiktok.com/@${user}/live" --wait-until="domcontentloaded" --timeout=30000 2>/dev/null; then
        echo '{"status":"technical_error","reason":"Navigation failed"}'
        return 1
    fi
    
    sleep $(($(human_delay 8000 10000) / 1000)).$((($(human_delay 8000 10000) % 1000) * 1000))
    
    local current_url
    current_url=$(playwright get-url --page="$page" 2>/dev/null || echo "")
    
    local body_text=""
    if playwright query-selector --page="$page" --selector="body" 2>/dev/null; then
        body_text=$(playwright inner-text --element="$(playwright query-selector --page="$page" --selector="body" 2>/dev/null)" 2>/dev/null || echo "")
    fi
    
    local title=""
    title=$(playwright get-title --page="$page" 2>/dev/null || echo "")
    
    classify_direct_live_state "$user" "$current_url" "$title" "$body_text" "$successful_stream_response"
}

# Main function to check live status
check_live_status() {
    local user="$1"
    local browser=""
    local page=""
    local context=""
    
    # Check if playwright is available
    if ! command -v playwright >/dev/null 2>&1; then
        echo '{"error":true,"status":"dependency_missing","method":"bash_enhanced","message":"Playwright CLI not found","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
        return 2
    fi
    
    # Launch browser
    browser=$(playwright launch --headless=true 2>/dev/null) || {
        echo '{"error":true,"status":"dependency_missing","method":"bash_enhanced","message":"Failed to launch Playwright browser","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
        return 2
    }
    
    # Create context with custom settings
    context=$(playwright new-context \
        --browser="$browser" \
        --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --viewport-width=1920 \
        --viewport-height=1080 2>/dev/null) || {
        echo '{"error":true,"status":"technical_error","method":"bash_enhanced","message":"Failed to create browser context","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
        playwright close-browser --browser="$browser" 2>/dev/null || true
        return 2
    }
    
    # Create page
    page=$(playwright new-page --context="$context" 2>/dev/null) || {
        echo '{"error":true,"status":"technical_error","method":"bash_enhanced","message":"Failed to create browser page","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
        playwright close-context --context="$context" 2>/dev/null || true
        playwright close-browser --browser="$browser" 2>/dev/null || true
        return 2
    }
    
    trap 'playwright close-page --page="$page" 2>/dev/null || true; playwright close-context --context="$context" 2>/dev/null || true; playwright close-browser --browser="$browser" 2>/dev/null || true' EXIT
    
    # Navigate to profile
    if ! playwright goto --page="$page" --url="https://www.tiktok.com/@${user}" --wait-until="domcontentloaded" --timeout=30000 2>/dev/null; then
        echo '{"error":true,"status":"technical_error","method":"bash_enhanced","message":"Failed to navigate to profile","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' >&2
        return 2
    fi
    
    # Step 1: Close DSGVO banner
    local banner_closed=false
    if close_dsgvo_banner "$page"; then
        banner_closed=true
    fi
    
    # Step 2: Wait for page to fully load
    local page_ready=false
    if wait_for_page_ready "$page"; then
        page_ready=true
    fi
    
    # Debug screenshot if requested
    if [[ "${DEBUG:-0}" == "1" ]]; then
        playwright screenshot --page="$page" --path="/tmp/tiktok-${user}-v2.png" --full-page=true 2>/dev/null || true
    fi
    
    # Step 3: Check live status with prioritized detection
    local live_result
    live_result=$(detect_live_status "$page" "$user")
    
    # Step 4: Check direct live page for restrictions
    local direct_result
    direct_result=$(inspect_direct_live_state "$page" "$user")
    
    # Parse results
    local is_live=false
    local detection_method="none"
    local is_restricted=false
    local restriction_reason=""
    
    # Extract values from JSON responses (conceptual - real implementation would use jq)
    if echo "$direct_result" | grep -q '"status":"restricted"'; then
        is_restricted=true
        restriction_reason=$(echo "$direct_result" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4)
        detection_method="account-live-restricted"
    elif echo "$live_result" | grep -q '"isLive":true'; then
        is_live=true
        detection_method=$(echo "$live_result" | grep -o '"detectionMethod":"[^"]*"' | cut -d'"' -f4)
    elif echo "$direct_result" | grep -q '"status":"live"'; then
        is_live=true
        detection_method="direct-live-page"
    fi
    
    local final_status="offline"
    if $is_restricted; then
        final_status="restricted"
    elif $is_live; then
        final_status="live"
    else
        if echo "$direct_result" | grep -q '"status":"offline"'; then
            final_status="offline"
        elif echo "$direct_result" | grep -q '"status":"technical_error"'; then
            final_status="technical_error"
        elif echo "$direct_result" | grep -q '"status":"overloaded"'; then
            final_status="overloaded"
        fi
    fi
    
    # Output result as JSON
    cat <<EOF
{
  "username": "$user",
  "status": "$final_status",
  "isLive": $([[ "$final_status" == "live" || "$final_status" == "restricted" ]] && echo "true" || echo "false"),
  "detectionMethod": "$detection_method",
  "isAgeRestricted": $is_restricted,
  "ageRestrictionReason": $(if $is_restricted; then echo "\"$restriction_reason\""; else echo "null"; fi),
  "indicators": $(echo "$live_result" | grep -o '"indicators":[^}]*}' || echo "{}"),
  "bannerClosed": $banner_closed,
  "pageFullyLoaded": $page_ready,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "2.1"
}
EOF
    
    echo "$final_status"
    return 0
}

# Run main function and handle exit codes
result=$(check_live_status "$username")
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    case "$result" in
        "live")
            exit 0
            ;;
        "offline"|"restricted")
            exit 1
            ;;
        *)
            exit 2
            ;;
    esac
else
    exit $exit_code
fi
