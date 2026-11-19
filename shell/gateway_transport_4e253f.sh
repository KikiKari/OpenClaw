#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "926047aa718be5518dc5b2daa562b4db6812f2be4411de2c405623758108f27e", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "shell"}
# gateway_transport.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

# Runtime dependencies: curl, jq, uuidgen (or built-in $RANDOM), flock

declare -A OPENCLAW_CONFIG_DEFAULTS=(
    [config_path]="$HOME/.openclaw/openclaw.json"
)

# Exception simulation
transport_unresolved() {
    echo "TransportUnresolved: $*" >&2
    exit 70  # EX_SOFTWARE
}

# Get gateway token from environment or config file
gateway_token() {
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"
    if [[ -n "${token}" ]]; then
        echo "${token}"
        return
    fi

    local config_path="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_CONFIG_DEFAULTS[config_path]}}"
    if [[ ! -f "${config_path}" ]]; then
        echo ""
        return
    fi

    # Try to extract token using jq
    if command -v jq >/dev/null 2>&1; then
        token=$(jq -r '.gateway.auth.token // ""' "${config_path}" 2>/dev/null) || token=""
    else
        # Fallback: basic grep/awk extraction
        token=$(grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' "${config_path}" 2>/dev/null | \
                sed -e 's/"token"[[:space:]]*:[[:space:]]*"//' -e 's/"[[:space:]]*$//' 2>/dev/null) || token=""
    fi

    # Check if token looks like a placeholder
    if [[ "${token}" =~ ^\$\\\{.*\\\}$ ]] || [[ "${token}" =~ ^\$\{.*\}$ ]]; then
        echo ""
    else
        echo "${token}"
    fi
}

# GatewayTransport class equivalent
GatewayTransport() {
    local state_file="$1"
    local save_function="$2"
    local url="$3"
    local token="$4"
    local timeout="${5:-3900}"
    local interval="${6:-3}"

    # Validate URL
    if [[ ! "${url}" =~ ^https?://[^/]+ ]]; then
        echo "invalid Gateway URL" >&2
        return 1
    fi

    local scheme hostname
    scheme=$(echo "${url}" | sed -E 's|^([^:]+)://.*|\1|')
    hostname=$(echo "${url}" | sed -E 's|^[^:]+://([^/]*)(/.*)?$|\1|' | cut -d: -f1)

    if [[ "${scheme}" == "http" ]] && [[ ! "${hostname}" =~ ^(127\.0\.0\.1|localhost|::1)$ ]]; then
        echo "unencrypted Gateway must use loopback" >&2
        return 1
    fi

    if [[ -z "${token// /}" ]] || (( timeout <= 0 )) || (( interval <= 0 )); then
        echo "Gateway token and positive timeouts required" >&2
        return 1
    fi

    # Store parameters in global variables with prefix
    GW_URL="${url}"
    GW_TOKEN="${token}"
    GW_TIMEOUT="${timeout}"
    GW_INTERVAL="${interval}"
    GW_STATE_FILE="${state_file}"
    GW_SAVE_FUNCTION="${save_function}"

    export GW_URL GW_TOKEN GW_TIMEOUT GW_INTERVAL GW_STATE_FILE GW_SAVE_FUNCTION
}

# Internal function to make HTTP requests
_gateway_request() {
    local node="$1"
    local request_json="$2"
    local device_id="${3:-}"

    local payload
    if [[ -n "${device_id}" ]]; then
        payload=$(jq -n --arg node "${node}" --arg device_id "${device_id}" --argjson request "${request_json}" \
            '{node: $node, device_id: $device_id, request: $request}')
    else
        payload=$(jq -n --arg node "${node}" --argjson request "${request_json}" \
            '{node: $node, request: $request}')
    fi

    local timeout_val=40
    if [[ "${node}" == "node4" ]]; then
        timeout_val=150
    fi

    local response_file response_data
    response_file=$(mktemp)
    trap "rm -f '${response_file}'" EXIT

    if ! curl -s -f -m "${timeout_val}" \
        -H "Authorization: Bearer ${GW_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${GW_URL}" >"${response_file}"; then
        transport_unresolved "Gateway request failed"
    fi

    # Check size limit (approximate)
    if [[ $(stat -c%s "${response_file}" 2>/dev/null || stat -f%z "${response_file}" 2>/dev/null) -gt 4000000 ]]; then
        transport_unresolved "response too large"
    fi

    response_data=$(cat "${response_file}")
    
    # Validate JSON structure
    if ! echo "${response_data}" | jq -e 'type == "object" and has("result")' >/dev/null 2>&1; then
        transport_unresolved "invalid gateway response"
    fi

    # Check device ID if provided
    if [[ -n "${device_id}" ]]; then
        local returned_device_id
        returned_device_id=$(echo "${response_data}" | jq -r '.device_id // empty')
        if [[ "${returned_device_id}" != "${device_id}" ]]; then
            transport_unresolved "gateway device identity mismatch"
        fi
    fi

    echo "${response_data}" | jq -c '.result'
}

# Check node availability
available() {
    local result
    result=$(_gateway_request "node1" '{"operation": "availability"}')

    if ! echo "${result}" | jq -e 'type == "object"' >/dev/null 2>&1; then
        transport_unresolved "invalid node availability"
    fi

    echo "${result}"
}

# Release a job
_release() {
    local original_ref="$1"
    local entry_ref="$2"

    # Check if already released
    if [[ "$(echo "${entry_ref}" | jq -r '.released // false')" == "true" ]]; then
        return
    fi

    local selected_node job_id attempt_id selected_device_id
    selected_node=$(echo "${original_ref}" | jq -r '.selected_node')
    job_id=$(echo "${original_ref}" | jq -r '.job_id')
    attempt_id=$(echo "${original_ref}" | jq -r '.attempt_id')
    selected_device_id=$(echo "${original_ref}" | jq -r '.selected_device_id')

    local result
    if ! result=$(_gateway_request "${selected_node}" \
        "{\"operation\": \"release\", \"job_id\": \"${job_id}\", \"attempt_id\": \"${attempt_id}\"}" \
        "${selected_device_id}" 2>/dev/null); then
        return  # Retry cleanup later
    fi

    local status
    status=$(echo "${result}" | jq -r '.status // empty')

    if [[ "${status}" == "released" ]]; then
        local match=true
        for key in job_id attempt_id selected_node target_language; do
            local orig_val result_val
            orig_val=$(echo "${original_ref}" | jq -r ".${key}")
            result_val=$(echo "${result}" | jq -r ".${key}")
            if [[ "${orig_val}" != "${result_val}" ]]; then
                match=false
                break
            fi
        done

        if [[ "${match}" == "true" ]]; then
            local updated_entry
            updated_entry=$(echo "${entry_ref}" | jq '.released = true')
            eval "${GW_SAVE_FUNCTION}" "${updated_entry}"
        fi
    fi
}

# Release pending jobs
release_pending() {
    local state_content entry_key entry_value
    state_content=$(cat "${GW_STATE_FILE}")

    # Process each auftrag
    local keys
    keys=$(echo "${state_content}" | jq -r '.auftraege | keys[]' 2>/dev/null) || return 0
    
    for entry_key in ${keys}; do
        entry_value=$(echo "${state_content}" | jq -c ".auftraege.\"${entry_key}\"")
        
        local status job_ref
        status=$(echo "${entry_value}" | jq -r '.status // empty')
        job_ref=$(echo "${entry_value}" | jq -c '.job // {}')
        
        if [[ "${status}" =~ ^(completed|rejected|failed)$ ]] && \
           [[ "$(echo "${job_ref}" | jq 'type == "object"')" == "true" ]]; then
            _release "${job_ref}" "${entry_value}"
        fi
    done
}

# Reject a job
reject() {
    local job_ref="$1"
    local reason="$2"

    local source_sha256 target_language key
    source_sha256=$(echo "${job_ref}" | jq -r '.source_sha256 // empty')
    target_language=$(echo "${job_ref}" | jq -r '.target_language // empty')
    
    if [[ -z "${source_sha256}" ]] || [[ -z "${target_language}" ]]; then
        return
    fi
    
    key="${source_sha256}:${target_language}"
    
    local state_content entry_ref
    state_content=$(cat "${GW_STATE_FILE}")
    entry_ref=$(echo "${state_content}" | jq -c ".auftraege.\"${key}\" // null")
    
    if [[ "$(echo "${entry_ref}" | jq 'type == "object" and .status == "completed"')" != "true" ]]; then
        return
    fi
    
    local job_attempt_id entry_job_attempt_id
    job_attempt_id=$(echo "${job_ref}" | jq -r '.attempt_id // empty')
    entry_job_attempt_id=$(echo "${entry_ref}" | jq -r '.job.attempt_id // empty')
    
    if [[ "${job_attempt_id}" != "${entry_job_attempt_id}" ]]; then
        transport_unresolved "rejected attempt identity mismatch"
    fi
    
    local updated_entry
    updated_entry=$(echo "${entry_ref}" | jq \
        --arg reason "${reason:0:500}" \
        '.status = "rejected" | .validation_error = $reason')
    
    # Update state
    local updated_state
    updated_state=$(echo "${state_content}" | jq --argjson entry "${updated_entry}" ".auftraege.\"${key}\" = \$entry")
    echo "${updated_state}" >"${GW_STATE_FILE}"
}

# Main transport function
call_transport() {
    local job_ref="$1"
    
    local source_sha256 target_language selected_device_id key
    source_sha256=$(echo "${job_ref}" | jq -r '.source_sha256 // empty')
    target_language=$(echo "${job_ref}" | jq -r '.target_language // empty')
    selected_device_id=$(echo "${job_ref}" | jq -r '.selected_device_id // empty')
    
    if [[ -z "${source_sha256}" ]] || [[ -z "${target_language}" ]] || [[ -z "${selected_device_id}" ]]; then
        echo "missing source identity" >&2
        return 1
    fi
    
    key="${source_sha256}:${target_language}"
    
    local state_content entries_ref entry_ref
    state_content=$(cat "${GW_STATE_FILE}")
    entries_ref=$(echo "${state_content}" | jq -c '.auftraege // {}')
    entry_ref=$(echo "${entries_ref}" | jq -c ".\"${key}\" // null")
    
    local fresh=false
    local original_ref="${job_ref}"
    
    if [[ "$(echo "${entry_ref}" | jq 'type == "object" and .status == "rejected"')" == "true" ]]; then
        local job_in_entry prev_attempts
        job_in_entry=$(echo "${entry_ref}" | jq -c '.job')
        _release "${job_in_entry}" "${entry_ref}"
        
        if [[ "$(echo "${entry_ref}" | jq -r '.released // false')" != "true" ]]; then
            transport_unresolved "rejected attempt release is unresolved"
        fi
        
        local previous_ref="${entry_ref}"
        local new_attempt_id
        new_attempt_id=$(uuidgen 2>/dev/null || echo "attempt_$(date +%s)_$$")
        
        original_ref=$(echo "${job_ref}" | jq --arg id "${new_attempt_id}" '. + {attempt_id: $id}')
        
        prev_attempts=$(echo "${previous_ref}" | jq -c '.previous_attempts // []')
        local prev_job_id prev_attempt_id prev_selected_node prev_validation_error
        prev_job_id=$(echo "${previous_ref}" | jq -r '.job.job_id // empty')
        prev_attempt_id=$(echo "${previous_ref}" | jq -r '.job.attempt_id // empty')
        prev_selected_node=$(echo "${previous_ref}" | jq -r '.job.selected_node // empty')
        prev_validation_error=$(echo "${previous_ref}" | jq -r '.validation_error // empty')
        
        local new_prev_attempt
        new_prev_attempt=$(jq -n \
            --arg job_id "${prev_job_id}" \
            --arg attempt_id "${prev_attempt_id}" \
            --arg selected_node "${prev_selected_node}" \
            --arg validation_error "${prev_validation_error}" \
            '{job_id: $job_id, attempt_id: $attempt_id, selected_node: $selected_node, validation_error: $validation_error}')
            
        prev_attempts=$(echo "${prev_attempts}" | jq -c ". + [${new_prev_attempt}]")
        
        entry_ref=$(jq -n --argjson job "${original_ref}" --argjson prev "${prev_attempts}" \
            '{job: $job, status: "submitted", previous_attempts: $prev}')
        
        entries_ref=$(echo "${entries_ref}" | jq --argjson entry "${entry_ref}" ".\"${key}\" = \$entry")
        state_content=$(echo "${state_content}" | jq --argjson entries "${entries_ref}" '.auftraege = $entries')
        echo "${state_content}" >"${GW_STATE_FILE}"
        fresh=true
    elif [[ "$(echo "${entry_ref}" | jq 'type == "null"')" == "true" ]]; then
        local new_attempt_id
        new_attempt_id=$(uuidgen 2>/dev/null || echo "attempt_$(date +%s)_$$")
        original_ref=$(echo "${job_ref}" | jq --arg id "${new_attempt_id}" '. + {attempt_id: $id}')
        entry_ref=$(jq -n --argjson job "${original_ref}" '{job: $job, status: "submitted"}')
        entries_ref=$(echo "${entries_ref}" | jq --argjson entry "${entry_ref}" ".\"${key}\" = \$entry")
        state_content=$(echo "${state_content}" | jq --argjson entries "${entries_ref}" '.auftraege = $entries')
        echo "${state_content}" >"${GW_STATE_FILE}"
        fresh=true
    else
        original_ref=$(echo "${entry_ref}" | jq -c '.job')
    fi
    
    # Update job with original values
    local updated_job
    updated_job=$(echo "${job_ref}" | jq --argjson orig "${original_ref}" '. + $orig')
    echo "${updated_job}"
    
    # Return cached response if exists
    local response
    response=$(echo "${entry_ref}" | jq -r '.response // empty')
    if [[ -n "${response}" ]]; then
        local job_in_entry
        job_in_entry=$(echo "${entry_ref}" | jq -c '.job')
        _release "${job_in_entry}" "${entry_ref}"
        echo "${response}"
        return 0
    fi
    
    # Handle failed/unknown states
    local status_field
    status_field=$(echo "${entry_ref}" | jq -r '.status // empty')
    if [[ "${status_field}" =~ ^(failed|unknown)$ ]]; then
        transport_unresolved "attempt requires reconciliation"
    fi
    
    local status_result=""
    
    # Submit fresh request
    if [[ "${fresh}" == "true" ]]; then
        local selected_node_ref
        selected_node_ref=$(echo "${original_ref}" | jq -r '.selected_node')
        local job_data
        job_data=$(echo "${original_ref}" | jq -c '.')
        
        if ! status_result=$(_gateway_request "${selected_node_ref}" \
            "{\"operation\": \"execute\", \"job\": ${job_data}}" \
            "$(echo "${original_ref}" | jq -r '.selected_device_id')" 2>/dev/null); then
            :  # Continue to querying phase
        fi
    fi
    
    # Query loop
    local start_time deadline_time current_time
    start_time=$(date +%s)
    deadline_time=$((start_time + GW_TIMEOUT))
    
    while true; do
        if [[ -z "${status_result}" ]]; then
            local job_id_ref attempt_id_ref selected_node_ref target_lang_ref
            job_id_ref=$(echo "${original_ref}" | jq -r '.job_id')
            attempt_id_ref=$(echo "${original_ref}" | jq -r '.attempt_id')
            selected_node_ref=$(echo "${original_ref}" | jq -r '.selected_node')
            target_lang_ref=$(echo "${original_ref}" | jq -r '.target_language')
            
            status_result=$(_gateway_request "${selected_node_ref}" \
                "{\"operation\": \"status\", \"job_id\": \"${job_id_ref}\", \"attempt_id\": \"${attempt_id_ref}\"}" \
                "$(echo "${original_ref}" | jq -r '.selected_device_id')")
        fi
        
        if [[ "$(echo "${status_result}" | jq 'type == "object"')" != "true" ]]; then
            transport_unresolved "attempt is not known by the node"
        fi
        
        # Verify identity fields
        for key in job_id attempt_id selected_node target_language; do
            local orig_val result_val
            orig_val=$(echo "${original_ref}" | jq -r ".${key}")
            result_val=$(echo "${status_result}" | jq -r ".${key}")
            if [[ "${orig_val}" != "${result_val}" ]]; then
                transport_unresolved "status identity mismatch"
            fi
        done
        
        local state_val
        state_val=$(echo "${status_result}" | jq -r '.status')
        
        if [[ "${state_val}" == "completed" ]]; then
            local response_data
            response_data=$(echo "${status_result}" | jq -c '.response')
            
            # Validate response
            if [[ "$(echo "${response_data}" | jq 'type == "object" and .status == "ok"')" != "true" ]]; then
                transport_unresolved "invalid translation result"
            fi
            
            for key in job_id selected_node target_language; do
                local orig_val resp_val
                orig_val=$(echo "${original_ref}" | jq -r ".${key}")
                resp_val=$(echo "${response_data}" | jq -r ".${key}")
                if [[ "${orig_val}" != "${resp_val}" ]]; then
                    transport_unresolved "invalid translation result"
                fi
            done
            
            local code_val
            code_val=$(echo "${response_data}" | jq -r '.code // empty')
            if [[ -z "${code_val// }" ]]; then
                transport_unresolved "invalid translation result"
            fi
            
            # Update entry and save
            entry_ref=$(echo "${entry_ref}" | jq --argjson resp "${response_data}" '.response = $resp | .status = "completed"')
            entries_ref=$(echo "${entries_ref}" | jq --argjson entry "${entry_ref}" ".\"${key}\" = \$entry")
            state_content=$(echo "${state_content}" | jq --argjson entries "${entries_ref}" '.auftraege = $entries')
            echo "${state_content}" >"${GW_STATE_FILE}"
            
            local job_in_entry
            job_in_entry=$(echo "${entry_ref}" | jq -c '.job')
            _release "${job_in_entry}" "${entry_ref}"
            
            echo "${response_data}"
            return 0
        elif [[ "${state_val}" =~ ^(failed|unknown)$ ]]; then
            entry_ref=$(echo "${entry_ref}" | jq --arg st "${state_val}" '.status = $st')
            entries_ref=$(echo "${entries_ref}" | jq --argjson entry "${entry_ref}" ".\"${key}\" = \$entry")
            state_content=$(echo "${state_content}" | jq --argjson entries "${entries_ref}" '.auftraege = $entries')
            echo "${state_content}" >"${GW_STATE_FILE}"
            
            if [[ "${state_val}" == "failed" ]]; then
                local job_in_entry
                job_in_entry=$(echo "${entry_ref}" | jq -c '.job')
                _release "${job_in_entry}" "${entry_ref}"
            fi
            
            transport_unresolved "attempt requires reconciliation"
        elif [[ "${state_val}" != "running" ]]; then
            transport_unresolved "attempt is unresolved"
        fi
        
        current_time=$(date +%s)
        if (( current_time >= deadline_time )); then
            transport_unresolved "attempt is unresolved"
        fi
        
        sleep "${GW_INTERVAL}"
        status_result=""
    done
}
