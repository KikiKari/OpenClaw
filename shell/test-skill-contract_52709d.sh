#!/usr/bin/env bash
# test-skill-contract.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/test-skill-contract.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Regression checks for /tiktok_live_mon routing and monitor actions.

set -euo pipefail

# Define paths and constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SCRIPT_DIR/../SKILL.md"
DISPATCHER="/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @name --quality auto --json"
CONTROLLER="/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh"

# Read the skill file content
text=$(cat "$SKILL")
normalized_text=$(echo "$text" | tr -s ' \t\n\r' ' ')

# Function to assert substring inclusion
assert_in_text() {
    local expected="$1"
    local context="$2"
    if [[ "$context" != *"$expected"* ]]; then
        echo "FAIL: Expected '$expected' not found in text."
        exit 1
    fi
}

assert_normalized_in_text() {
    local expected="$1"
    local context="$2"
    if [[ "$context" != *"$expected"* ]]; then
        echo "FAIL: Expected normalized '$expected' not found in text."
        exit 1
    fi
}

# Test cases as functions
test_bare_handle_uses_dispatcher_as_first_tool_call() {
    assert_in_text "dispatcher exec must be the first tool call" "$normalized_text"
    assert_in_text "$DISPATCHER" "$text"
    assert_in_text "A bare handle never starts a daemon" "$text"
}

test_slash_command_bypasses_the_model() {
    local expected_list=(
        "command-dispatch: tool"
        "command-tool: tiktok_live_mon_command"
        "command-arg-mode: raw"
    )
    for expected in "${expected_list[@]}"; do
        assert_in_text "$expected" "$text"
    done
}

test_no_preliminary_playwright_or_dependency_probe() {
    local expected_list=(
        "Before this dispatcher call, do not invoke or inspect"
        "\`tiktok-check-profile.js\`"
        "Do not attempt to install or repair browser dependencies"
        "failed preliminary tool call"
    )
    for expected in "${expected_list[@]}"; do
        assert_normalized_in_text "$expected" "$normalized_text"
    done
}

test_direct_exec_without_shell_wrapper() {
    local expected_list=(
        "Invoke that executable directly as the exec command"
        "Do not invoke \`bash\`"
        "\`bash -lc\`"
        "wrapper must not be attempted in the first place"
    )
    for expected in "${expected_list[@]}"; do
        assert_normalized_in_text "$expected" "$normalized_text"
    done
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
        assert_normalized_in_text "$expected" "$normalized_text"
    done
}

test_running_dispatcher_is_polled_without_restart() {
    local expected_list=(
        "Start exactly one dispatcher exec per request"
        "do not rerun exec"
        'sessionId: "NAME"'
        "Continue polling that same name until completion"
    )
    for expected in "${expected_list[@]}"; do
        assert_in_text "$expected" "$text"
    done
}

test_monitor_actions_remain_controller_backed() {
    local actions=("start" "status" "stop")
    for action in "${actions[@]}"; do
        assert_in_text "$CONTROLLER $action @name" "$text"
    done
    assert_in_text "prevents duplicate active monitors" "$text"
    assert_in_text "Without the current word \`start\`" "$text"
}

test_one_shot_response_contract_covers_all_statuses() {
    local legacy="@<handle> is currently <OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.
VLC/MPV: not available
Method: <method>"
    assert_in_text "$legacy" "$text"
    assert_in_text "@<handle> is currently LIVE on TikTok.
Titel: <room.title>" "$text"

    local expected_list=(
        "Stream-URLs:"
        "<label> (HLS):"
        "<label> (FLV):"
        "exactly one URL and nothing else"
        "No raw URL appears in plain text"
    )
    local flat_text
    flat_text=$(echo "$text" | tr -d '\n')
    for expected in "${expected_list[@]}"; do
        assert_normalized_in_text "$expected" "$flat_text"
    done

    local statuses=("live" "offline" "restricted" "overloaded" "dependency_missing" "technical_error")
    for status in "${statuses[@]}"; do
        assert_in_text "$status" "$text"
    done
}

test_invalid_current_input_is_not_taken_from_history() {
    assert_in_text "Derive the action, handle, hours, and poll interval only" "$text"
    assert_in_text "Never take them from" "$text"
}

# Run all tests
run_tests() {
    test_bare_handle_uses_dispatcher_as_first_tool_call
    test_slash_command_bypasses_the_model
    test_no_preliminary_playwright_or_dependency_probe
    test_direct_exec_without_shell_wrapper
    test_success_json_wins_over_trailing_diagnostics
    test_running_dispatcher_is_polled_without_restart
    test_monitor_actions_remain_controller_backed
    test_one_shot_response_contract_covers_all_statuses
    test_invalid_current_input_is_not_taken_from_history
    echo "All tests passed."
}

run_tests
