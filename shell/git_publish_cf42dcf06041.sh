#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "bd4e6079af21bc3226b0d13b3f90a69e981d3b9d61192d0884a4d375e925a207", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "shell"}
# git_publish.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Git Publish Agent - Automatisierte Skill-Veröffentlichung

readonly SKILLS_DIR="${HOME}/.openclaw/workspace/skills"

# Commit skill changes.
git_commit() {
    local skill_path="$1"
    local message="${2:-}"

    if [[ -z "$message" ]]; then
        message="[skill] Auto-update $(basename "$skill_path") - $(date --iso-8601=seconds)"
    fi

    git add "$skill_path" && git commit -m "$message"
}

# Publish to ClawHub.
clawhub_publish() {
    local skill_name="$1"
    local skill_path="${SKILLS_DIR}/${skill_name}"

    clawhub publish "$skill_path" \
        --slug "$skill_name" \
        --version "1.0.0"
}

# Publish all changed skills with rate limiting.
batch_publish() {
    local changed_skills=()
    local skill
    local i

    # Check git status
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ "$line" == *"skills/"* ]]; then
            skill=$(echo "$line" | sed -n 's/.*skills\/\([^/]*\).*/\1/p')
            if [[ ! " ${changed_skills[*]} " =~ " ${skill} " ]]; then
                changed_skills+=("$skill")
            fi
        fi
    done < <(git status --short "$SKILLS_DIR")

    echo "Changed skills: ${changed_skills[*]}"

    # Publish with delay
    for i in "${!changed_skills[@]}"; do
        if (( i > 0 && i < 5 )); then
            echo "Waiting 15min for rate limit..."
            # In real: sleep 900
        fi

        if (( i >= 5 )); then
            break
        fi

        skill="${changed_skills[i]}"
        echo "Publishing ${skill}..."

        if git_commit "${SKILLS_DIR}/${skill}"; then
            if clawhub_publish "$skill"; then
                echo "  ✓ Published successfully"
            else
                echo "  ✗ Failed to publish"
            fi
        else
            echo "  ✗ Failed to commit"
        fi
    done
}

main() {
    local skill=""
    local publish_all=false
    local no_publish=false
    local message=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skill)
                skill="$2"
                shift 2
                ;;
            --all)
                publish_all=true
                shift
                ;;
            --no-publish)
                no_publish=true
                shift
                ;;
            --message)
                message="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    if [[ -n "$skill" ]]; then
        local skill_path="${SKILLS_DIR}/${skill}"
        if $no_publish; then
            git_commit "$skill_path" "$message"
        else
            git_commit "$skill_path" "$message"
            clawhub_publish "$skill"
        fi
    elif $publish_all; then
        batch_publish
    else
        echo "Use --skill <name> or --all"
    fi
}

main "$@"
