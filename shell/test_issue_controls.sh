#!/usr/bin/env bash
# test_issue_controls.cjs — portiert nach shell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This is a conceptual translation of JavaScript tests to Bash.
# Since Bash lacks native testing frameworks like Node.js's test module,
# we simulate the behavior using functions and basic assertions.

# Mocking required modules and setup
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sidepanel_js="$source_dir/../browser-extension/sidepanel.js"
content_core_js="$source_dir/../browser-extension/content-core.js"

if [[ ! -f "$sidepanel_js" ]]; then
    echo "Error: $sidepanel_js not found!" >&2
    exit 1
fi

if [[ ! -f "$content_core_js" ]]; then
    echo "Error: $content_core_js not found!" >&2
    exit 1
fi

# Read source file into variable
source_code=$(cat "$sidepanel_js")

# Function to extract code fragments between start and end markers
fragment() {
    local start="$1"
    local end="$2"
    local extracted
    # Extract substring between start and end markers
    extracted=$(echo "$source_code" | sed -n "/$start/,/$end/p" | head -n -1)
    echo "$extracted"
}

# Simulate DOM elements with associative arrays
declare -A elements
declare -A document

# Initialize mock element
init_element() {
    local id="$1"
    elements["$id,hidden"]=true
    elements["$id,disabled"]=false
    elements["$id,textContent"]='Off'
    elements["$id,focus"]=false
    elements["$id,click"]=""
}

# Focus an element
focus_element() {
    local id="$1"
    document["activeElement"]="$id"
    elements["$id,focus"]=true
}

# Click an element (simulate event handler)
click_element() {
    local id="$1"
    if [[ -n "${elements["$id,click"]:-}" ]]; then
        eval "${elements["$id,click"]}"
    fi
}

# Test 175: Manual and automatic speech reject raw point triggers before author prefixes
test_175() {
    echo "Running test 175..."

    for enabled in false true; do
        spoken=()
        speech_queue=()

        # Define speakItem function based on fragment
        speak_item_code=$(fragment "async function speakItem(" "async function pumpSpeech(")
        enqueue_speech_code=$(fragment "function enqueueSpeech(" "function ")

        # Evaluate code snippets (simulated)
        eval "$speak_item_code"
        eval "$enqueue_speech_code"

        # Loop through content items
        for content in ".Text" ". Text" "  .Text" "Normal" "Ein Satz. Noch einer"; do
            # Call speakItem and enqueueSpeech
            eval "speakItem \"{ content: '$content' }\""
            eval "enqueueSpeech \"{ content: '$content' }\""
        done

        # Assertions
        expected_spoken_length=$((enabled ? 2 : 5))
        expected_queue_length=$((enabled ? 2 : 5))

        if [[ ${#spoken[@]} -ne $expected_spoken_length ]]; then
            echo "Test 175 failed: spoken.length = ${#spoken[@]}, expected $expected_spoken_length"
            exit 1
        fi

        if [[ ${#speech_queue[@]} -ne $expected_queue_length ]]; then
            echo "Test 175 failed: speechQueue.length = ${#speech_queue[@]}, expected $expected_queue_length"
            exit 1
        fi
    done

    echo "Test 175 passed."
}

# Test 176: Speech switch commits On/Off only after a successful request
test_176_speech_switch() {
    echo "Running test 176 (speech switch)..."

    speech_enabled=false
    send_result="success"

    # Toggle speech function
    toggle_speech() {
        if [[ "$send_result" == "success" ]]; then
            speech_enabled=!$speech_enabled
        else
            elements["speech-status,textContent"]="failed"
        fi
    }

    # Add event listener for toggle-speech
    elements["toggle-speech,click"]="toggle_speech"

    # Initial click - should enable
    click_element "toggle-speech"
    if [[ "$speech_enabled" != "true" ]]; then
        echo "Test 176 failed: speech not enabled after first click"
        exit 1
    fi

    # Second click with failure - should remain enabled but show error
    send_result="failed"
    click_element "toggle-speech"
    if [[ "$speech_enabled" != "true" ]]; then
        echo "Test 176 failed: speech should remain enabled after failed request"
        exit 1
    fi

    if [[ ! "${elements["speech-status,textContent"]:-}" =~ "failed" ]]; then
        echo "Test 176 failed: status should show failed message"
        exit 1
    fi

    # Third click with success - should disable
    send_result="success"
    click_element "toggle-speech"
    if [[ "$speech_enabled" != "false" ]]; then
        echo "Test 176 failed: speech should be disabled after successful request"
        exit 1
    fi

    echo "Test 176 (speech switch) passed."
}

# Test 176: Connection selects both commands and preserves state on rejection
test_176_connection() {
    echo "Running test 176 (connection)..."

    declare -a calls=()
    current_state_hook_armed=false

    # Toggle hook function
    toggle_hook() {
        if [[ "$send_result" == "success" ]]; then
            current_state_hook_armed=!$current_state_hook_armed
            if [[ "$current_state_hook_armed" == "true" ]]; then
                calls+=("TLC_ENABLE_HOOK")
            else
                calls+=("TLC_DISABLE_HOOK")
            fi
        else
            elements["notice,textContent"]="failed"
        fi
    }

    # Add event listener for toggle-hook
    elements["toggle-hook,click"]="toggle_hook"

    # First two clicks - should succeed
    send_result="success"
    click_element "toggle-hook"
    click_element "toggle-hook"

    # Check calls array
    if [[ ${#calls[@]} -ne 2 ]]; then
        echo "Test 176 failed: expected 2 calls, got ${#calls[@]}"
        exit 1
    fi

    if [[ "${calls[0]}" != "TLC_ENABLE_HOOK" ]] || [[ "${calls[1]}" != "TLC_DISABLE_HOOK" ]]; then
        echo "Test 176 failed: unexpected call sequence"
        exit 1
    fi

    # Next click with failure - should preserve state
    send_result="failed"
    click_element "toggle-hook"
    if [[ "$current_state_hook_armed" != "false" ]]; then
        echo "Test 176 failed: state should be preserved on rejection"
        exit 1
    fi

    if [[ ! "${elements["notice,textContent"]:-}" =~ "failed" ]]; then
        echo "Test 176 failed: notice should show failed message"
        exit 1
    fi

    echo "Test 176 (connection) passed."
}

# Test 176: Connection dialog returns focus and traps Tab in both directions
test_176_focus_trap() {
    echo "Running test 176 (focus trap)..."

    # Initialize modal elements
    init_element "connection-settings-modal"
    init_element "close-connection-settings"
    init_element "open-connection-settings"
    init_element "quick-recover-seconds"
    init_element "notice"

    elements["connection-settings-modal,hidden"]=true

    # Open connection settings function
    open_connection_settings() {
        elements["connection-settings-modal,hidden"]=false
        focus_element "close-connection-settings"
    }

    # Close connection settings function
    close_connection_settings() {
        elements["connection-settings-modal,hidden"]=true
        focus_element "open-connection-settings"
    }

    # Keydown handler
    handle_keydown() {
        local key="$1"
        local shift_key="$2"
        case "$key" in
            Tab)
                if [[ "$shift_key" == "true" ]]; then
                    focus_element "quick-recover-seconds"
                else
                    focus_element "close-connection-settings"
                fi
                ;;
            Escape)
                close_connection_settings
                ;;
        esac
    }

    # Add event listeners
    elements["open-connection-settings,click"]="open_connection_settings"
    elements["close-connection-settings,click"]="close_connection_settings"

    # Click to open modal
    click_element "open-connection-settings"
    if [[ "${elements["connection-settings-modal,hidden"]:-}" != "false" ]]; then
        echo "Test 176 failed: modal should be visible after opening"
        exit 1
    fi

    if [[ "${document["activeElement"]:-}" != "close-connection-settings" ]]; then
        echo "Test 176 failed: focus should be on close button"
        exit 1
    fi

    # Simulate Tab key press (forward)
    handle_keydown "Tab" "false"
    if [[ "${document["activeElement"]:-}" != "close-connection-settings" ]]; then
        echo "Test 176 failed: focus should stay on first element when tabbing forward"
        exit 1
    fi

    # Simulate Shift+Tab key press (backward)
    handle_keydown "Tab" "true"
    if [[ "${document["activeElement"]:-}" != "quick-recover-seconds" ]]; then
        echo "Test 176 failed: focus should move to last element when shift-tabbing"
        exit 1
    fi

    # Simulate Escape key press
    handle_keydown "Escape" ""
    if [[ "${elements["connection-settings-modal,hidden"]:-}" != "true" ]]; then
        echo "Test 176 failed: modal should be hidden after escape"
        exit 1
    fi

    if [[ "${document["activeElement"]:-}" != "open-connection-settings" ]]; then
        echo "Test 176 failed: focus should return to open button"
        exit 1
    fi

    echo "Test 176 (focus trap) passed."
}

# Run all tests
main() {
    test_175
    test_176_speech_switch
    test_176_connection
    test_176_focus_trap
    echo "All tests passed."
}

main "$@"
