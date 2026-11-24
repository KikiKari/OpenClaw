#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "483fadaf01058513585aa07f50dd41d5f29c03528e7cbebafba6b66508b4394c", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "shell"}
# test-extension.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Shell script to run extension tests similar to the JavaScript version.
# This script mimics the behavior of test-extension.mjs by resolving a test plan
# and running vitest with appropriate arguments.

# Function to print usage information
print_usage() {
    echo "Usage: $0 <extension-name|path> [vitest args...]" >&2
    echo "       bash $0 [extension-name|path] [vitest args...]" >&2
}

# Function to print message when no tests are found
print_no_tests_message() {
    local extension_dir="$1"
    echo "[test-extension] No tests found for $extension_dir. Skipping."
}

# Function to check if a string starts with a dash (i.e., an option)
starts_with_dash() {
    [[ "${1:-}" =~ ^-.* ]]
}

# Function to resolve extension test plan using Node.js
resolve_extension_test_plan() {
    local cwd="$1"
    local target_arg="$2"

    # Call the Node.js module that resolves the test plan and outputs JSON
    node --experimental-import-meta-resolve -e "
        import { resolveExtensionTestPlan } from './lib/extension-test-plan.mjs';
        const plan = resolveExtensionTestPlan({ cwd: '$cwd', targetArg: '$target_arg' });
        console.log(JSON.stringify(plan));
    "
}

# Function to run vitest batch using Node.js
run_vitest_batch() {
    local config_file="$1"
    local roots_json="$2"
    shift 2
    local vitest_args=("$@")

    # Run the vitest batch runner via Node.js
    node --experimental-import-meta-resolve -e "
        import { runVitestBatch } from './lib/vitest-batch-runner.mjs';

        const configPath = '$config_file';
        const roots = JSON.parse('$roots_json');
        const env = Object.fromEntries(Object.entries(process.env));

        runVitestBatch({
            args: process.argv.slice(1),
            config: configPath,
            env: env,
            targets: roots
        }).then(code => process.exit(code));
    " -- "${vitest_args[@]}"
}

# Main execution logic
main() {
    local raw_args=("$@")
    local passthrough_args=()
    local target_arg=""

    # Check for help flags
    for arg in "${raw_args[@]}"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            print_usage
            exit 0
        fi
    done

    # Filter out '--' separator if present
    for arg in "${raw_args[@]}"; do
        if [[ "$arg" != "--" ]]; then
            passthrough_args+=("$arg")
        fi
    done

    # Extract target argument if it's not an option
    if [[ ${#passthrough_args[@]} -gt 0 ]] && ! starts_with_dash "${passthrough_args[0]}"; then
        target_arg="${passthrough_args[0]}"
        # Remove first element from array
        passthrough_args=("${passthrough_args[@]:1}")
    fi

    # Resolve test plan using Node.js
    local plan_json
    plan_json=$(resolve_extension_test_plan "$(pwd)" "$target_arg") || {
        print_usage
        echo "Error resolving test plan." >&2
        exit 1
    }

    # Parse JSON fields using jq or basic parsing
    local has_tests
    has_tests=$(echo "$plan_json" | jq -r '.hasTests')

    if [[ "$has_tests" != "true" ]]; then
        local extension_dir
        extension_dir=$(echo "$plan_json" | jq -r '.extensionDir')
        print_no_tests_message "$extension_dir"
        return
    fi

    local test_file_count
    test_file_count=$(echo "$plan_json" | jq -r '.testFileCount')
    local extension_id
    extension_id=$(echo "$plan_json" | jq -r '.extensionId')
    local config_path
    config_path=$(echo "$plan_json" | jq -r '.config')
    local roots_json
    roots_json=$(echo "$plan_json" | jq -c '.roots')

    echo "[test-extension] Running $test_file_count test files for $extension_id"

    # Run vitest batch with resolved configuration
    run_vitest_batch "$config_path" "$roots_json" "${passthrough_args[@]}"
}

# Only execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
