#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "1a4db4ca13edf24ff664773d8e2c8b431458be664a822f754c090406acbfb82c", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "shell"}
# generated-output-utils.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Import necessary functions from other modules
source "${BASH_SOURCE[0]%/*}/../runtime-postbuild-shared.bash"
source "${BASH_SOURCE[0]%/*}/bundled-plugin-source-utils.bash"

writeGeneratedOutput() {
    local repoRoot="$1"
    local outputPath="$2"
    local next="$3"
    local check="${4:-false}"
    
    local fullOutputPath
    fullOutputPath=$(realpath "${repoRoot}/${outputPath}" 2>/dev/null || echo "${repoRoot}/${outputPath}")
    
    local current=""
    if [[ -f "$fullOutputPath" ]]; then
        current=$(readIfExists "$fullOutputPath")
    fi
    
    local changed=false
    if [[ "$current" != "$next" ]]; then
        changed=true
    fi
    
    if [[ "$check" == true ]]; then
        echo "{\"changed\":$([[ "$changed" == true ]] && echo "true" || echo "false"),\"wrote\":false,\"outputPath\":\"$fullOutputPath\"}"
        return
    fi
    
    local wrote=false
    if writeTextFileIfChanged "$fullOutputPath" "$next"; then
        wrote=true
    fi
    
    echo "{\"changed\":$([[ "$changed" == true ]] && echo "true" || echo "false"),\"wrote\":$([[ "$wrote" == true ]] && echo "true" || echo "false"),\"outputPath\":\"$fullOutputPath\"}"
}

reportGeneratedOutputCli() {
    local label="$1"
    local scriptPath="$2"
    
    # Check if this script is being run directly
    if [[ "$(realpath "${BASH_SOURCE[0]}")" != "$(realpath "$scriptPath")" ]]; then
        return
    fi
    
    local check=false
    for arg in "$@"; do
        if [[ "$arg" == "--check" ]]; then
            check=true
            break
        fi
    done
    
    local result
    result=$(writeGeneratedOutput "$3" "$4" "$5" "$check")
    
    # Parse JSON result (simplified)
    local changed=false
    if [[ "$result" == *"\"changed\":true"* ]]; then
        changed=true
    fi
    
    if [[ "$changed" != true ]]; then
        return
    fi
    
    # Extract output path from result (simplified parsing)
    local outputPath
    outputPath=$(echo "$result" | sed -n 's/.*"outputPath":"\([^"]*\)".*/\1/p')
    
    local relativeOutputPath
    relativeOutputPath=$(realpath --relative-to="$(pwd)" "$outputPath")
    
    if [[ "$check" == true ]]; then
        echo "[$label] stale generated output at $relativeOutputPath" >&2
        exit 1
    fi
    
    echo "[$label] wrote $relativeOutputPath"
}
