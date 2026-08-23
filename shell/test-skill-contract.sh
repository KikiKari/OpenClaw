#!/usr/bin/env bash
# test-skill-contract.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/tiktok-live/scripts/test-skill-contract.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Regression checks for the documented /tiktok_live normal flow.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SKILL="$SCRIPT_DIR/../SKILL.md"
readonly CANONICAL_COMMAND="/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --quality auto --json"
readonly NODE_COMMAND="$CANONICAL_COMMAND"

# Helper function to check if text contains a substring
text_contains() {
    local text="$1"
    local search="$2"
    [[ "$text" == *"$search"* ]]
}

# Helper function to count occurrences of a string in text
count_occurrences() {
    local text="$1"
    local search="$2"
    echo "$text" | grep -oF "$search" | wc -l
}

# Read skill file content
text=$(cat "$SKILL")
normalized_text=$(echo "$text" | tr -s '[:space:]' ' ')

# Test functions
test_dispatcher_is_the_documented_first_action() {
    if ! text_contains "$text" "Make the existing dispatcher the first action"; then
        echo "FAIL: Make the existing dispatcher the first action not found in text"
        return 1
    fi
    
    if ! text_contains "$normalized_text" "first tool call of the request"; then
        echo "FAIL: first tool call of the request not found in normalized text"
        return 1
    fi
    
    local count
    count=$(count_occurrences "$text" "$CANONICAL_COMMAND")
    if [ "$count" -ne 2 ]; then
        echo "FAIL: Expected 2 occurrences of CANONICAL_COMMAND, got $count"
        return 1
    fi
    
    echo "PASS: test_dispatcher_is_the_documented_first_action"
}

test_slash_command_bypasses_the_model() {
    local expected_list=(
        "command-dispatch: tool"
        "command-tool: tiktok_live_command"
        "command-arg-mode: raw"
    )
    
    for expected in "${expected_list[@]}"; do
        if ! text_contains "$text" "$expected"; then
            echo "FAIL: $expected not found in text"
            return 1
        fi
    done
    
    echo "PASS: test_slash_command_bypasses_the_model"
}

test_no_preliminary_playwright_or_dependency_probe() {
    local expected_list=(
        "Before this dispatcher call, do not invoke or inspect"
        "\`tiktok-check-profile.js\`"
        "Do not attempt to install or repair browser dependencies"
        "failed preliminary tool call"
    )
    
    for expected in "${expected_list[@]}"; do
        if ! text_contains "$normalized_text" "$expected"; then
            echo "FAIL: $expected not found in normalized text"
            return 1
        fi
    done
    
    echo "PASS: test_no_preliminary_playwright_or_dependency_probe"
}

test_direct_exec_without_shell_wrapper() {
    local expected_list=(
        "Invoke that executable directly as the exec command"
        "Do not invoke \`bash\`"
        "\`bash -lc\`"
        "wrapper must not be attempted in the first place"
    )
    
    for expected in "${expected_list[@]}"; do
        if ! text_contains "$normalized_text" "$expected"; then
            echo "FAIL: $expected not found in normalized text"
            return 1
        fi
    done
    
    echo "PASS: test_direct_exec_without_shell_wrapper"
}

test_success_json_wins_over_trailing_diagnostics() {
    local expected_list=(
        "display the final stdout JSON before trailing stderr diagnostics"
        "regardless of its visual position"
        "the tool execution succeeded"
        "Never replace such a result with a generic tool-failure message"
        "\`node_available\`"
    )
    
    for expected in "${expected_list[@]}"; do
        if ! text_contains "$normalized_text" "$expected"; then
            echo "FAIL: $expected not found in normalized text"
            return 1
        fi
    done
    
    echo "PASS: test_success_json_wins_over_trailing_diagnostics"
}

test_auto_host_and_bounded_node_fallback() {
    local expected_list=(
        "tools.exec.host=auto"
        "omit both the \`host\` and \`node\` fields"
        "retry exactly once"
        "least-loaded connected paired node"
        "host=node"
        "$NODE_COMMAND"
        "Never replace it with"
    )
    
    for expected in "${expected_list[@]}"; do
        if ! text_contains "$text" "$expected"; then
            echo "FAIL: $expected not found in text"
            return 1
        fi
    done
    
    if ! text_contains "$normalized_text" "technical_error, dependency_missing, or overloaded"; then
        echo "FAIL: technical_error, dependency_missing, or overloaded not found in normalized text"
        return 1
    fi
    
    if text_contains "$text" "host=gateway"; then
        echo "FAIL: host=gateway should not be present in text"
        return 1
    fi
    
    if ! text_contains "$text" "Never start a second node retry"; then
        echo "FAIL: Never start a second node retry not found in text"
        return 1
    fi
    
    if ! text_contains "$text" "never change the global exec host"; then
        echo "FAIL: never change the global exec host not found in text"
        return 1
    fi
    
    if ! text_contains "$text" "runtime block occurs before the Node allowlist"; then
        echo "FAIL: runtime block occurs before the Node allowlist not found in text"
        return 1
    fi
    
    local count
    count=$(count_occurrences "$text" "$CANONICAL_COMMAND")
    if [ "$count" -ne 2 ]; then
        echo "FAIL: Expected 2 occurrences of CANONICAL_COMMAND, got $count"
        return 1
    fi
    
    echo "PASS: test_auto_host_and_bounded_node_fallback"
}

test_public_contract_covers_legacy_and_rich_formats() {
    local legacy="@<handle> is currently <OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.
VLC/MPV: not available
Method: <validated method>"
    
    if ! text_contains "$text" "$legacy"; then
        echo "FAIL: Legacy format not found in text"
        return 1
    fi
    
    local live_format="@<handle> is currently LIVE on TikTok.
Titel: <room.title>"
    
    if ! text_contains "$text" "$live_format"; then
        echo "FAIL: Live format not found in text"
        return 1
    fi
    
    local expected_list=(
        "Stream-URLs:"
        "<label> (HLS):"
        "<label> (FLV):"
        "Live seit: <HH:MM UTC> (<Xh Ym>)"
        "exactly one URL and nothing else"
        "degrades to the legacy three lines including the \`VLC/MPV:\` URL"
        "No raw URL appears in plain text"
    )
    
    for expected in "${expected_list[@]}"; do
        if ! text_contains "$normalized_text" "$expected"; then
            echo "FAIL: $expected not found in normalized text"
            return 1
        fi
    done
    
    echo "PASS: test_public_contract_covers_legacy_and_rich_formats"
}

test_existing_capabilities_are_preserved() {
    local capabilities=(
        "Node" "browser" "file" "directory" "configuration"
        "dependency" "diagnostic tools remain available"
    )
    
    for capability in "${capabilities[@]}"; do
        if ! text_contains "$text" "$capability"; then
            echo "FAIL: $capability not found in text"
            return 1
        fi
    done
    
    echo "PASS: test_existing_capabilities_are_preserved"
}

test_no_response_flag_is_documented() {
    if text_contains "$text" "--response"; then
        echo "FAIL: --response flag should not be present in text"
        return 1
    fi
    
    echo "PASS: test_no_response_flag_is_documented"
}

test_atomic_output_and_synchronized_audio() {
    local expected_list=(
        "send it atomically"
        "Preserve every returned URL byte-for-byte"
        "channel voice output set to \`always\`"
        "Do not invoke the \`tts\` tool"
        "do not emit \`[[tts:text]]\` wrappers"
        "visible text remains the authoritative source"
    )
    
    for expected in "${expected_list[@]}"; do
        if ! text_contains "$normalized_text" "$expected"; then
            echo "FAIL: $expected not found in normalized text"
            return 1
        fi
    done
    
    echo "PASS: test_atomic_output_and_synchronized_audio"
}

# Run all tests
main() {
    local failed_tests=0
    local test_functions=(
        test_dispatcher_is_the_documented_first_action
        test_slash_command_bypasses_the_model
        test_no_preliminary_playwright_or_dependency_probe
        test_direct_exec_without_shell_wrapper
        test_success_json_wins_over_trailing_diagnostics
        test_auto_host_and_bounded_node_fallback
        test_public_contract_covers_legacy_and_rich_formats
        test_existing_capabilities_are_preserved
        test_no_response_flag_is_documented
        test_atomic_output_and_synchronized_audio
    )
    
    for test_func in "${test_functions[@]}"; do
        if ! "$test_func"; then
            ((failed_tests++))
        fi
    done
    
    if [ "$failed_tests" -eq 0 ]; then
        echo "All tests passed!"
        exit 0
    else
        echo "$failed_tests test(s) failed"
        exit 1
    fi
}

main "$@"
