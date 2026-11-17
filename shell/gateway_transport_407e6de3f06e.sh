#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "e7f5d8de1c4fa3c55afe80f3c8713fad1ebe0aa70645f385669608a2a84753b7", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "shell"}
# gateway_transport.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

# Exception simulation for unresolved transport
transport_unresolved() {
    echo "TransportUnresolved: $*" >&2
    exit 1
}

# Use the local Gateway credential without changing its configuration.
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

# GatewayTransport class equivalent
GatewayTransport() {
    local state_file="$1"
    local url="$2"
    local token="$3"
    local timeout="${4:-3900}"
    local interval="${5:-3}"
    
    # Validate inputs
    if [[ ! "$url" =~ ^https?://[^/]+ ]]; then
        echo "invalid Gateway URL" >&2
        exit 1
    fi
    
    local scheme hostname
    scheme=$(echo "$url" | sed -E 's|^([a-z]+)://([^/]+).*|\1|')
    hostname=$(echo "$url" | sed -E 's|^([a-z]+)://([^/]+).*|\2|')
    
    if [[ "$scheme" == "http" ]] && [[ ! "$hostname" =~ ^(127\.0\.0\.1|localhost|::1)$ ]]; then
        echo "unencrypted Gateway must use loopback" >&2
        exit 1
    fi
    
    if [[ -z "$token" ]] || [[ "$timeout" -le 0 ]] || [[ "$interval" -le 0 ]]; then
        echo "Gateway token and positive timeouts required" >&2
        exit 1
    fi
    
    # Store configuration
    GW_STATE_FILE="$state_file"
    GW_URL="$url"
    GW_TOKEN="$token"
    GW_TIMEOUT="$timeout"
    GW_INTERVAL="$interval"
}

# Internal function to make HTTP requests
_request() {
    local node="$1"
    local request_json="$2"
    local device_id="${3:-}"
    
    local payload device_field=""
    if [[ -n "$device_id" ]]; then
        device_field=",\"device_id\":\"$device_id\""
    fi
    
    payload="{\"node\":\"$node\"$device_field,\"request\":$request_json}"
    
    local timeout_val=40
    if [[ "$node" == "node4" ]]; then
        timeout_val=150
    fi
    
    local response
    response=$(curl -s -m "$timeout_val" \
        -H "Authorization: Bearer $GW_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$GW_URL") || transport_unresolved "Gateway request failed"
    
    # Check response size (approximate)
    if [[ ${#response} -gt 4000000 ]]; then
        transport_unresolved "response too large"
    fi
    
    # Validate response structure
    if ! echo "$response" | jq -e 'type == "object" and has("result")' >/dev/null 2>&1; then
        transport_unresolved "invalid gateway response"
    fi
    
    # Check device ID match if provided
    if [[ -n "$device_id" ]]; then
        local resp_device_id
        resp_device_id=$(echo "$response" | jq -r '.device_id // ""')
        if [[ "$resp_device_id" != "$device_id" ]]; then
            transport_unresolved "gateway device identity mismatch"
        fi
    fi
    
    echo "$response" | jq -c '.result'
}

available() {
    local result
    result=$(_request "node1" '{"operation":"availability"}')
    
    if ! echo "$result" | jq -e 'type == "object"' >/dev/null 2>&1; then
        transport_unresolved "invalid node availability"
    fi
    
    echo "$result"
}

_release() {
    local original_json="$1"
    local entry_key="$2"
    
    # Check if already released
    if jq -e ".auftraege[\"$entry_key\"].released == true" "$GW_STATE_FILE" >/dev/null 2>&1; then
        return
    fi
    
    local job_id selected_node attempt_id target_language selected_device_id
    job_id=$(echo "$original_json" | jq -r '.job_id')
    selected_node=$(echo "$original_json" | jq -r '.selected_node')
    attempt_id=$(echo "$original_json" | jq -r '.attempt_id')
    target_language=$(echo "$original_json" | jq -r '.target_language')
    selected_device_id=$(echo "$original_json" | jq -r '.selected_device_id')
    
    local result
    if result=$(_request "$selected_node" "{\"operation\":\"release\",\"job_id\":\"$job_id\",\"attempt_id\":\"$attempt_id\"}" "$selected_device_id" 2>/dev/null); then
        local status check_job_id check_attempt_id check_selected_node check_target_language
        status=$(echo "$result" | jq -r '.status // ""')
        check_job_id=$(echo "$result" | jq -r '.job_id // ""')
        check_attempt_id=$(echo "$result" | jq -r '.attempt_id // ""')
        check_selected_node=$(echo "$result" | jq -r '.selected_node // ""')
        check_target_language=$(echo "$result" | jq -r '.target_language // ""')
        
        if [[ "$status" == "released" ]] && \
           [[ "$check_job_id" == "$job_id" ]] && \
           [[ "$check_attempt_id" == "$attempt_id" ]] && \
           [[ "$check_selected_node" == "$selected_node" ]] && \
           [[ "$check_target_language" == "$target_language" ]]; then
            jq ".auftraege[\"$entry_key\"].released = true" "$GW_STATE_FILE" > "${GW_STATE_FILE}.tmp" && mv "${GW_STATE_FILE}.tmp" "$GW_STATE_FILE"
        fi
    fi
    # Ignore errors - retry cleanup later
}

release_pending() {
    local keys
    keys=$(jq -r '.auftraege | keys[]' "$GW_STATE_FILE" 2>/dev/null) || return 0
    
    local key
    while IFS= read -r key; do
        local status selected_device_id
        status=$(jq -r ".auftraege[\"$key\"].status // empty" "$GW_STATE_FILE")
        selected_device_id=$(jq -r ".auftraege[\"$key\"].job.selected_device_id // empty" "$GW_STATE_FILE")
        
        if [[ ("$status" == "completed" || "$status" == "failed" || "$status" == "unknown") ]] && [[ -n "$selected_device_id" ]]; then
            local job_json
            job_json=$(jq -c ".auftraege[\"$key\"].job" "$GW_STATE_FILE")
            _release "$job_json" "$key"
        fi
    done <<< "$keys"
}

call_transport() {
    local job_json="$1"
    
    local source_sha256 target_language selected_device_id
    source_sha256=$(echo "$job_json" | jq -r '.source_sha256 // ""')
    target_language=$(echo "$job_json" | jq -r '.target_language // ""')
    selected_device_id=$(echo "$job_json" | jq -r '.selected_device_id // ""')
    
    if [[ -z "$source_sha256" ]] || [[ -z "$target_language" ]] || [[ -z "$selected_device_id" ]]; then
        echo "missing source identity" >&2
        exit 1
    fi
    
    local key="${source_sha256}:${target_language}"
    
    # Check if entry exists
    if ! jq -e ".auftraege[\"$key\"]" "$GW_STATE_FILE" >/dev/null 2>&1; then
        # Create new entry
        local attempt_id
        attempt_id=$(uuidgen)
        
        local original_json
        original_json=$(echo "$job_json" | jq --arg aid "$attempt_id" '. + {attempt_id: $aid}')
        
        local entry_json
        entry_json=$(jq -n --argjson job "$original_json" '{job: $job, status: "submitted"}')
        
        # Save state before remote submission
        jq --arg key "$key" --argjson entry "$entry_json" '.auftraege[$key] = $entry' "$GW_STATE_FILE" > "${GW_STATE_FILE}.tmp" && mv "${GW_STATE_FILE}.tmp" "$GW_STATE_FILE"
        
        local status=""
        # Try initial execution
        local selected_node
        selected_node=$(echo "$original_json" | jq -r '.selected_node')
        if _request "$selected_node" "{\"operation\":\"execute\",\"job\":$(echo "$original_json" | jq -c .)}" "$(echo "$original_json" | jq -r '.selected_device_id')" >/dev/null 2>&1; then
            status="success"
        else
            # Request may have been accepted, so we'll query instead of resending
            :
        fi
    else
        # Entry exists, get existing data
        local original_json status_val
        original_json=$(jq -c ".auftraege[\"$key\"].job" "$GW_STATE_FILE")
        status_val=$(jq -r ".auftraege[\"$key\"].status // \"\"" "$GW_STATE_FILE")
        
        # Update job with original data
        local updated_job
        updated_job=$(echo "$job_json" | jq --argjson orig "$original_json" '. + $orig')
        echo "$updated_job" > "/tmp/job_update_$$_$(date +%s)"
        
        # Check if we have a cached response
        if jq -e ".auftraege[\"$key\"].response" "$GW_STATE_FILE" >/dev/null 2>&1; then
            local response
            response=$(jq -c ".auftraege[\"$key\"].response" "$GW_STATE_FILE")
            _release "$original_json" "$key"
            echo "$response"
            return
        fi
        
        # Check if status indicates failure requiring reconciliation
        if [[ "$status_val" == "failed" ]] || [[ "$status_val" == "unknown" ]]; then
            transport_unresolved "attempt requires reconciliation"
        fi
    fi
    
    # Query loop
    local deadline
    deadline=$(( $(date +%s) + GW_TIMEOUT ))
    
    while true; do
        local status_response
        local job_id attempt_id selected_node target_language selected_device_id
        job_id=$(echo "$original_json" | jq -r '.job_id')
        attempt_id=$(echo "$original_json" | jq -r '.attempt_id')
        selected_node=$(echo "$original_json" | jq -r '.selected_node')
        target_language=$(echo "$original_json" | jq -r '.target_language')
        selected_device_id=$(echo "$original_json" | jq -r '.selected_device_id')
        
        status_response=$(_request "$selected_node" "{\"operation\":\"status\",\"job_id\":\"$job_id\",\"attempt_id\":\"$attempt_id\"}" "$selected_device_id")
        
        # Validate status response
        local check_job_id check_attempt_id check_selected_node check_target_language
        check_job_id=$(echo "$status_response" | jq -r '.job_id // ""')
        check_attempt_id=$(echo "$status_response" | jq -r '.attempt_id // ""')
        check_selected_node=$(echo "$status_response" | jq -r '.selected_node // ""')
        check_target_language=$(echo "$status_response" | jq -r '.target_language // ""')
        
        if [[ "$check_job_id" != "$job_id" ]] || \
           [[ "$check_attempt_id" != "$attempt_id" ]] || \
           [[ "$check_selected_node" != "$selected_node" ]] || \
           [[ "$check_target_language" != "$target_language" ]]; then
            transport_unresolved "status identity mismatch"
        fi
        
        local state
        state=$(echo "$status_response" | jq -r '.status // ""')
        
        if [[ "$state" == "completed" ]]; then
            local response
            response=$(echo "$status_response" | jq -c '.response // {}')
            
            # Validate response
            local resp_status code
            resp_status=$(echo "$response" | jq -r '.status // ""')
            code=$(echo "$response" | jq -r '.code // ""')
            
            local resp_job_id resp_selected_node resp_target_language
            resp_job_id=$(echo "$response" | jq -r '.job_id // ""')
            resp_selected_node=$(echo "$response" | jq -r '.selected_node // ""')
            resp_target_language=$(echo "$response" | jq -r '.target_language // ""')
            
            if [[ "$resp_status" != "ok" ]] || \
               [[ "$resp_job_id" != "$job_id" ]] || \
               [[ "$resp_selected_node" != "$selected_node" ]] || \
               [[ "$resp_target_language" != "$target_language" ]] || \
               [[ -z "$code" ]] || [[ -z "${code// }" ]]; then
                transport_unresolved "invalid translation result"
            fi
            
            # Save successful response
            jq --arg key "$key" --argjson resp "$response" '.auftraege[$key].response = $resp | .auftraege[$key].status = "completed"' "$GW_STATE_FILE" > "${GW_STATE_FILE}.tmp" && mv "${GW_STATE_FILE}.tmp" "$GW_STATE_FILE"
            _release "$original_json" "$key"
            echo "$response"
            return
        elif [[ "$state" == "failed" ]] || [[ "$state" == "unknown" ]]; then
            jq --arg key "$key" --arg state "$state" '.auftraege[$key].status = $state' "$GW_STATE_FILE" > "${GW_STATE_FILE}.tmp" && mv "${GW_STATE_FILE}.tmp" "$GW_STATE_FILE"
            _release "$original_json" "$key"
            transport_unresolved "attempt requires reconciliation"
        elif [[ "$state" != "running" ]] || [[ $(date +%s) -ge $deadline ]]; then
            transport_unresolved "attempt is unresolved"
        fi
        
        sleep "$GW_INTERVAL"
    done
}
