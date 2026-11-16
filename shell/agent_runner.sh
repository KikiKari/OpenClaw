#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "9f577e47cf6b16da34b821221f9aad50409bd32f637d273c0beadb2f35173080", "source_sha256": "bb3a3622a1b49888ef51f2b6fac687955ed97e97b6ee7a16d4e47117a764be29", "target_language": "shell"}
# agent_runner.py — portiert nach shell
# Quelle: python, workspace@local:skills/sub-agents-utils/scripts/agent_runner.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Run a gateway-only OpenClaw agent turn for a porting task.

# Function to get allowed models from config
allowed_models() {
    local config_path="$1"
    local models_json
    local defaults_json
    local models_set=""
    
    if [[ ! -f "$config_path" ]]; then
        echo ""
        return
    fi
    
    # Extract agents.defaults section
    defaults_json=$(jq -r '.agents.defaults // {}' "$config_path" 2>/dev/null || echo "{}")
    
    # Get models array if it exists
    models_json=$(echo "$defaults_json" | jq -r '.models // []' 2>/dev/null || echo "[]")
    
    # Add each model to our set
    while IFS= read -r model; do
        if [[ -n "$model" && "$model" != "null" ]]; then
            models_set="${models_set}${model}"$'\n'
        fi
    done < <(echo "$models_json" | jq -r '.[]' 2>/dev/null || true)
    
    # Handle single model string
    local single_model
    single_model=$(echo "$defaults_json" | jq -r '.model // empty' 2>/dev/null || true)
    if [[ -n "$single_model" && "$single_model" != "null" ]]; then
        models_set="${models_set}${single_model}"$'\n'
    fi
    
    # Handle model object with primary and fallbacks
    if echo "$defaults_json" | jq -e '.model | type == "object"' >/dev/null 2>&1; then
        local primary
        primary=$(echo "$defaults_json" | jq -r '.model.primary // empty' 2>/dev/null || true)
        if [[ -n "$primary" && "$primary" != "null" ]]; then
            models_set="${models_set}${primary}"$'\n'
        fi
        
        local fallbacks_json
        fallbacks_json=$(echo "$defaults_json" | jq -r '.model.fallbacks // []' 2>/dev/null || echo "[]")
        while IFS= read -r fallback; do
            if [[ -n "$fallback" && "$fallback" != "null" ]]; then
                models_set="${models_set}${fallback}"$'\n'
            fi
        done < <(echo "$fallbacks_json" | jq -r '.[]' 2>/dev/null || true)
    fi
    
    echo -n "$models_set" | sort -u
}

# Main run function
run() {
    local task="$1"
    local model="$2"
    local timeout="$3"
    
    # Validate inputs
    if [[ -z "${task// }" ]] || [[ ${#task} -gt 500 ]]; then
        echo "task must contain 1–500 characters" >&2
        return 1
    fi
    
    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [[ $timeout -lt 1 ]] || [[ $timeout -gt 7200 ]]; then
        echo "timeout must be between 1 and 7200 seconds" >&2
        return 1
    fi
    
    # Determine config path
    local config_path="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
    
    # Check if model is allowed
    local is_allowed=false
    while IFS= read -r allowed_model; do
        if [[ "$model" == "$allowed_model" ]]; then
            is_allowed=true
            break
        fi
    done < <(allowed_models "$config_path")
    
    if [[ "$is_allowed" != "true" ]]; then
        echo "model is not in the configured OpenClaw model allowlist" >&2
        return 1
    fi
    
    # Parse provider and model_id
    local provider model_id
    IFS='/' read -r provider model_id <<< "$model"
    
    if [[ -z "$provider" ]] || [[ -z "$model_id" ]] || [[ "$model" != *"/*" ]]; then
        echo "model must have provider/model form" >&2
        return 1
    fi
    
    # Generate UUID for run_id
    local run_id
    run_id=$(uuidgen 2>/dev/null || echo "$(date +%s)_${RANDOM}")
    
    # Build parameters JSON
    local params_json
    params_json=$(jq -n \
        --arg message "${task//[$'\n\r']}" \
        --arg provider "$provider" \
        --arg model "$model_id" \
        --arg sessionKey "agent:main:abstraction-runner:$run_id" \
        --arg idempotencyKey "$run_id" \
        --arg timeout_str "$timeout" \
        --arg deliver "false" \
        '{
            message: $message,
            provider: $provider,
            model: $model,
            sessionKey: $sessionKey,
            idempotencyKey: $idempotencyKey,
            timeout: ($timeout_str | tonumber),
            deliver: ($deliver | test("true"))
        }')
    
    # Calculate command timeout
    local cmd_timeout=$((timeout + 20))
    local openclaw_timeout_ms=$(((timeout + 10) * 1000))
    
    # Execute the command
    local output
    if ! output=$(timeout "$cmd_timeout" openclaw gateway call agent \
        --params "$params_json" \
        --expect-final \
        --json \
        --timeout "$openclaw_timeout_ms" 2>&1); then
        echo "${output:-OpenClaw agent call failed}" >&2
        return 1
    fi
    
    # Validate JSON response
    if ! echo "$output" | jq empty 2>/dev/null; then
        echo "OpenClaw returned invalid JSON" >&2
        return 1
    fi
    
    # Check status
    local status
    status=$(echo "$output" | jq -r '.status // ""' 2>/dev/null || echo "")
    if [[ "$status" != "ok" ]]; then
        echo "OpenClaw did not return a completed agent result" >&2
        return 1
    fi
    
    # Check result structure
    local has_result
    has_result=$(echo "$output" | jq -r 'has("result")' 2>/dev/null || echo "false")
    if [[ "$has_result" != "true" ]]; then
        echo "OpenClaw returned no agent result" >&2
        return 1
    fi
    
    # Check meta info
    local meta_aborted meta_error
    meta_aborted=$(echo "$output" | jq -r '.result.meta.aborted // false' 2>/dev/null || echo "false")
    meta_error=$(echo "$output" | jq -r '.result.meta.error // false' 2>/dev/null || echo "false")
    
    if [[ "$meta_aborted" == "true" ]] || [[ "$meta_error" == "true" ]]; then
        echo "OpenClaw agent execution did not complete successfully" >&2
        return 1
    fi
    
    # Check payloads for errors and content
    local payloads_count payload_index payload_is_error payload_text
    payloads_count=$(echo "$output" | jq '(.result.payloads | length) // 0' 2>/dev/null || echo "0")
    
    for ((payload_index=0; payload_index<payloads_count; payload_index++)); do
        payload_is_error=$(echo "$output" | jq -r ".result.payloads[$payload_index].isError // false" 2>/dev/null || echo "false")
        if [[ "$payload_is_error" == "true" ]]; then
            echo "OpenClaw agent returned an error" >&2
            return 1
        fi
    done
    
    # Check for text content
    local found_text=false
    for ((payload_index=0; payload_index<payloads_count; payload_index++)); do
        payload_text=$(echo "$output" | jq -r ".result.payloads[$payload_index].text // \"\"" 2>/dev/null || echo "")
        if [[ -n "${payload_text// }" ]]; then
            found_text=true
            break
        fi
    done
    
    if [[ "$found_text" != "true" ]]; then
        echo "OpenClaw agent returned no text" >&2
        return 1
    fi
    
    # Output final result
    echo "$output"
    return 0
}

# Main function
main() {
    local task=""
    local model=""
    local timeout=1800
    local gateway_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --task)
                task="$2"
                shift 2
                ;;
            --model)
                model="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --gateway-only)
                gateway_only=true
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Check required arguments
    if [[ -z "$task" ]] || [[ -z "$model" ]]; then
        echo "Both --task and --model are required" >&2
        return 1
    fi
    
    # Check gateway-only flag
    if [[ "$gateway_only" != "true" ]]; then
        echo "agent_runner: no worker/relay transport configured; gateway-only requires --gateway-only" >&2
        return 1
    fi
    
    # Run the main logic
    if ! run "$task" "$model" "$timeout"; then
        return 1
    fi
    
    return 0
}

# Entry point
main "$@"
