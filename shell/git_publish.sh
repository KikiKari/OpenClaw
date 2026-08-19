#!/usr/bin/env bash
# git_publish.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

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

    git add "$skill_path"
    git commit -m "$message"
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
            skill=$(echo "$line" | sed -n 's/.*skills\/\([^\/]*\).*/\1/p')
            if [[ ! " ${changed_skills[*]} " =~ " $skill " ]]; then
                changed_skills+=("$skill")
            fi
        fi
    done < <(git status --short "$SKILLS_DIR")

    echo "Changed skills: ${changed_skills[*]}"

    # Publish with delay (max 5 per batch)
    for i in "${!changed_skills[@]}"; do
        if [[ $i -ge 5 ]]; then
            break
        fi
        
        if [[ $i -gt 0 ]]; then
            echo "Waiting 15min for rate limit..."
            # In real: sleep 900
        fi

        skill="${changed_skills[$i]}"
        echo "Publishing $skill..."
        
        if git_commit "${SKILLS_DIR}/${skill}"; then
            if clawhub_publish "$skill"; then
                echo "  ✓ Published successfully"
            else
                echo "  ✗ Publish failed"
            fi
        else
            echo "  ✗ Git commit failed"
        fi
    done
}

main() {
    local skill=""
    local all=false
    local no_publish=false
    local message=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skill)
                skill="$2"
                shift 2
                ;;
            --all)
                all=true
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
                echo "Unknown option: $1"
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
    elif $all; then
        batch_publish
    else
        echo "Use --skill <name> or --all"
        exit 1
    fi
}

# Change to parent directory of SKILLS_DIR for git operations
cd "$(dirname "$SKILLS_DIR")"

main "$@"
