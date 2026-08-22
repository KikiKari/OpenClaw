#!/usr/bin/env bash
# quick_validate.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Quick validation script for skills - minimal version

MAX_SKILL_NAME_LENGTH=64

# Function to extract frontmatter from SKILL.md
# Returns the frontmatter content between --- markers
extract_frontmatter() {
    local content="$1"
    local lines
    IFS=$'\n' read -rd '' -a lines <<<"$content" || true
    
    # Check if first line is ---
    if [[ ${#lines[@]} -eq 0 ]] || [[ "${lines[0]}" != "---" ]]; then
        echo ""
        return
    fi
    
    local i
    for ((i=1; i<${#lines[@]}; i++)); do
        if [[ "${lines[$i]}" == "---" ]]; then
            # Output lines between the --- markers
            local j
            for ((j=1; j<i; j++)); do
                echo "${lines[$j]}"
            done
            return
        fi
    done
    
    # No closing --- found
    echo ""
}

# Parse simple frontmatter without YAML library
# Supports basic key: value format
parse_simple_frontmatter() {
    local frontmatter_text="$1"
    declare -A parsed
    local current_key=""
    
    local line
    while IFS= read -r line; do
        local stripped="${line#"${line%%[![:space:]]*}"}"  # Trim leading whitespace
        stripped="${stripped%"${stripped##*[![:space:]]}"}"  # Trim trailing whitespace
        
        # Skip empty lines and comments
        if [[ -z "$stripped" ]] || [[ "$stripped" == "#"* ]]; then
            continue
        fi
        
        # Check if line is indented
        if [[ "${line:0:1}" =~ [[:space:]] ]]; then
            if [[ -z "$current_key" ]]; then
                echo "ERROR: Indentation without previous key"
                return 1
            fi
            local current_value="${parsed[$current_key]}"
            if [[ -n "$current_value" ]]; then
                parsed["$current_key"]="$current_value"$'\n'"$stripped"
            else
                parsed["$current_key"]="$stripped"
            fi
            continue
        fi
        
        # Check for key-value pair
        if [[ "$stripped" != *":"* ]]; then
            echo "ERROR: Invalid line format: $stripped"
            return 1
        fi
        
        local key="${stripped%%:*}"
        local value="${stripped#*:}"
        
        key="${key#"${key%%[![:space:]]*}"}"  # Trim leading whitespace
        key="${key%"${key##*[![:space:]]}"}"  # Trim trailing whitespace
        
        if [[ -z "$key" ]]; then
            echo "ERROR: Empty key"
            return 1
        fi
        
        value="${value#"${value%%[![:space:]]*}"}"  # Trim leading whitespace
        value="${value%"${value##*[![:space:]]}"}"  # Trim trailing whitespace
        
        # Remove quotes if present
        if [[ (${#value} -ge 2) && 
              (("${value:0:1}" == "\"" && "${value: -1}" == "\"") ||
               ("${value:0:1}" == "'" && "${value: -1}" == "'")) ]]; then
            value="${value:1:${#value}-2}"
        fi
        
        parsed["$key"]="$value"
        current_key="$key"
    done <<<"$frontmatter_text"
    
    # Export results
    for k in "${!parsed[@]}"; do
        printf "%s=%s\n" "$k" "${parsed[$k]}"
    done
}

validate_skill() {
    local skill_path="$1"
    local skill_md="$skill_path/SKILL.md"
    
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
    frontmatter_text=$(extract_frontmatter "$content")
    if [[ -z "$frontmatter_text" ]]; then
        echo "Invalid frontmatter format"
        return 1
    fi
    
    # Parse frontmatter using our simple parser
    local parsed_output
    if ! parsed_output=$(parse_simple_frontmatter "$frontmatter_text"); then
        echo "Invalid YAML in frontmatter: unsupported syntax without PyYAML installed"
        return 1
    fi
    
    # Convert parsed output to associative array
    declare -A frontmatter
    while IFS='=' read -r key value; do
        frontmatter["$key"]="$value"
    done <<<"$parsed_output"
    
    # Define allowed properties
    local allowed_properties=("name" "description" "license" "allowed-tools" "metadata")
    
    # Check for unexpected keys
    local unexpected_keys=()
    for key in "${!frontmatter[@]}"; do
        local found=false
        for prop in "${allowed_properties[@]}"; do
            if [[ "$key" == "$prop" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            unexpected_keys+=("$key")
        fi
    done
    
    if [[ ${#unexpected_keys[@]} -gt 0 ]]; then
        local allowed_str joined_unexpected
        printf -v joined_unexpected '%s, ' "${unexpected_keys[@]}"
        joined_unexpected=${joined_unexpected%, }
        local sorted_allowed
        IFS=$'\n' sorted_allowed=($(sort <<<"${allowed_properties[*]}"))
        local joined_allowed
        printf -v joined_allowed '%s, ' "${sorted_allowed[@]}"
        joined_allowed=${joined_allowed%, }
        echo "Unexpected key(s) in SKILL.md frontmatter: $joined_unexpected. Allowed properties are: $joined_allowed"
        return 1
    fi
    
    # Check required fields
    if [[ -z "${frontmatter[name]:-}" ]]; then
        echo "Missing 'name' in frontmatter"
        return 1
    fi
    
    if [[ -z "${frontmatter[description]:-}" ]]; then
        echo "Missing 'description' in frontmatter"
        return 1
    fi
    
    local name="${frontmatter[name]}"
    if [[ ! "$name" =~ ^[a-z0-9-]+$ ]]; then
        echo "Name '$name' should be hyphen-case (lowercase letters, digits, and hyphens only)"
        return 1
    fi
    
    if [[ "$name" == -* ]] || [[ "$name" == *- ]] || [[ "$name" == *--* ]]; then
        echo "Name '$name' cannot start/end with hyphen or contain consecutive hyphens"
        return 1
    fi
    
    if [[ ${#name} -gt $MAX_SKILL_NAME_LENGTH ]]; then
        echo "Name is too long (${#name} characters). Maximum is $MAX_SKILL_NAME_LENGTH characters."
        return 1
    fi
    
    local description="${frontmatter[description]}"
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
