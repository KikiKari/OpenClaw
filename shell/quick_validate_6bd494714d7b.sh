#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "620446eb2b0571c47d74c9ea32c7fbf35a49ac1d59e2041f0ad50f139f900ce7", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "shell"}
# quick_validate.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Quick validation script for skills - minimal version

MAX_SKILL_NAME_LENGTH=64

# Function to extract frontmatter from SKILL.md
# Returns the frontmatter content between --- markers
_extract_frontmatter() {
    local content="$1"
    local first_line
    first_line=$(echo "$content" | head -n1 | xargs)
    if [[ "$first_line" != "---" ]]; then
        echo ""
        return
    fi
    
    # Read line by line until we find closing ---
    local line_num=2
    while IFS= read -r line; do
        local trimmed
        trimmed=$(echo "$line" | xargs)
        if [[ "$trimmed" == "---" ]]; then
            # Return everything between the --- markers
            echo "$content" | sed -n "2,$((line_num-1))p"
            return
        fi
        ((line_num++))
    done <<< "$(echo "$content" | tail -n +2)"
    
    echo ""
}

# Simple YAML parser for basic key-value pairs when yq/yaml tools aren't available
_parse_simple_frontmatter() {
    local frontmatter_text="$1"
    local result=""
    local current_key=""
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        local trimmed
        trimmed=$(echo "$line" | xargs)
        if [[ -z "$trimmed" ]] || [[ "${trimmed:0:1}" == "#" ]]; then
            continue
        fi
        
        # Check if line is indented (continuation of previous value)
        if [[ "${line:0:1}" =~ [[:space:]] ]]; then
            if [[ -z "$current_key" ]]; then
                echo ""
                return
            fi
            # Append to existing key's value
            local old_value
            old_value=$(echo "$result" | grep "^${current_key}:" | cut -d':' -f2- | xargs)
            local new_value="${old_value}"$'\n'"$(echo "$trimmed" | xargs)"
            result=$(echo "$result" | sed "s|^${current_key}:.*|${current_key}: ${new_value}|")
            continue
        fi
        
        # Regular key-value line
        if [[ "$trimmed" != *":"* ]]; then
            echo ""
            return
        fi
        
        local key
        local value
        key=$(echo "$trimmed" | cut -d':' -f1 | xargs)
        value=$(echo "$trimmed" | cut -d':' -f2- | xargs)
        
        if [[ -z "$key" ]]; then
            echo ""
            return
        fi
        
        # Remove quotes if present
        if [[ "${value:0:1}" == "'" ]] && [[ "${value: -1}" == "'" ]]; then
            value="${value:1:-1}"
        elif [[ "${value:0:1}" == "\"" ]] && [[ "${value: -1}" == "\"" ]]; then
            value="${value:1:-1}"
        fi
        
        result+="${key}: ${value}"$'\n'
        current_key="$key"
    done <<< "$(echo "$frontmatter_text")"
    
    echo "$result"
}

validate_skill() {
    local skill_path="$1"
    local skill_md="${skill_path}/SKILL.md"
    
    if [[ ! -f "$skill_md" ]]; then
        echo "SKILL.md not found"
        return 1
    fi
    
    local content
    if ! content=$(cat "$skill_md"); then
        echo "Could not read SKILL.md: $(errno)"
        return 1
    fi
    
    local frontmatter_text
    frontmatter_text=$(_extract_frontmatter "$content")
    if [[ -z "$frontmatter_text" ]]; then
        echo "Invalid frontmatter format"
        return 1
    fi
    
    local frontmatter
    frontmatter=$(_parse_simple_frontmatter "$frontmatter_text")
    if [[ -z "$frontmatter" ]]; then
        echo "Invalid YAML in frontmatter: unsupported syntax without PyYAML installed"
        return 1
    fi
    
    # Check for unexpected keys
    local allowed_properties=("name" "description" "license" "allowed-tools" "metadata")
    local unexpected_keys=()
    
    while IFS= read -r line; do
        local key
        key=$(echo "$line" | cut -d':' -f1)
        local found=false
        for prop in "${allowed_properties[@]}"; do
            if [[ "$key" == "$prop" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == false ]] && [[ -n "$key" ]]; then
            unexpected_keys+=("$key")
        fi
    done <<< "$(echo "$frontmatter")"
    
    if [[ ${#unexpected_keys[@]} -gt 0 ]]; then
        local allowed_str
        local unexpected_str
        printf -v allowed_str '%s, ' "${allowed_properties[@]}"
        allowed_str=${allowed_str%, }
        printf -v unexpected_str '%s, ' "${unexpected_keys[@]}"
        unexpected_str=${unexpected_str%, }
        echo "Unexpected key(s) in SKILL.md frontmatter: ${unexpected_str}. Allowed properties are: ${allowed_str}"
        return 1
    fi
    
    # Check required fields
    if ! echo "$frontmatter" | grep -q "^name:"; then
        echo "Missing 'name' in frontmatter"
        return 1
    fi
    
    if ! echo "$frontmatter" | grep -q "^description:"; then
        echo "Missing 'description' in frontmatter"
        return 1
    fi
    
    # Validate name
    local name
    name=$(echo "$frontmatter" | grep "^name:" | cut -d':' -f2- | xargs)
    
    if [[ ! "$name" =~ ^[a-z0-9-]+$ ]]; then
        echo "Name '$name' should be hyphen-case (lowercase letters, digits, and hyphens only)"
        return 1
    fi
    
    if [[ "$name" == -* ]] || [[ "$name" == *- ]] || [[ "$name" == *--* ]]; then
        echo "Name '$name' cannot start/end with hyphen or contain consecutive hyphens"
        return 1
    fi
    
    if [[ ${#name} -gt $MAX_SKILL_NAME_LENGTH ]]; then
        echo "Name is too long (${#name} characters). Maximum is ${MAX_SKILL_NAME_LENGTH} characters."
        return 1
    fi
    
    # Validate description
    local description
    description=$(echo "$frontmatter" | grep "^description:" | cut -d':' -f2- | xargs)
    
    if [[ "$description" == *"<"* ]] || [[ "$description" == *">"* ]]; then
        echo "Description cannot contain angle brackets (< or >)"
        return 1
    fi
    
    if [[ ${#description} -gt 1024 ]]; then
        echo "Description is too long (${#description} characters). Maximum is 1024 characters."
        return 1
    fi
    
    echo "Skill is valid!"
    return 0
}

# Main execution
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <skill_directory>"
    exit 1
fi

if validate_skill "$1"; then
    exit 0
else
    exit 1
fi
