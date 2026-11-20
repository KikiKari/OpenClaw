#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "c3d6e2a6087c2e61499d53de04a751bd560a6e01ca6b72298bec5419dceb72db", "source_sha256": "f6c7bd2581ab63fdb19f7caaff8e9c362e279303a47e4efe1873b2e652a7fbc8", "target_language": "shell"}
# generate-host-env-security-policy-swift.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/generate-host-env-security-policy-swift.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 [--check | --write]" >&2
    exit 1
}

# Parse arguments
check_only=false
write_mode=false

for arg in "$@"; do
    case "$arg" in
        --check)
            check_only=true
            ;;
        --write)
            write_mode=true
            ;;
        *)
            usage
            ;;
    esac
done

if [ "$check_only" = true ] && [ "$write_mode" = true ]; then
    echo "Use either --check or --write, not both." >&2
    exit 1
fi

if [ "$check_only" = false ] && [ "$write_mode" = false ]; then
    write_mode=true
fi

# Determine paths
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
policy_path="$repo_root/src/infra/host-env-security-policy.json"
output_path="$repo_root/apps/macos/Sources/OpenClaw/HostEnvSecurityPolicy.generated.swift"

# Read and parse JSON using jq
if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required but not installed. Please install jq." >&2
    exit 1
fi

# Helper function to extract array from JSON and format as Swift string literals
render_swift_string_array() {
    local key="$1"
    jq -r --arg key "$key" '
        if (.[$key] | type == "array") then
            .[$key][] | "        \"\(.)\""
        else
            ""
        end
    ' "$policy_path" | sed '/^$/d' | paste -sd ",\n" -
}

# Extract each field with fallback for optional fields
blocked_inherited_keys=$(render_swift_string_array "blockedInheritedKeys")
blocked_inherited_prefixes=$(render_swift_string_array "blockedInheritedPrefixes")
blocked_keys=$(render_swift_string_array "blockedKeys")
blocked_override_keys=$(jq -r '
    if (.blockedOverrideKeys and (.blockedOverrideKeys | type == "array")) then
        .blockedOverrideKeys[] | "        \"\(.)\""
    else
        ""
    end
' "$policy_path" | sed '/^$/d' | paste -sd ",\n" -)
blocked_override_prefixes=$(jq -r '
    if (.blockedOverridePrefixes and (.blockedOverridePrefixes | type == "array")) then
        .blockedOverridePrefixes[] | "        \"\(.)\""
    else
        ""
    end
' "$policy_path" | sed '/^$/d' | paste -sd ",\n" -)
blocked_prefixes=$(render_swift_string_array "blockedPrefixes")

# Generate the Swift code
generated="// Generated file. Do not edit directly.
// Source: src/infra/host-env-security-policy.json
// Regenerate: bash scripts/generate-host-env-security-policy-swift.sh --write

import Foundation

enum HostEnvSecurityPolicy {
    static let blockedInheritedKeys: Set<String> = [
$(echo "$blocked_inherited_keys" | sed 's/^/        "/; s/$/"/')
    ]

    static let blockedInheritedPrefixes: [String] = [
$(echo "$blocked_inherited_prefixes" | sed 's/^/        "/; s/$/"/')
    ]

    static let blockedKeys: Set<String> = [
$(echo "$blocked_keys" | sed 's/^/        "/; s/$/"/')
    ]

    static let blockedOverrideKeys: Set<String> = [
$(echo "$blocked_override_keys" | sed 's/^/        "/; s/$/"/')
    ]

    static let blockedOverridePrefixes: [String] = [
$(echo "$blocked_override_prefixes" | sed 's/^/        "/; s/$/"/')
    ]

    static let blockedPrefixes: [String] = [
$(echo "$blocked_prefixes" | sed 's/^/        "/; s/$/"/')
    ]
}"

# Handle check mode
if [ "$check_only" = true ]; then
    if [ -f "$output_path" ]; then
        current=$(cat "$output_path")
    else
        current=""
    fi

    if [ "$current" = "$generated" ]; then
        rel_path="${output_path#$repo_root/}"
        echo "OK $rel_path"
        exit 0
    else
        rel_path="${output_path#$repo_root/}"
        echo "Out of date $rel_path."
        echo "Run: bash scripts/generate-host-env-security-policy-swift.sh --write"
        exit 1
    fi
fi

# Handle write mode
if [ "$write_mode" = true ]; then
    mkdir -p "$(dirname "$output_path")"
    if [ -f "$output_path" ]; then
        current=$(cat "$output_path")
    else
        current=""
    fi

    if [ "$current" != "$generated" ]; then
        echo "$generated" > "$output_path"
    fi
    rel_path="${output_path#$repo_root/}"
    echo "Wrote $rel_path"
fi
