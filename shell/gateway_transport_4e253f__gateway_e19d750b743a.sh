#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "109ae65c595f01273fb727f1ff29a1b60d84f481f9a6b0888b9057c61ee39cb9", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "shell"}
# gateway_transport.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# auch in: workspace@local:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

# Custom error codes
declare -r E_TRANSPORT_UNRESOLVED=1

# Function to exit with transport unresolved error
transport_unresolved() {
    echo "TransportUnresolved: $1" >&2
    exit $E_TRANSPORT_UNRESOLVED
}

# Get gateway token from environment or config file
gateway_token() {
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"
    if [[ -n "$token" ]]; then
        echo "$token"
        return
    fi
    
    local config_path="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
    if [[ ! -f "$config_path" ]]; then
        echo ""
        return
    fi
    
    # Extract token from JSON config
    token=$(jq -r '.gateway.auth.token // ""' "$config_path" 2>/dev/null) || {
        echo ""
        return
    }
    
    # Check if token looks like a variable placeholder
    if [[ "$token" =~ ^\$\{.*\}$ ]]; then
        echo ""
        return
    fi
    
    echo "$token"
}

# GatewayTransport class implementation
GatewayTransport() {
    local state_file="$1"
    local url="$2"
    local token="$3"
    local timeout="${4:-3900}"
    local interval="${5:-3}"
    
    # Validate URL
    if [[ ! "$url" =~ ^https?://[^/]+ ]]; then
        echo "invalid Gateway URL" >&2
        return 1
    fi
    
    # Check for unencrypted gateway on non-loopback address
    if [[ "$url" =~ ^http:// ]] && ! [[ "$url" =~ ^http://(127\.0\.0\.1|localhost|\[::1\]) ]]; then
        echo "unencrypted Gateway must use loopback" >&2
        return 1
    fi
    
    # Validate parameters
    if [[ -z "$token" ]] || [[ "$timeout" -le 0 ]] || [[ "$interval" -le 0 ]]; then
        echo "Gateway token and positive timeouts required" >&2
        return 1
    fi
    
    # Export variables for internal functions
    export GT_STATE_FILE="$state_file"
    export GT_URL="$url"
    export GT_TOKEN="$token"
    export GT_TIMEOUT="$timeout"
    export GT_INTERVAL="$interval"
}

# Make HTTP request to gateway
_request() {
    local node="$1"
    local request_json="$2"
    local device_id="${3:-null}"
    
    # Build payload
    local payload
    if [[ "$device_id" == "null" ]]; then
        payload=$(jq -n --arg node "$node" --argjson request "$request_json" \
            '{"node": $node, "device_id": null, "request": $request}')
    else
        payload=$(jq -n --arg node "$node" --arg device_id "$device_id" --argjson request "$request_json" \
            '{"node": $node, "device_id": $device_id, "request": $request}')
    fi
    
    # Determine timeout based on node
    local request_timeout=40
    if [[ "$node" == "node4" ]]; then
        request_timeout=150
    fi
    
    # Make request
    local response
    response=$(curl -s -f -m "$request_timeout" \
        -H "Authorization: Bearer $GT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$GT_URL" 2>/dev/null) || transport_unresolved "Gateway request failed"
    
    # Check response size (approximate)
    if [[ ${#response} -gt 4000000 ]]; then
        transport_unresolved "response too large"
    fi
    
    # Validate response structure
    local result_check
    result_check=$(echo "$response" | jq -r 'if type == "object" and has("result") then "valid" else "invalid" end' 2>/dev/null)
    if [[ "$result_check" != "valid" ]]; then
        transport_unresolved "invalid gateway response"
    fi
    
    # Check device ID if provided
    if [[ "$device_id" != "null" ]]; then
        local response_device_id
        response_device_id=$(echo "$response" | jq -r '.device_id // empty' 2>/dev/null)
        if [[ "$response_device_id" != "$device_id" ]]; then
            transport_unresolved "gateway device identity mismatch"
        fi
    fi
    
    echo "$response" | jq -c '.result'
}

# Check node availability
available() {
    local result
    result=$(_request "node1" '{"operation": "availability"}')
    
    local type_check
    type_check=$(echo "$result" | jq -r 'if type == "object" then "valid" else "invalid" end' 2>/dev/null)
    if [[ "$type_check" != "valid" ]]; then
        transport_unresolved "invalid node availability"
    fi
    
    echo "$result"
}

# Release a completed job
_release() {
    local original_json="$1"
    local entry_key="$2"
    
    # Check if already released
    local released
    released=$(jq -r ".auftraege[\"$entry_key\"].released // false" "$GT_STATE_FILE")
    if [[ "$released" == "true" ]]; then
        return
    fi
    
    # Extract values from original
    local selected_node job_id attempt_id selected_device_id target_language
    selected_node=$(echo "$original_json" | jq -r '.selected_node')
    job_id=$(echo "$original_json" | jq -r '.job_id')
    attempt_id=$(echo "$original_json" | jq -r '.attempt_id')
    selected_device_id=$(echo "$original_json" | jq -r '.selected_device_id')
    target_language=$(echo "$original_json" | jq -r '.target_language')
    
    # Try to release
    local result
    if ! result=$(_request "$selected_node" "{\"operation\": \"release\", \"job_id\": \"$job_id\", \"attempt_id\": \"$attempt_id\"}" "$selected_device_id" 2>/dev/null); then
        return  # Retry cleanup later
    fi
    
    # Check release result
    local status check_job_id check_attempt_id check_selected_node check_target_language
    status=$(echo "$result" | jq -r '.status // empty' 2>/dev/null)
    check_job_id=$(echo "$result" | jq -r '.job_id // empty' 2>/dev/null)
    check_attempt_id=$(echo "$result" | jq -r '.attempt_id // empty' 2>/dev/null)
    check_selected_node=$(echo "$result" | jq -r '.selected_node // empty' 2>/dev/null)
    check_target_language=$(echo "$result" | jq -r '.target_language // empty' 2>/dev/null)
    
    if [[ "$status" == "released" ]] && 
       [[ "$check_job_id" == "$job_id" ]] && 
       [[ "$check_attempt_id" == "$attempt_id" ]] && 
       [[ "$check_selected_node" == "$selected_node" ]] && 
       [[ "$check_target_language" == "$target_language" ]]; then
        # Update state
        jq ".auftraege[\"$entry_key\"].released = true" "$GT_STATE_FILE" > "${GT_STATE_FILE}.tmp" && mv "${GT_STATE_FILE}.tmp" "$GT_STATE_FILE"
    fi
}

# Release all pending jobs
release_pending() {
    # Process each entry in auftraege
    local keys
    keys=$(jq -r 'if .auftraege and type == "object" then .auftraege | keys[] else empty end' "$GT_STATE_FILE" 2>/dev/null) || return
    
    local key
    for key in $keys; do
        local status entry_type job_type
        status=$(jq -r ".auftraege[\"$key\"].status // empty" "$GT_STATE_FILE" 2>/dev/null)
        entry_type=$(jq -r ".auftraege[\"$key\"] | type" "$GT_STATE_FILE" 2>/dev/null)
        job_type=$(jq -r ".auftraege[\"$key\"].job | type // empty" "$GT_STATE_FILE" 2>/dev/null)
        
        if [[ "$entry_type" == "object" ]] && 
           [[ "$status" =~ ^(completed|rejected|failed)$ ]] && 
           [[ "$job_type" == "object" ]]; then
            local original_json
            original_json=$(jq -c ".auftraege[\"$key\"].job" "$GT_STATE_FILE")
            _release "$original_json" "$key"
        fi
    done
}

# Reject a job with reason
reject() {
    local job_json="$1"
    local reason="$2"
    
    local source_sha256 target_language
    source_sha256=$(echo "$job_json" | jq -r '.source_sha256 // empty' 2>/dev/null)
    target_language=$(echo "$job_json" | jq -r '.target_language // empty' 2>/dev/null)
    
    local key="$source_sha256:$target_language"
    
    # Check entry status
    local entry_status entry_type
    entry_status=$(jq -r ".auftraege[\"$key\"].status // empty" "$GT_STATE_FILE" 2>/dev/null)
    entry_type=$(jq -r ".auftraege[\"$key\"] | type // empty" "$GT_STATE_FILE" 2>/dev/null)
    
    if [[ "$entry_type" != "object" ]] || [[ "$entry_status" != "completed" ]]; then
        return
    fi
    
    # Check attempt ID match
    local current_attempt_id job_attempt_id
    current_attempt_id=$(jq -r ".auftraege[\"$key\"].job.attempt_id // empty" "$GT_STATE_FILE" 2>/dev/null)
    job_attempt_id=$(echo "$job_json" | jq -r '.attempt_id // empty' 2>/dev/null)
    
    if [[ "$current_attempt_id" != "$job_attempt_id" ]]; then
        transport_unresolved "rejected attempt identity mismatch"
    fi
    
    # Update entry
    local truncated_reason="${reason:0:500}"
    jq ".auftraege[\"$key\"].status = \"rejected\" | .auftraege[\"$key\"].validation_error = \"$truncated_reason\"" "$GT_STATE_FILE" > "${GT_STATE_FILE}.tmp" && mv "${GT_STATE_FILE}.tmp" "$GT_STATE_FILE"
}

# Main transport function
call_transport() {
    local job_json="$1"
    
    # Validate job fields
    local source_sha256 target_language selected_device_id
    source_sha256=$(echo "$job_json" | jq -r '.source_sha256 // empty' 2>/dev/null)
    target_language=$(echo "$job_json" | jq -r '.target_language // empty' 2>/dev/null)
    selected_device_id=$(echo "$job_json" | jq -r '.selected_device_id // empty' 2>/dev/null)
    
    if [[ -z "$source_sha256" ]] || [[ -z "$target_language" ]] || [[ -z "$selected_device_id" ]]; then
        echo "missing source identity" >&2
        return 1
    fi
    
    local key="$source_sha256:$target_language"
    local entries_path=".auftraege"
    
    # Initialize auftraege if needed
    if ! jq -e '.auftraege' "$GT_STATE_FILE" >/dev/null 2>&1; then
        jq '.auftraege = {}' "$GT_STATE_FILE" > "${GT_STATE_FILE}.tmp" && mv "${GT_STATE_FILE}.tmp" "$GT_STATE_FILE"
    fi
    
    # Get entry
    local entry_json entry_type
    entry_json=$(jq -c ".auftraege[\"$key\"] // null" "$GT_STATE_FILE" 2>/dev/null)
    entry_type=$(echo "$entry_json" | jq -r 'type' 2>/dev/null)
    
    local fresh="false"
    local original_json
    
    if [[ "$entry_type" == "object" ]] && [[ $(echo "$entry_json" | jq -r '.status') == "rejected" ]]; then
        # Handle rejected entry
        local job_field
        job_field=$(echo "$entry_json" | jq -c '.job // {}')
        _release "$job_field" "$key"
        
        local released
        released=$(jq -r ".auftraege[\"$key\"].released // false" "$GT_STATE_FILE")
        if [[ "$released" != "true" ]]; then
            transport_unresolved "rejected attempt release is unresolved"
        fi
        
        # Create new entry with previous attempts tracking
        local previous_entry="$entry_json"
        original_json=$(echo "$job_json" | jq -c '. + {"attempt_id": "\(uuidgen)"}')
        
        local new_entry
        new_entry=$(jq -n --argjson orig "$original_json" --argjson prev "$previous_entry" '{
            job: $orig,
            status: "submitted",
            previous_attempts: ($prev.previous_attempts // []) + [{
                job_id: $prev.job.job_id,
                attempt_id: $prev.job.attempt_id,
                selected_node: $prev.job.selected_node,
                validation_error: $prev.validation_error
            }]
        }')
        
        jq ".auftraege[\"$key\"] = $new_entry" "$GT_STATE_FILE" > "${GT_STATE_FILE}.tmp" && mv "${GT_STATE_FILE}.tmp" "$GT_STATE_FILE"
        fresh="true"
    elif [[ "$entry_type" == "null" ]]; then
        # Create new entry
        original_json=$(echo "$job_json" | jq -c '. + {"attempt_id": "\(uuidgen)"}')
        local new_entry
        new_entry=$(jq -n --argjson orig "$original_json" '{job: $orig, status: "submitted"}')
        jq ".auftraege[\"$key\"] = $new_entry" "$GT_STATE_FILE" > "${GT_STATE_FILE}.tmp" && mv "${GT_STATE_FILE}.tmp" "$GT_STATE_FILE"
        fresh="true"
    else
        # Use existing entry
        original_json=$(echo "$entry_json" | jq -c '.job')
    fi
    
    # Update job with original values
    local updated_job
    updated_job=$(echo "$job_json" | jq -c '. + '"$original_json")
    echo "$updated_job"
    
    # Check for existing response
    local response
    response=$(jq -r ".auftraege[\"$key\"].response // null" "$GT_STATE_FILE")
    if [[ "$response" != "null" ]]; then
        local job_field
        job_field=$(jq -c ".auftraege[\"$key\"].job" "$GT_STATE_FILE")
        _release "$job_field" "$key"
        echo "$response"
        return
    fi
    
    # Check for failed/unknown status
    local entry_status
    entry_status=$(jq -r ".auftraege[\"$key\"].status // empty" "$GT_STATE_FILE")
    if [[ "$entry_status" =~ ^(failed|unknown)$ ]]; then
        transport_unresolved "attempt requires reconciliation"
    fi
    
    # Extract job details
    local selected_node job_id attempt_id selected_device_id target_language
    selected_node=$(echo "$original_json" | jq -r '.selected_node')
    job_id=$(echo "$original_json" | jq -r '.job_id')
    attempt_id=$(echo "$original_json" | jq -r '.attempt_id')
    selected_device_id=$(echo "$original_json" | jq -r '.selected_device_id')
    target_language=$(echo "$original_json" | jq -r '.target_language')
    
    local status=""
    
    # Submit if fresh
    if [[ "$fresh" == "true" ]]; then
        if ! status=$(_request "$selected_node" "{\"operation\": \"execute\", \"job\": $original_json}" "$selected_device_id" 2>/dev/null); then
            status=""  # Will query instead
        fi
    fi
    
    # Deadline tracking using seconds since epoch
    local deadline
    deadline=$(($(date +%s) + GT_TIMEOUT))
    
    # Poll until completion or timeout
    while true; do
        if [[ -z "$status" ]]; then
            status=$(_request "$selected_node" "{\"operation\": \"status\", \"job_id\": \"$job_id\", \"attempt_id\": \"$attempt_id\"}" "$selected_device_id")
        fi
        
        # Validate status structure
        if ! echo "$status" | jq -e 'type == "object"' >/dev/null 2>&1; then
            transport_unresolved "attempt is not known by the node"
        fi
        
        # Check identity match
        local check_job_id check_attempt_id check_selected_node check_target_language
        check_job_id=$(echo "$status" | jq -r '.job_id // empty')
        check_attempt_id=$(echo "$status" | jq -r '.attempt_id // empty')
        check_selected_node=$(echo "$status" | jq -r '.selected_node // empty')
        check_target_language=$(echo "$status" | jq -r '.target_language // empty')
        
        if [[ "$check_job_id" != "$job_id" ]] || 
           [[ "$check_attempt_id" != "$attempt_id" ]] || 
           [[ "$check_selected_node" != "$selected_node" ]] || 
           [[ "$check_target_language" != "$target_language" ]]; then
            transport_unresolved "status identity mismatch"
        fi
        
        local state
        state=$(echo "$status" | jq -r '.status // empty')
        
        if [[ "$state" == "completed" ]]; then
            local response_result
            response_result=$(echo "$status" | jq -c '.response // {}')
            
            # Validate response
            local response_status code_present code_value
            response_status=$(echo "$response_result" | jq -r '.status // empty')
            code_present=$(echo "$response_result" | jq -r 'has("code")')
            code_value=$(echo "$response_result" | jq -r '.code // empty')
            
            local resp_job_id resp_selected_node resp_target_language
            resp_job_id=$(echo "$response_result" | jq -r '.job_id // empty')
            resp_selected_node=$(echo "$response_result" | jq -r '.selected_node // empty')
            resp_target_language=$(echo "$response_result" | jq -r '.target_language // empty')
            
            if [[ "$response_status" != "ok" ]] || 
               [[ "$resp_job_id" != "$job_id" ]] || 
               [[ "$resp_selected_node" != "$selected_node" ]] || 
               [[ "$resp_target_language" != "$target_language" ]] || 
               [[ "$code_present" != "true" ]] || 
               [[ -z "$(echo "$code_value" | tr -d ' \t\n\r')" ]]; then
                transport_unresolved "invalid translation result"
            fi
            
            # Save response and update status
            jq ".auftraege[\"$key\"].response = $response_result | .auftraege[\"$key\"].status = \"completed\"" "$GT_STATE_FILE" > "${GT_STATE_FILE}.tmp" && mv "${GT_STATE_FILE}.tmp" "$GT_STATE_FILE"
            _release "$original_json" "$key"
            echo "$response_result"
            return
        elif [[ "$state" =~ ^(failed|unknown) ]]; then
            jq ".auftraege[\"$key\"].status = \"$state\"" "$GT_STATE_FILE" > "${GT_STATE_FILE}.tmp" && mv "${GT_STATE_FILE}.tmp" "$GT_STATE_FILE"
            if [[ "$state" == "failed" ]]; then
                _release "$original_json" "$key"
            fi
            transport_unresolved "attempt requires reconciliation"
        elif [[ "$state" != "running" ]] || [[ $(date +%s) -ge $deadline ]]; then
            transport_unresolved "attempt is unresolved"
        fi
        
        # Sleep and reset status for next iteration
        sleep "$GT_INTERVAL"
        status=""
    done
}
