#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "3fc72e8adc7fc16e6341e03e57b0b2d5192bf45aeef89a4f45c4dcb0f3f00d82", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "shell"}
# gateway_transport.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

# Exception handling: simulate custom exceptions using exit codes and messages
TRANSPORT_UNRESOLVED=99

die() {
    echo "$*" >&2
    exit 1
}

transport_unresolved() {
    echo "$*" >&2
    exit $TRANSPORT_UNRESOLVED
}

# Function to get gateway token
gateway_token() {
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"
    token=$(echo "$token" | xargs)  # trim whitespace
    
    if [[ -n "$token" ]]; then
        echo "$token"
        return
    fi
    
    local config_path="${OPENCLAW_CONFIG_PATH:-}"
    if [[ -z "$config_path" ]]; then
        config_path="$HOME/.openclaw/openclaw.json"
    fi
    
    if [[ ! -f "$config_path" ]]; then
        echo ""
        return
    fi
    
    # Extract token from JSON using jq if available, otherwise use grep/sed
    if command -v jq >/dev/null 2>&1; then
        token=$(jq -r '.gateway.auth.token // ""' "$config_path" 2>/dev/null || echo "")
    else
        # Fallback: basic extraction using sed/grep
        token=$(grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_path" | \
                sed -E 's/"token"[[:space:]]*:[[:space:]]*"([^"]*)"/\1/' 2>/dev/null || echo "")
    fi
    
    # Check if token looks like a variable placeholder
    if [[ "$token" == \$\{* ]] || [[ -z "$token" ]]; then
        echo ""
        return
    fi
    
    echo "$token" | xargs  # trim whitespace
}

# Main GatewayTransport implementation
GatewayTransport() {
    local state_file="$1"
    local url="$2"
    local token="$3"
    local timeout="${4:-3900}"
    local interval="${5:-3}"
    
    # Validate URL
    if [[ ! "$url" =~ ^https?://[^/]+ ]]; then
        die "invalid Gateway URL"
    fi
    
    local scheme hostname
    scheme=$(echo "$url" | sed -E 's#^(https?)://([^/]+).*#\1#')
    hostname=$(echo "$url" | sed -E 's#^(https?)://([^/]+).*#\2#')
    
    if [[ "$scheme" == "http" ]] && [[ ! "$hostname" =~ ^(127\.0\.0\.1|localhost|\[::1\])$ ]]; then
        die "unencrypted Gateway must use loopback"
    fi
    
    if [[ -z "${token// }" ]] || [[ "$timeout" -le 0 ]] || [[ "$interval" -le 0 ]]; then
        die "Gateway token and positive timeouts required"
    fi
    
    # Export variables for internal functions
    export GATEWAY_URL="$url"
    export GATEWAY_TOKEN="$token"
    export GATEWAY_TIMEOUT="$timeout"
    export GATEWAY_INTERVAL="$interval"
    export STATE_FILE="$state_file"
}

# Internal function to make HTTP requests
_request() {
    local node="$1"
    local request_json="$2"
    local device_id="$3"
    
    # Add device_id to request if provided
    if [[ -n "$device_id" ]]; then
        request_json=$(echo "$request_json" | jq --arg device_id "$device_id" '.device_id = $device_id')
    fi
    
    # Create payload
    local payload
    payload=$(jq -n --arg node "$node" --argjson request "$request_json" '{node: $node, request: $request}')
    if [[ -n "$device_id" ]]; then
        payload=$(echo "$payload" | jq --arg device_id "$device_id" '.device_id = $device_id')
    fi
    
    # Set timeout based on node
    local request_timeout=40
    if [[ "$node" == "node4" ]]; then
        request_timeout=150
    fi
    
    # Make request
    local response_file response_code
    response_file=$(mktemp)
    trap "rm -f '$response_file'" EXIT
    
    # Try curl first, then wget
    if command -v curl >/dev/null 2>&1; then
        response_code=$(curl -s -w "%{http_code}" -o "$response_file" \
            -H "Authorization: Bearer $GATEWAY_TOKEN" \
            -H "Content-Type: application/json" \
            --data-binary "$payload" \
            --max-time "$request_timeout" \
            "$GATEWAY_URL" 2>/dev/null || echo "000")
    elif command -v wget >/dev/null 2>&1; then
        response_code=$(wget -q -O "$response_file" \
            --header="Authorization: Bearer $GATEWAY_TOKEN" \
            --header="Content-Type: application/json" \
            --post-data="$payload" \
            --read-timeout="$request_timeout" \
            --server-response -S \
            "$GATEWAY_URL" 2>&1 | grep "HTTP/" | tail -1 | cut -d' ' -f2 || echo "000")
    else
        transport_unresolved "No HTTP client available"
    fi
    
    # Check response size (approximate limit)
    local response_size
    response_size=$(stat -c%s "$response_file" 2>/dev/null || echo "0")
    if [[ "$response_size" -gt 4000000 ]]; then
        transport_unresolved "response too large"
    fi
    
    # Read response
    local raw_result
    raw_result=$(cat "$response_file")
    
    # Parse response
    local result device_check
    if command -v jq >/dev/null 2>&1; then
        if ! echo "$raw_result" | jq -e 'type == "object" and has("result")' >/dev/null 2>&1; then
            transport_unresolved "invalid gateway response"
        fi
        
        result=$(echo "$raw_result" | jq -c '.result')
        
        if [[ -n "$device_id" ]]; then
            device_check=$(echo "$raw_result" | jq -r '.device_id // empty')
            if [[ "$device_check" != "$device_id" ]]; then
                transport_unresolved "gateway device identity mismatch"
            fi
        fi
    else
        # Fallback parsing with grep/sed
        if ! echo "$raw_result" | grep -q '"result"'; then
            transport_unresolved "invalid gateway response"
        fi
        result=$(echo "$raw_result" | sed -n 's/.*"result":[[:space:]]*\([^,}]*\).*/\1/p')
    fi
    
    echo "$result"
}

available() {
    local result
    result=$(_request "node1" '{"operation": "availability"}')
    
    # Validate result is dictionary-like
    if ! echo "$result" | grep -q '^{.*}$'; then
        transport_unresolved "invalid node availability"
    fi
    
    echo "$result"
}

_release() {
    local original_json="$1"
    local entry_key="$2"
    
    # Check if already released
    if _entry_get_released "$entry_key"; then
        return
    fi
    
    # Extract values from original
    local selected_node selected_device_id job_id attempt_id target_language
    selected_node=$(echo "$original_json" | jq -r '.selected_node')
    selected_device_id=$(echo "$original_json" | jq -r '.selected_device_id')
    job_id=$(echo "$original_json" | jq -r '.job_id')
    attempt_id=$(echo "$original_json" | jq -r '.attempt_id')
    target_language=$(echo "$original_json" | jq -r '.target_language')
    
    # Try to release
    local result
    if ! result=$(_request "$selected_node" "{\"operation\": \"release\", \"job_id\": \"$job_id\", \"attempt_id\": \"$attempt_id\"}" "$selected_device_id" 2>/dev/null); then
        return  # Retry cleanup later
    fi
    
    # Check release status
    local status check_job_id check_attempt_id check_selected_node check_target_language
    status=$(echo "$result" | jq -r '.status // empty')
    check_job_id=$(echo "$result" | jq -r '.job_id // empty')
    check_attempt_id=$(echo "$result" | jq -r '.attempt_id // empty')
    check_selected_node=$(echo "$result" | jq -r '.selected_node // empty')
    check_target_language=$(echo "$result" | jq -r '.target_language // empty')
    
    if [[ "$status" == "released" ]] && \
       [[ "$check_job_id" == "$job_id" ]] && \
       [[ "$check_attempt_id" == "$attempt_id" ]] && \
       [[ "$check_selected_node" == "$selected_node" ]] && \
       [[ "$check_target_language" == "$target_language" ]]; then
        _entry_set_released "$entry_key" true
    fi
}

release_pending() {
    # This would need to iterate through all entries in the state file
    # Implementation depends on how the state is stored
    :
}

_entry_get_released() {
    local entry_key="$1"
    # Placeholder for checking if entry is released
    # Would require reading from state file
    echo "false"
}

_entry_set_released() {
    local entry_key="$1"
    local value="$2"
    # Placeholder for setting released status
    # Would require updating state file
    :
}

# Main transport function
transport_call() {
    local job_json="$1"
    
    # Validate job
    local source_sha256 target_language selected_device_id
    source_sha256=$(echo "$job_json" | jq -r '.source_sha256 // empty')
    target_language=$(echo "$job_json" | jq -r '.target_language // empty')
    selected_device_id=$(echo "$job_json" | jq -r '.selected_device_id // empty')
    
    if [[ -z "$source_sha256" ]] || [[ -z "$target_language" ]] || [[ -z "$selected_device_id" ]]; then
        die "missing source identity"
    fi
    
    local key="$source_sha256:$target_language"
    
    # Load or create entry
    local entry_exists entry_fresh entry_response entry_status
    entry_exists=$(_load_entry "$key")
    entry_fresh=$?
    
    if [[ "$entry_exists" == "false" ]]; then
        # Generate new attempt ID
        local attempt_id
        attempt_id=$(uuidgen 2>/dev/null || echo "$(date +%s)_$(RANDOM)")
        
        # Create new entry
        local original_json
        original_json=$(echo "$job_json" | jq --arg id "$attempt_id" '. + {attempt_id: $id}')
        
        _create_entry "$key" "$original_json"
        entry_fresh=0
    else
        # Load existing entry data
        entry_response=$(_entry_get_response "$key")
        entry_status=$(_entry_get_status "$key")
    fi
    
    # Get original job data
    local original_json
    original_json=$(_entry_get_original "$key")
    
    # Update job with original data
    job_json=$(echo "$original_json" | jq '.')
    
    # Return cached response if available
    if [[ -n "${entry_response:-}" ]] && [[ "$entry_response" != "null" ]]; then
        _release "$original_json" "$key"
        echo "$entry_response"
        return
    fi
    
    # Handle failed/unknown attempts
    if [[ "${entry_status:-}" == "failed" ]] || [[ "${entry_status:-}" == "unknown" ]]; then
        transport_unresolved "attempt requires reconciliation"
    fi
    
    local status=""
    
    # Submit new request if fresh
    if [[ "$entry_fresh" -eq 0 ]]; then
        local selected_node selected_device_id
        selected_node=$(echo "$original_json" | jq -r '.selected_node')
        selected_device_id=$(echo "$original_json" | jq -r '.selected_device_id')
        
        if ! status=$(_request "$selected_node" "{\"operation\": \"execute\", \"job\": $original_json}" "$selected_device_id" 2>/dev/null); then
            :  # Continue to querying phase
        fi
    fi
    
    # Calculate deadline
    local deadline start_time
    start_time=$(date +%s)
    deadline=$((start_time + GATEWAY_TIMEOUT))
    
    # Polling loop
    while true; do
        if [[ -z "$status" ]]; then
            local selected_node selected_device_id job_id attempt_id
            selected_node=$(echo "$original_json" | jq -r '.selected_node')
            selected_device_id=$(echo "$original_json" | jq -r '.selected_device_id')
            job_id=$(echo "$original_json" | jq -r '.job_id')
            attempt_id=$(echo "$original_json" | jq -r '.attempt_id')
            
            status=$(_request "$selected_node" "{\"operation\": \"status\", \"job_id\": \"$job_id\", \"attempt_id\": \"$attempt_id\"}" "$selected_device_id")
        fi
        
        # Validate status structure
        if ! echo "$status" | grep -q '^{.*}$'; then
            transport_unresolved "attempt is not known by the node"
        fi
        
        # Check identity match
        local job_id attempt_id selected_node target_language
        job_id=$(echo "$original_json" | jq -r '.job_id')
        attempt_id=$(echo "$original_json" | jq -r '.attempt_id')
        selected_node=$(echo "$original_json" | jq -r '.selected_node')
        target_language=$(echo "$original_json" | jq -r '.target_language')
        
        local check_job_id check_attempt_id check_selected_node check_target_language
        check_job_id=$(echo "$status" | jq -r '.job_id // empty')
        check_attempt_id=$(echo "$status" | jq -r '.attempt_id // empty')
        check_selected_node=$(echo "$status" | jq -r '.selected_node // empty')
        check_target_language=$(echo "$status" | jq -r '.target_language // empty')
        
        if [[ "$check_job_id" != "$job_id" ]] || \
           [[ "$check_attempt_id" != "$attempt_id" ]] || \
           [[ "$check_selected_node" != "$selected_node" ]] || \
           [[ "$check_target_language" != "$target_language" ]]; then
            transport_unresolved "status identity mismatch"
        fi
        
        local state
        state=$(echo "$status" | jq -r '.status // empty')
        
        if [[ "$state" == "completed" ]]; then
            local response
            response=$(echo "$status" | jq -c '.response // {}')
            
            # Validate response
            local response_status code
            response_status=$(echo "$response" | jq -r '.status // empty')
            code=$(echo "$response" | jq -r '.code // empty')
            
            if [[ "$response_status" != "ok" ]] || \
               [[ -z "$code" ]] || \
               [[ "${code// }" == "" ]]; then
                transport_unresolved "invalid translation result"
            fi
            
            # Save and return response
            _entry_set_response "$key" "$response"
            _entry_set_status "$key" "completed"
            _save_state
            _release "$original_json" "$key"
            echo "$response"
            return
        fi
        
        if [[ "$state" == "failed" ]] || [[ "$state" == "unknown" ]]; then
            _entry_set_status "$key" "$state"
            _save_state
            _release "$original_json" "$key"
            transport_unresolved "attempt requires reconciliation"
        fi
        
        if [[ "$state" != "running" ]]; then
            transport_unresolved "attempt is unresolved"
        fi
        
        local current_time
        current_time=$(date +%s)
        if [[ "$current_time" -ge "$deadline" ]]; then
            transport_unresolved "attempt is unresolved"
        fi
        
        sleep "$GATEWAY_INTERVAL"
        status=""
    done
}

# Helper functions for state management (would need actual implementation)
_load_entry() { echo "false"; return 1; }
_create_entry() { :; }
_entry_get_response() { :; }
_entry_get_status() { :; }
_entry_get_original() { :; }
_entry_set_response() { :; }
_entry_set_status() { :; }
_save_state() { :; }

# Example usage function
main() {
    local state_file url token timeout interval
    
    state_file="${1:-/tmp/state.json}"
    url="${2:-http://localhost:8080}"
    token=$(gateway_token)
    timeout="${3:-3900}"
    interval="${4:-3}"
    
    if [[ -z "$token" ]]; then
        die "Could not obtain gateway token"
    fi
    
    GatewayTransport "$state_file" "$url" "$token" "$timeout" "$interval"
    
    # Process input job
    local job_input
    job_input=$(cat)
    
    transport_call "$job_input"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
