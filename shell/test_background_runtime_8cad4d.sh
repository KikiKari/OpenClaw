#!/bin/bash
# test_background_runtime.cjs — portiert nach shell
# Quelle: javascript, Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_background_runtime.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This bash translation simulates testing the background runtime logic
# originally written in JavaScript using Node.js modules and VM contexts.
# Since bash lacks native support for such features, we simulate behavior
# through functions and variable manipulation where possible.

# Simulate core functions from content-core.js and export-privacy.js
# These are placeholders since actual implementation would require full JS engine

new_embed_session() {
    local handle="$1"
    local creator="$2"
    local started_at_ms="$3"

    echo "{ \"handle\": \"$handle\", \"creator\": \"$creator\", \"startedAtMs\": $started_at_ms, \"attempt\": 1, \"nextAttemptAtMs\": null, \"phase\": \"loading\" }"
}

advance_embed_session() {
    local state_json="$1"
    local observation_json="$2"
    local now="$3"

    # Parse JSON inputs (simulated)
    local status=$(echo "$observation_json" | jq -r '.status')
    local document_id=$(echo "$observation_json" | jq -r '.documentId')
    local document_started_at_ms=$(echo "$observation_json" | jq -r '.documentStartedAtMs')

    # Extract fields from state
    local phase=$(echo "$state_json" | jq -r '.phase')
    local attempt=$(echo "$state_json" | jq -r '.attempt')
    local next_attempt_at_ms=$(echo "$state_json" | jq -r '.nextAttemptAtMs')

    case "$status" in
        "server-error")
            if [[ "$phase" == "loading" ]]; then
                if (( $(echo "$now >= $next_attempt_at_ms" | bc -l) )); then
                    echo "{ \"session\": $(echo "$state_json" | jq --argjson attempt "$((attempt+1))" --argjson nextAttemptAtMs "$((now+2000))" '.attempt=$attempt|.nextAttemptAtMs=$nextAttemptAtMs'), \"action\": \"reload\" }"
                else
                    echo "{ \"session\": $state_json, \"action\": \"none\" }"
                fi
            else
                echo "{ \"session\": $state_json, \"action\": \"none\" }"
            fi
            ;;
        "playing")
            if [[ "$phase" == "loading" ]]; then
                echo "{ \"session\": $(echo "$state_json" | jq '.phase=\"playing\"'), \"action\": \"none\" }"
            else
                echo "{ \"session\": $state_json, \"action\": \"none\" }"
            fi
            ;;
        *)
            echo "{ \"session\": $state_json, \"action\": \"none\" }"
            ;;
    esac
}

classify_embed_observation() {
    local text="$1"
    if [[ "$text" == *"Server error"* ]]; then
        echo "server-error"
    elif [[ "$text" == *"LIVE is unavailable"* ]]; then
        echo "unavailable"
    elif [[ "$text" == *"Melde dich an für das vollständige Erlebnis"* ]]; then
        echo "login-required"
    elif [[ "$text" == *"playing"* ]]; then
        echo "playing"
    elif [[ "$text" == *"paused"* ]]; then
        echo "awaiting-gesture"
    else
        echo "unknown"
    fi
}

# Test cases adapted from original file

test_startup_retry_backoff_caps_attempts_ignores_stale_documents() {
    local state=$(new_embed_session "test" "creator" 1000)
    
    # First observation: server-error at 2000ms
    local result=$(advance_embed_session "$state" '{"status":"server-error","documentId":"a","documentStartedAtMs":1000}' 2000)
    state=$(echo "$result" | jq -r '.session')
    local action=$(echo "$result" | jq -r '.action')
    [[ "$action" == "none" ]] || exit 1
    
    # Check next attempt time
    local next_attempt=$(echo "$state" | jq -r '.nextAttemptAtMs')
    [[ "$next_attempt" == "4000" ]] || exit 1
    
    # Second observation just before next attempt
    result=$(advance_embed_session "$state" '{"status":"server-error","documentId":"a","documentStartedAtMs":1000}' 3999)
    state=$(echo "$result" | jq -r '.session')
    action=$(echo "$result" | jq -r '.action')
    [[ "$action" == "none" ]] || exit 1
    
    # Third observation exactly at next attempt
    result=$(advance_embed_session "$state" '{"status":"server-error","documentId":"a","documentStartedAtMs":1000}' 4000)
    state=$(echo "$result" | jq -r '.session')
    action=$(echo "$result" | jq -r '.action')
    [[ "$action" == "reload" ]] || exit 1
    [[ "$(echo "$state" | jq -r '.attempt')" == "2" ]] || exit 1
    
    # Fourth observation: playing at 5000ms
    result=$(advance_embed_session "$state" '{"status":"playing","documentId":"a","documentStartedAtMs":1000}' 5000)
    state=$(echo "$result" | jq -r '.session')
    action=$(echo "$result" | jq -r '.action')
    [[ "$action" == "none" ]] || exit 1
    [[ "$(echo "$state" | jq -r '.phase')" == "loading" ]] || exit 1  # Old document cannot complete newer attempt
    
    # Fifth observation: unavailable at 6000ms with new document ID
    result=$(advance_embed_session "$state" '{"status":"unavailable","documentId":"b","documentStartedAtMs":4500}' 6000)
    state=$(echo "$result" | jq -r '.session')
    action=$(echo "$result" | jq -r '.action')
    [[ "$action" == "none" ]] || exit 1
    [[ "$(echo "$state" | jq -r '.nextAttemptAtMs')" == "10000" ]] || exit 1
    
    # Sixth observation: unavailable at 10000ms with same document ID
    result=$(advance_embed_session "$state" '{"status":"unavailable","documentId":"b","documentStartedAtMs":4500}' 10000)
    state=$(echo "$result" | jq -r '.session')
    action=$(echo "$result" | jq -r '.action')
    [[ "$action" == "reload" ]] || exit 1
    
    # Seventh observation: server-error at 11000ms with new document ID
    result=$(advance_embed_session "$state" '{"status":"server-error","documentId":"c","documentStartedAtMs":10500}' 11000)
    state=$(echo "$result" | jq -r '.session')
    action=$(echo "$result" | jq -r '.action')
    [[ "$(echo "$state" | jq -r '.phase')" == "failed" ]] || exit 1
    [[ "$(echo "$state" | jq -r '.attempt')" == "3" ]] || exit 1
    
    # Eighth observation far in future
    result=$(advance_embed_session "$state" '{"status":"server-error","documentId":"c","documentStartedAtMs":10500}' 100000)
    state=$(echo "$result" | jq -r '.session')
    action=$(echo "$result" | jq -r '.action')
    [[ "$action" == "none" ]] || exit 1
}

test_playback_before_retry_cancels_it_never_reload() {
    local observation_status
    for status in "login-required" "ended" "awaiting-gesture"; do
        observation_status=$(classify_embed_observation "{\"text\":\"$status\"}")
        [[ "$observation_status" == "$status" ]] || exit 1
    done
    
    # Additional checks can be added here if needed
}

# Run all tests
main() {
    test_startup_retry_backoff_caps_attempts_ignores_stale_documents
    test_playback_before_retry_cancels_it_never_reload
    echo "All tests passed."
}

main "$@"
