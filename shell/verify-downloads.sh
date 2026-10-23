#!/usr/bin/env bash
# verify-downloads.py — portiert nach shell
# Quelle: python, Projects@TikTok-Live-Companion:site/scripts/verify-downloads.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/scripts/verify-downloads.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Verify the candidate's actual HTTP downloads against committed files.

usage() {
    echo "Usage: $0 --base-url BASE_URL --report REPORT_FILE" >&2
    exit 1
}

base_url=""
report=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-url)
            base_url="$2"
            shift 2
            ;;
        --report)
            report="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$base_url" ]] || [[ -z "$report" ]]; then
    usage
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(dirname "$script_dir")
checksum_file="$repo_root/public/downloads/tiktok-live-companion-0.8.2-SHA256.txt"
downloads_dir="$repo_root/public/downloads"
results=()

# Read each line from the checksum file
while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    
    expected=$(echo "$line" | cut -d' ' -f1)
    name=$(echo "$line" | cut -d' ' -f3)
    
    url="${base_url%/}/downloads/$name"
    
    # Download file and get its content
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT
    
    if ! curl -s -L --max-time 30 -o "$temp_file" "$url"; then
        echo "Failed to download: $name" >&2
        exit 1
    fi
    
    # Calculate SHA256 hash
    actual=$(sha256sum "$temp_file" | cut -d' ' -f1)
    
    # Compare with expected hash
    if [[ "$actual" != "$expected" ]]; then
        echo "HTTP artifact mismatch: $name" >&2
        exit 1
    fi
    
    # Compare with local file
    if ! cmp -s "$temp_file" "$downloads_dir/$name"; then
        echo "HTTP artifact mismatch: $name" >&2
        exit 1
    fi
    
    # Check ZIP integrity
    if ! unzip -tqq "$temp_file" >/dev/null 2>&1; then
        echo "Corrupt archive: $name" >&2
        exit 1
    fi
    
    # Special checks for extension files
    if [[ "$name" == *"-extension-"* ]]; then
        manifest_version=$(unzip -p "$temp_file" manifest.json | jq -r '.version')
        if [[ "$manifest_version" != "0.8.2" ]]; then
            echo "Wrong extension version" >&2
            exit 1
        fi
        
        # Check source files
        for source in background.js content.js sidepanel.js sidepanel.html; do
            extension_source_file="$repo_root/../plugin-source/browser-extension/$source"
            if ! unzip -p "$temp_file" "$source" | cmp -s - "$extension_source_file"; then
                echo "Extension source mismatch: $source" >&2
                exit 1
            fi
        done
    fi
    
    # Get file size
    bytes=$(stat -c%s "$temp_file")
    
    # Add result
    results+=("{\"name\": \"$name\", \"sha256\": \"$actual\", \"bytes\": $bytes, \"verified\": true}")
    
    rm -f "$temp_file"
done < "$checksum_file"

# Create JSON output
results_json=$(printf '%s,\n' "${results[@]}" | sed '$ s/,$//' )
json_output="{\"base_url\": \"$base_url\", \"artifacts\": [$results_json]}"
echo "$json_output" | jq . > "$report"

# Print results
echo "["
printf '%s,\n' "${results[@]}" | sed '$ s/,$//'
echo "]" | jq .
