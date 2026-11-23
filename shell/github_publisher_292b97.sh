#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "7a977a5dc2cb6f4c68c7fb5732e5729a71ea000b5e260dbb2fc04f4a65a47bd3", "source_sha256": "292b977dd14f55e08a3852eccaf235d04d5f7e909ab6139a9ab2e379ae2305a1", "target_language": "shell"}
# github_publisher.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Publish queued, provenance-checked artifacts without staging unrelated files.

LANGUAGES=(perl5 powershell perl6 tcl javascript ruby python lua shell go)

# Reconcile a remote snapshot into the checkout without changing its Git history.
# Arguments:
#   $1: Root directory
#   $2: Remote URL (optional, default=https://github.com/KikiKari/OpenClaw.git)
#   $3: Branch name (optional, default=gateway1-abstractions)
# Returns:
#   Revision and file counts via global variables
synchronize_checkout() {
    local root="$1"
    local remote="${2:-https://github.com/KikiKari/OpenClaw.git}"
    local branch="${3:-gateway1-abstractions}"
    
    # Create temporary directory for snapshot
    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/abstractions-snapshot-XXXXXX")
    local snapshot="$tmp/repo"
    
    # Cleanup function
    cleanup() {
        rm -rf "$tmp"
    }
    trap cleanup EXIT
    
    # Clone repository
    git clone --quiet --depth=1 --single-branch --branch "$branch" -- "$remote" "$snapshot"
    
    # Get revision
    local revision
    revision=$(git -C "$snapshot" rev-parse HEAD)
    
    # Process each language
    declare -gA counts=()
    local language
    for language in "${LANGUAGES[@]}"; do
        local source="$snapshot/$language"
        local target="$root/$language"
        
        # Check for symlinks
        if [[ -L "$source" ]] || [[ -L "$target" ]]; then
            echo "Error: language directory is a symlink" >&2
            return 1
        fi
        
        # Validate source directory
        if [[ -e "$source" ]] && [[ ! -d "$source" ]]; then
            echo "Error: invalid remote language directory" >&2
            return 1
        fi
        
        # Create target directory
        mkdir -p "$target"
        
        # Build set of known hashes
        local known_files=()
        local known_hashes=()
        local i=0
        while IFS= read -r -d '' file; do
            if [[ ! -L "$file" ]] && [[ -f "$file" ]]; then
                known_files+=("$file")
                known_hashes+=("$(sha256sum < "$file" | cut -d' ' -f1)")
            fi
            ((i++))
        done < <(find "$target" -maxdepth 1 -type f -print0 2>/dev/null || true)
        
        # Get list of files to process
        local files=()
        if [[ -d "$source" ]]; then
            while IFS= read -r -d '' file; do
                if [[ -L "$file" ]] || [[ ! -f "$file" ]]; then
                    echo "Error: invalid remote abstraction" >&2
                    return 1
                fi
                files+=("$file")
            done < <(find "$source" -maxdepth 1 -type f -print0 2>/dev/null || true)
        fi
        
        # Set count
        counts["$language"]="${#files[@]}"
        
        # Process files
        local file
        for file in "${files[@]}"; do
            local data
            data=$(cat "$file")
            local digest
            digest=$(echo -n "$data" | sha256sum | cut -d' ' -f1)
            
            # Check if already known
            local known=false
            for known_hash in "${known_hashes[@]}"; do
                if [[ "$known_hash" == "$digest" ]]; then
                    known=true
                    break
                fi
            done
            
            if [[ "$known" == false ]]; then
                local filename
                filename=$(basename "$file")
                local destination="$target/$filename"
                
                # Handle conflicts
                if [[ -e "$destination" ]] || [[ -L "$destination" ]]; then
                    local stem="${filename%.*}"
                    local suffix="${filename#$stem}"
                    if [[ "$suffix" == "$filename" ]]; then
                        suffix=""
                    fi
                    destination="$target/${stem}__pool_${digest}${suffix}"
                fi
                
                # Write file
                if [[ -e "$destination" ]]; then
                    if [[ -L "$destination" ]] || [[ ! -f "$destination" ]] || [[ "$(cat "$destination")" != "$data" ]]; then
                        echo "Error: local abstraction conflict" >&2
                        return 1
                    fi
                else
                    echo -n "$data" > "$destination"
                fi
                
                known_hashes+=("$digest")
            fi
        done
    done
    
    # Return revision
    echo "$revision"
}

# Update status counts in STATUS.md
# Arguments:
#   $1: Path to STATUS.md
#   $2: Revision hash
update_status_counts() {
    local path="$1"
    local revision="$2"
    
    # Read file content
    local text
    text=$(cat "$path")
    
    # Build replacement rows
    local rows=$'## Bestand\n\n'
    rows+="GitHub-Stand: \`$revision\`\n\n"
    rows+="| Zielsprache | Dateien |\n|---|---:|\n"
    
    local language
    local total=0
    for language in "${LANGUAGES[@]}"; do
        local count=${counts["$language"]}
        rows+="| $language | $count |\n"
        total=$((total + count))
    done
    rows+="| **gesamt** | **$total** |\n\n"
    
    # Replace section using sed
    local temp_file
    temp_file=$(mktemp)
    echo "$text" | sed '/^## Bestand$/,/^## Quellen$/{
        /^## Bestand$/!{
            /^## Quellen$/!d
        }
        /^## Bestand$/c\
'"$rows"'## Quellen
    }' > "$temp_file"
    
    # Move temp file to original location
    mv "$temp_file" "$path"
}

# Queue an artifact for publishing
# Arguments:
#   $1: State file path
#   $2: Root directory
#   $3: Artifact path
queue_artifact() {
    local state_file="$1"
    local root="$2"
    local path="$3"
    
    # Resolve paths
    root=$(realpath "$root")
    path=$(realpath "$path")
    
    # Check if artifact is a symlink
    if [[ -L "$path" ]]; then
        echo "Error: artifact must not be a symlink" >&2
        return 1
    fi
    
    # Get relative path
    local relative
    relative=$(realpath --relative-to="$root" "$path" 2>/dev/null) || {
        echo "Error: unable to determine relative path" >&2
        return 1
    }
    
    # Validate path
    if [[ "$relative" != "STATUS.md" ]]; then
        if [[ "$relative" != */* ]] || [[ ! " ${LANGUAGES[*]} " =~ " ${relative%%/*} " ]]; then
            echo "Error: artifact is outside a language directory" >&2
            return 1
        fi
    fi
    
    # Calculate hash
    local hash
    hash=$(sha256sum < "$path" | cut -d' ' -f1)
    
    # Update state file
    if [[ -f "$state_file" ]]; then
        # Use jq if available, otherwise fall back to sed
        if command -v jq >/dev/null 2>&1; then
            jq --arg rel "$relative" --arg hash "$hash" \
                '.ausstehende_veroeffentlichungen[$rel] = $hash' "$state_file" > "$state_file.tmp" && 
                mv "$state_file.tmp" "$state_file"
        else
            # Simple approach for adding entry without jq
            local temp_state
            temp_state=$(mktemp)
            if grep -q '"ausstehende_veroeffentlichungen"' "$state_file" 2>/dev/null; then
                # Add to existing object
                sed '/"ausstehende_veroeffentlichungen"/,/}/ {
                    /}/i \    "'"$relative"'": "'"$hash"'",
                }' "$state_file" > "$temp_state"
            else
                # Create new object
                sed '/^{/a \  "ausstehende_veroeffentlichungen": {\
    "'"$relative"'": "'"$hash"'"\
  }' "$state_file" > "$temp_state"
            fi
            mv "$temp_state" "$state_file"
        fi
    else
        # Create new state file
        echo '{"ausstehende_veroeffentlichungen":{"'"$relative"'":"'"$hash"'"}}' > "$state_file"
    fi
}

# Publish pending artifacts
# Arguments:
#   $1: Root directory
#   $2: State file path
#   $3: GitHub token
publish_pending() {
    local root="$1"
    local state_file="$2"
    local token="$3"
    
    # Check if state file exists
    if [[ ! -f "$state_file" ]]; then
        echo "State file does not exist: $state_file" >&2
        return 1
    fi
    
    # Check token
    if [[ -z "${token// }" ]]; then
        return 1
    fi
    
    # Resolve root
    root=$(realpath "$root")
    
    # Headers for API requests
    local headers=(
        "Authorization: Bearer $token"
        "Accept: application/vnd.github+json"
        "X-GitHub-Api-Version: 2022-11-28"
        "User-Agent: abstractions-manager"
    )
    
    # Get pending publications from state file
    local pending_entries=()
    if command -v jq >/dev/null 2>&1; then
        mapfile -t pending_entries < <(jq -r 'if .ausstehende_veroeffentlichungen|type=="object" 
            then .ausstehende_veroeffentlichungen|to_entries[]|"\(.key):\(.value)"
            else empty end' "$state_file" 2>/dev/null || true)
    else
        # Fallback parsing without jq
        if grep -q '"ausstehende_veroeffentlichungen"' "$state_file" 2>/dev/null; then
            # Extract entries manually
            local key_val_lines
            key_val_lines=$(sed -n '/"ausstehende_veroeffentlichungen"/,/^  }/p' "$state_file" | 
                           grep -E '^  "[^"]+": "[a-f0-9]+"' | 
                           sed 's/^  "\([^"]\+\)": "\([a-f0-9]\+\)".*/\1:\2/')
            mapfile -t pending_entries <<< "$key_val_lines"
        fi
    fi
    
    # Sort entries putting STATUS.md last
    local sorted_entries=()
    local status_entry=""
    local entry
    for entry in "${pending_entries[@]}"; do
        if [[ "${entry%%:*}" == "STATUS.md" ]]; then
            status_entry="$entry"
        else
            sorted_entries+=("$entry")
        fi
    done
    if [[ -n "$status_entry" ]]; then
        sorted_entries+=("$status_entry")
    fi
    
    local success=true
    local synced=false
    
    # Process each pending entry
    for entry in "${sorted_entries[@]}"; do
        local name="${entry%%:*}"
        local expected="${entry#*:}"
        
        # Validate path
        local path="$root/$name"
        if [[ -L "$path" ]]; then
            echo "Error: invalid queued path" >&2
            success=false
            continue
        fi
        
        # Verify hash
        local actual_hash
        actual_hash=$(sha256sum < "$path" | cut -d' ' -f1)
        if [[ "$actual_hash" != "$expected" ]]; then
            echo "Error: queued artifact changed" >&2
            success=false
            continue
        fi
        
        # Special handling for STATUS.md
        if [[ "$name" == "STATUS.md" ]]; then
            if [[ "$success" != true ]]; then
                echo "Error: artifact publication incomplete" >&2
                success=false
                continue
            fi
            
            # Synchronize checkout
            local revision
            revision=$(synchronize_checkout "$root")
            synced=true
            
            # Update status counts
            update_status_counts "$path" "$revision"
            
            # Recalculate hash after update
            expected=$(sha256sum < "$path" | cut -d' ' -f1)
            
            # Update state
            if command -v jq >/dev/null 2>&1; then
                jq --arg hash "$expected" '.ausstehende_veroeffentlichungen["STATUS.md"] = $hash' "$state_file" > "$state_file.tmp" &&
                mv "$state_file.tmp" "$state_file"
            fi
        fi
        
        # Function to lookup remote file
        lookup() {
            local remote_name="$1"
            local endpoint="https://api.github.com/repos/KikiKari/OpenClaw/contents/$(printf '%s' "$remote_name" | sed 's/ /%20/g')"
            
            # Try to get existing file
            local response
            response=$(curl -s -H "${headers[0]}" -H "${headers[1]}" -H "${headers[2]}" -H "${headers[3]}" \
                "$endpoint?ref=gateway1-abstractions" 2>/dev/null || echo "{}")
            
            # Check if it's a valid JSON response with content
            if echo "$response" | grep -q '"content"'; then
                echo "$endpoint|$response"
            else
                echo "$endpoint|"
            fi
        }
        
        # Function to compare content
        same() {
            local existing="$1"
            local data="$2"
            
            # Extract content and encoding
            local encoding
            local content
            encoding=$(echo "$existing" | grep -o '"encoding":"[^"]*"' | cut -d'"' -f4)
            content=$(echo "$existing" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
            
            if [[ "$encoding" == "base64" ]]; then
                local decoded_content
                decoded_content=$(echo "$content" | base64 -d)
                if [[ "$decoded_content" == "$data" ]]; then
                    return 0
                fi
            fi
            return 1
        }
        
        # Get file data
        local data
        data=$(cat "$path")
        
        # Lookup remote file
        local lookup_result
        lookup_result=$(lookup "$name")
        local endpoint="${lookup_result%%|*}"
        local existing="${lookup_result#*|}"
        
        # Handle STATUS.md update case
        if [[ "$name" == "STATUS.md" ]] && [[ -n "$existing" ]] && ! same "$existing" "$data"; then
            # Extract SHA
            local sha
            sha=$(echo "$existing" | grep -o '"sha":"[^"]*"' | cut -d'"' -f4)
            if [[ -z "$sha" ]]; then
                echo "Error: missing remote status version" >&2
                success=false
                continue
            fi
            
            # Prepare update payload
            local content_b64
            content_b64=$(echo -n "$data" | base64 -w0)
            local body
            body="{\"message\":\"Update abstraction status\",\"branch\":\"gateway1-abstractions\",\"content\":\"$content_b64\",\"sha\":\"$sha\"}"
            
            # Update file
            curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -H "${headers[2]}" -H "${headers[3]}" \
                -d "$body" "$endpoint" >/dev/null 2>&1 || {
                echo "Error updating STATUS.md" >&2
                success=false
                continue
            }
        elif [[ -n "$existing" ]] && ! same "$existing" "$data"; then
            # Handle conflicts by creating alternate filename
            local candidate="$name"
            local basename
            basename=$(basename "$candidate")
            local dirname
            dirname=$(dirname "$candidate")
            local stem="${basename%.*}"
            local suffix="${basename#$stem}"
            if [[ "$suffix" == "$basename" ]]; then
                suffix=""
            fi
            local alternate="$dirname/${stem}_${expected:0:12}$suffix"
            
            # Check alternate file
            lookup_result=$(lookup "$alternate")
            existing="${lookup_result#*|}"
            
            if [[ -n "$existing" ]] && ! same "$existing" "$data"; then
                echo "Error: remote artifact conflict" >&2
                success=false
                continue
            fi
            
            endpoint="${lookup_result%%|*}"
        fi
        
        # Upload new file if needed
        if [[ -z "$existing" ]]; then
            local content_b64
            content_b64=$(echo -n "$data" | base64 -w0)
            local message="Publish script abstraction"
            if [[ "$name" == "STATUS.md" ]]; then
                message="Update abstraction status"
            fi
            local body
            body="{\"message\":\"$message\",\"branch\":\"gateway1-abstractions\",\"content\":\"$content_b64\"}"
            
            curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -H "${headers[2]}" -H "${headers[3]}" \
                -d "$body" "$endpoint" >/dev/null 2>&1 || {
                echo "Error uploading file: $name" >&2
                success=false
                continue
            }
        fi
        
        # Remove from pending list
        if command -v jq >/dev/null 2>&1; then
            jq --arg name "$name" 'del(.ausstehende_veroeffentlichungen[$name])' "$state_file" > "$state_file.tmp" &&
            mv "$state_file.tmp" "$state_file"
        else
            # Manual removal fallback
            sed "/\"$name\":/d" "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
        fi
    done
    
    # Sync if needed
    if [[ "${sync:-}" == "true" ]] && [[ "$synced" != true ]]; then
        synchronize_checkout "$root" >/dev/null 2>&1 || success=false
    fi
    
    # Return success status
    if [[ "$success" == true ]]; then
        return 0
    else
        return 1
    fi
}
