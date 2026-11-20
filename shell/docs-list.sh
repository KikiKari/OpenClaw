#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "744141da957225cd8f247cc759f4f05512ca15e808d7b96b4a6f29233ad5debf", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "shell"}
# docs-list.js — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Check if docs directory exists and is a directory
DOCS_DIR="$(pwd)/docs"
if [[ ! -d "$DOCS_DIR" ]]; then
    echo "docs:list: missing docs directory. Run from repo root." >&2
    exit 1
fi

# Function to check if a directory should be excluded
is_excluded_dir() {
    local dir_name="$1"
    case "$dir_name" in
        archive|research)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Recursively find markdown files
walk_markdown_files() {
    local dir="$1"
    local base="${2:-$dir}"
    
    # Use find to get all entries, then process them
    while IFS= read -r -d '' entry; do
        local basename_entry="$(basename "$entry")"
        
        # Skip hidden files/directories
        if [[ "$basename_entry" == .* ]]; then
            continue
        fi
        
        if [[ -d "$entry" ]]; then
            # Skip excluded directories
            if is_excluded_dir "$basename_entry"; then
                continue
            fi
            # Recurse into subdirectories
            walk_markdown_files "$entry" "$base"
        elif [[ -f "$entry" && "$basename_entry" == *.md ]]; then
            # Print relative path from base
            realpath --relative-to="$base" "$entry"
        fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -print0 2>/dev/null | sort -z)
}

# Extract metadata from markdown file
extract_metadata() {
    local full_path="$1"
    
    # Read the entire file
    local content
    content=$(cat "$full_path")
    
    # Check for front matter
    if [[ ! "$content" =~ ^--- ]]; then
        echo "summary:null"
        echo "read_when:"
        echo "error:missing front matter"
        return
    fi
    
    # Find end of front matter
    local front_matter_end
    front_matter_end=$(echo "$content" | grep -n "^---" | tail -n +2 | head -n 1 | cut -d: -f1)
    
    if [[ -z "$front_matter_end" ]]; then
        echo "summary:null"
        echo "read_when:"
        echo "error:unterminated front matter"
        return
    fi
    
    # Extract front matter content
    local front_matter
    front_matter=$(echo "$content" | sed -n "2,$((front_matter_end - 1))p")
    
    # Initialize variables
    local summary=""
    local read_when_list=()
    local collecting_field=""
    
    # Process each line in front matter
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # trim whitespace
        
        if [[ "$line" =~ ^summary: ]]; then
            summary="$line"
            collecting_field=""
            continue
        fi
        
        if [[ "$line" =~ ^read_when: ]]; then
            collecting_field="read_when"
            local inline_value="${line#read_when:}"
            inline_value=$(echo "$inline_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Handle inline array format like ['hook', 'state']
            if [[ "$inline_value" =~ ^\[.*\]$ ]]; then
                # Convert single quotes to double quotes for proper parsing
                local json_array="${inline_value//\'/\"}"
                
                # Try to parse as JSON array
                if echo "$json_array" | jq -e . >/dev/null 2>&1; then
                    mapfile -t items < <(echo "$json_array" | jq -r '.[]' 2>/dev/null)
                    for item in "${items[@]}"; do
                        if [[ -n "$item" ]]; then
                            read_when_list+=("$item")
                        fi
                    done
                fi
            fi
            continue
        fi
        
        if [[ "$collecting_field" == "read_when" ]]; then
            if [[ "$line" =~ ^-[[:space:]]+(.+) ]]; then
                local hint="${BASH_REMATCH[1]}"
                if [[ -n "$hint" ]]; then
                    read_when_list+=("$hint")
                fi
            elif [[ -z "$line" ]]; then
                # Allow blank lines inside the list
                continue
            else
                collecting_field=""
            fi
        fi
    done <<< "$(echo "$front_matter")"
    
    # Validate summary
    if [[ -z "$summary" ]]; then
        echo "summary:null"
        echo "read_when:$(IFS=';'; echo "${read_when_list[*]}")"
        echo "error:summary key missing"
        return
    fi
    
    # Normalize summary value
    local summary_value="${summary#summary:}"
    summary_value=$(echo "$summary_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/^['\"]//;s/['\"]$//" | tr -s ' ')
    
    if [[ -z "$summary_value" ]]; then
        echo "summary:null"
        echo "read_when:$(IFS=';'; echo "${read_when_list[*]}")"
        echo "error:summary is empty"
        return
    fi
    
    echo "summary:$summary_value"
    echo "read_when:$(IFS=';'; echo "${read_when_list[*]}")"
    echo "error:"
}

# Main execution starts here
echo "Listing all markdown files in docs folder:"

# Collect markdown files
mapfile -t markdown_files < <(walk_markdown_files "$DOCS_DIR")

# Process each markdown file
for relative_path in "${markdown_files[@]}"; do
    full_path="$DOCS_DIR/$relative_path"
    
    # Call extract_metadata and capture output
    metadata_output=$(extract_metadata "$full_path")
    
    # Parse the output
    summary=$(echo "$metadata_output" | grep "^summary:" | cut -d: -f2-)
    read_when=$(echo "$metadata_output" | grep "^read_when:" | cut -d: -f2-)
    error=$(echo "$metadata_output" | grep "^error:" | cut -d: -f2-)
    
    if [[ "$summary" != "null" && -n "$summary" ]]; then
        echo "$relative_path - $summary"
        if [[ -n "$read_when" ]]; then
            echo "  Read when: $read_when"
        fi
    else
        local reason=""
        if [[ -n "$error" && "$error" != ":" ]]; then
            reason=" - [$error]"
        fi
        echo "$relative_path$reason"
    fi
done

echo ""
echo "Reminder: keep docs up to date as behavior changes. When your task matches any \"Read when\" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing."
