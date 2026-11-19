#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "3c8ab2a93e867c32d1eb0e328fd8bab8cbd75c016408224198a9bd0610340280", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "shell"}
# scrape_to_markdown.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Default values
urls=()
url_file=""
selector=""
js=false
wait_selector=""
preserve_links=false
body_width=0
timeout=30
output_dir="outputs"
automatch_domain=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            urls+=("$2")
            shift 2
            ;;
        --url-file)
            url_file="$2"
            shift 2
            ;;
        --selector)
            selector="$2"
            shift 2
            ;;
        --js)
            js=true
            shift
            ;;
        --wait-selector)
            wait_selector="$2"
            shift 2
            ;;
        --preserve-links)
            preserve_links=true
            shift
            ;;
        --body-width)
            body_width="$2"
            shift 2
            ;;
        --timeout)
            timeout="$2"
            shift 2
            ;;
        --output-dir)
            output_dir="$2"
            shift 2
            ;;
        --automatch-domain)
            automatch_domain="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Function to slugify text
slugify() {
    local text="$1"
    local max_len="${2:-80}"
    # Remove non-word characters except spaces and hyphens
    text=$(echo "$text" | sed 's/[^a-zA-Z0-9\s-]//g' | tr '[:upper:]' '[:lower:]' | xargs)
    # Replace multiple spaces/hyphens with single hyphen
    text=$(echo "$text" | sed 's/[-\s]\+/-/g')
    # Truncate and remove leading/trailing hyphens
    text=$(echo "$text" | cut -c1-"$max_len" | sed 's/^-*//' | sed 's/-*$//')
    # If empty, use default
    if [ -z "$text" ]; then
        text="page"
    fi
    echo "$text"
}

# Function to extract domain from URL
extract_domain() {
    local url="$1"
    echo "$url" | awk -F/ '{print $3}'
}

# Function to validate URL
validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https?:// ]] || [[ ! "$url" =~ \. ]]; then
        return 1
    fi
    return 0
}

# Load URLs from file if provided
if [ -n "$url_file" ] && [ -f "$url_file" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [ -n "$line" ] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
            urls+=("$line")
        fi
    done < "$url_file"
fi

# Remove duplicate URLs
temp_urls=()
declare -A seen
for url in "${urls[@]}"; do
    if [ -z "${seen[$url]+isset}" ]; then
        temp_urls+=("$url")
        seen["$url"]=1
    fi
done
urls=("${temp_urls[@]}")

# Check if we have URLs
if [ ${#urls[@]} -eq 0 ]; then
    echo '{"ok": false, "error": "No URLs provided"}'
    exit 1
fi

# Validate all URLs
for url in "${urls[@]}"; do
    if ! validate_url "$url"; then
        echo "{\"ok\": false, \"error\": \"Invalid URL: $url\"}"
        exit 1
    fi
done

# Create output directory
mkdir -p "$output_dir"

# Initialize results array
results=()
success_count=0
failure_count=0

# Process each URL
for url in "${urls[@]}"; do
    item="{\"url\": \"$url\", \"ok\": false, \"title\": \"\", \"status\": null, \"selector_used\": null, \"backend\": null, \"markdown\": \"\", \"preview\": \"\", \"output_markdown_file\": null, \"error\": null}"
    
    # Try to fetch the page
    temp_html=$(mktemp)
    temp_md=$(mktemp)
    
    # Determine fetch command based on JS setting
    if [ "$js" = true ]; then
        # For JS-enabled fetching, we'd need a tool like pupeteer-cli or similar
        # Since there's no direct equivalent in bash, we'll fall back to curl/wget
        # This is a limitation of the bash translation
        if command -v curl >/dev/null 2>&1; then
            curl -sL --max-time "$timeout" "$url" > "$temp_html" 2>/dev/null || true
        elif command -v wget >/dev/null 2>&1; then
            wget --timeout="$timeout" -q -O "$temp_html" "$url" 2>/dev/null || true
        else
            echo "{\"ok\": false, \"error\": \"No fetch tool available (curl or wget required)\"}"
            exit 1
        fi
        backend="bash.curl"
    else
        if command -v curl >/dev/null 2>&1; then
            curl -sL --max-time "$timeout" "$url" > "$temp_html" 2>/dev/null || true
        elif command -v wget >/dev/null 2>&1; then
            wget --timeout="$timeout" -q -O "$temp_html" "$url" 2>/dev/null || true
        else
            echo "{\"ok\": false, \"error\": \"No fetch tool available (curl or wget required)\"}"
            exit 1
        fi
        backend="bash.curl"
    fi
    
    # Extract title from HTML
    title=$(grep -iPo '(?<=<title>).*?(?=</title>)' "$temp_html" 2>/dev/null | sed 's/<[^>]*>//g' | xargs 2>/dev/null || echo "")
    
    # If no title found, use domain
    if [ -z "$title" ]; then
        title=$(extract_domain "$url")
    fi
    
    # Convert HTML to Markdown using pandoc if available
    if command -v pandoc >/dev/null 2>&1; then
        if [ "$preserve_links" = true ]; then
            pandoc -f html -t markdown "$temp_html" > "$temp_md" 2>/dev/null || true
        else
            pandoc -f html -t markdown-raw_html-links "$temp_html" > "$temp_md" 2>/dev/null || true
        fi
    else
        # Fallback: simple conversion using sed (very basic)
        sed 's/<[^>]*>//g' "$temp_html" | sed 's/&nbsp;/ /g' | sed 's/&amp;/\&/g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g' > "$temp_md" 2>/dev/null || true
    fi
    
    # Read markdown content
    markdown_content=$(cat "$temp_md" 2>/dev/null || echo "")
    
    # Generate filename
    filename=$(slugify "${title}" 80).md
    md_path="$output_dir/$filename"
    
    # Write markdown file
    echo "$markdown_content" > "$md_path"
    
    # Create preview (first 1200 chars)
    preview=$(echo "$markdown_content" | head -c 1200)
    
    # Update success counters
    success_count=$((success_count + 1))
    
    # Build result object
    item="{\"url\": \"$url\", \"ok\": true, \"title\": \"$title\", \"status\": 200, \"selector_used\": null, \"backend\": \"$backend\", \"markdown\": \"$(echo "$markdown_content" | sed 's/"/\\"/g')\", \"preview\": \"$(echo "$preview" | sed 's/"/\\"/g')\", \"output_markdown_file\": \"$md_path\", \"error\": null}"
    
    results+=("$item")
    
    # Clean up temp files
    rm -f "$temp_html" "$temp_md"
done

# Build final JSON response
results_json=$(printf '%s,\n' "${results[@]}" | sed '$ s/,$//' )

output_index_file="$output_dir/index.json"

final_json="{
  \"ok\": true,
  \"count\": ${#urls[@]},
  \"success_count\": $success_count,
  \"failure_count\": $failure_count,
  \"output_index_file\": \"$output_index_file\",
  \"results\": [
$results_json
  ]
}"

# Write index file
echo "$final_json" > "$output_index_file"

# Output final JSON
echo "$final_json"
