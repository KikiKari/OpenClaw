#!/usr/bin/env bash
# update_readme_stats.py — portiert nach shell
# Quelle: python, OpenClaw@main:scripts/update_readme_stats.py
# Erzeugt: 2026-08-24 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Fetch ClawHub stats and update README.md download counts and security status.

readonly API_BASE="https://clawhub.ai/api/v1"
readonly TOKEN="${CLAWHUB_TOKEN:-}"

# Define SKILLS array with name and slug pairs
declare -a SKILLS=(
    "Cluster Gateway:cluster-gateway"
    "MCP Tool Utils:mcp-tool-utils"
    "Reports Creator:reports-creator"
    "Relay Node:relay-node"
    "JSON Utils:json-utils"
    "Log Collector:log-collector"
    "TikTok Live Monitor:tiktok-live-monitor"
    "Doc Scraper:doc-scraper"
    "Workspace Database Manager:workspace-database-manager"
    "Scripting Utils:scripting-utils"
)

# Function to fetch skill data from API
fetch_skill() {
    local slug="$1"
    local url="${API_BASE}/skills/${slug}"
    local headers=("-H" "Accept: application/json" "-H" "User-Agent: bash-script")

    if [[ -n "${TOKEN}" ]]; then
        headers+=("-H" "Authorization: Bearer ${TOKEN}")
    fi

    curl -s --fail-with-body -m 10 "${headers[@]}" "${url}"
}

# Function to parse skill JSON response
parse_skill() {
    local json_data="$1"
    
    # Extract fields using jq
    local downloads version mod_is_malware_blocked mod_exists
    
    downloads=$(echo "${json_data}" | jq -r '.skill.stats.downloads // 0')
    version=$(echo "${json_data}" | jq -r '.latestVersion.version // "1.0.0"')
    mod_exists=$(echo "${json_data}" | jq -r 'if .moderation == null then "false" else "true" end')
    mod_is_malware_blocked=$(echo "${json_data}" | jq -r '.moderation.isMalwareBlocked // false')

    # Format version
    if [[ ! "${version}" =~ ^v ]]; then
        version="v${version}"
    fi

    # Determine security status
    local security="✅ Pass"
    if [[ "${mod_exists}" == "true" ]]; then
        if [[ "${mod_is_malware_blocked}" == "true" ]]; then
            security="🚫 Blocked"
        else
            security="🔍 Review"
        fi
    fi

    echo "${downloads}|${version}|${security}"
}

# Main function
main() {
    declare -A stats
    local errors=0
    local name slug pair

    # Fetch all skill data
    for pair in "${SKILLS[@]}"; do
        name="${pair%%:*}"
        slug="${pair##*:}"
        
        if data=$(fetch_skill "${slug}" 2>/dev/null); then
            if parsed=$(parse_skill "${data}" 2>/dev/null); then
                stats["${slug}"]="${parsed}"
                IFS='|' read -r dl ver sec <<<"${parsed}"
                echo "  OK  ${slug}: ${dl} downloads, ${ver}, ${sec}"
            else
                echo "  ERR ${slug}: Failed to parse data" >&2
                ((errors++))
            fi
        else
            echo "  ERR ${slug}: Failed to fetch data" >&2
            ((errors++))
        fi
    done

    # Check if we have any data
    if [[ ${#stats[@]} -eq 0 ]]; then
        echo "No data fetched — aborting." >&2
        exit 1
    fi

    # Read README.md
    local readme_content
    readme_content=$(cat "README.md")

    # Update download counts in README.md
    for pair in "${SKILLS[@]}"; do
        name="${pair%%:*}"
        slug="${pair##*:}"
        
        if [[ -n "${stats[${slug}]+isset}" ]]; then
            IFS='|' read -r dl _ _ <<<"${stats[${slug}]}"
            
            # Escape special regex characters in name
            local escaped_name
            escaped_name=$(printf '%s\n' "${name}" | sed 's/[]\/$*.^|()+{}[]/\\&/g')
            
            # Create pattern that matches the row with the skill name and replaces download count
            local pattern="|\\s*\\[\\?*${escaped_name}\\]\\?[^|]*|[^|]*|\\s*[0-9]*\\s*|"
            local replacement="| \\[${name}\\](${slug}) | ${dl} |"
            
            # Use perl for complex regex replacement (more powerful than sed)
            if command -v perl >/dev/null 2>&1; then
                readme_content=$(echo "${readme_content}" | perl -pe "s/\\|\\s*\\[?\\Q${name}\\E\\]?(?:(?!\\|).)*\\|(?:(?!\\|).)*\\|\\s*\\d+\\s*\\|/| [${name}](${slug}) | ${dl} |/gi")
                echo "  Updated: ${name} -> ${dl}"
            fi
        fi
    done

    # Write updated content back to README.md
    echo "${readme_content}" > "README.md"
    echo "Done: ${#stats[@]} skills, ${errors} errors."
}

# Run main function
main "$@"
