#!/usr/bin/env bash
# sync_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

readonly CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
readonly GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"
readonly STATE_FILE="/home/openclaw/.openclaw/workspace/db/sync_state.json"
readonly BACKUP_ROOT="/home/openclaw/.openclaw/workspace/backups/sync_agent"
readonly SCRIPTS_DIR="/home/openclaw/.openclaw/workspace/scripts"

# Lade externe Funktionen
source "${SCRIPTS_DIR}/sync_clawhub_git.sh"

# Globale Variablen für Ergebnisstatistiken
declare -a synced_to_git=()
declare -a synced_to_clawhub=()
declare -a updated_git=()
declare -a updated_clawhub=()
declare -a no_change=()
declare -a errors=()

load_state() {
    # Lädt den Sync-State
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"sync_history":[],"pending":[]}'
    fi
}

save_state() {
    local state="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$state" > "$STATE_FILE"
}

get_all_skills() {
    # Findet nur valide Skill-Verzeichnisse in beiden Verzeichnissen
    local skills=()
    
    # Sammle Skills aus ClawHub
    while IFS= read -r dir; do
        local skill_name
        skill_name=$(basename "$dir")
        if [[ ! "$skill_name" =~ ^[._] ]] && [[ -f "$dir/SKILL.md" ]]; then
            skills+=("$skill_name")
        fi
    done < <(find "$CLAWHUB_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    # Sammle Skills aus Git
    while IFS= read -r dir; do
        local skill_name
        skill_name=$(basename "$dir")
        if [[ ! "$skill_name" =~ ^[._] ]] && [[ -f "$dir/SKILL.md" ]] && [[ ! " ${skills[@]} " =~ " $skill_name " ]]; then
            skills+=("$skill_name")
        fi
    done < <(find "$GIT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    printf '%s\n' "${skills[@]}" | sort -u
}

init_git_repo() {
    local skill_path="$1"
    local skill_name="$2"
    
    if [[ ! -d "$skill_path/.git" ]]; then
        (
            cd "$skill_path" || exit 1
            git init >/dev/null 2>&1
            git add . >/dev/null 2>&1
            git commit -m "Initial commit: $skill_name skill" >/dev/null 2>&1
        )
        log "Git initialized for $skill_name"
    fi
}

backup_skill_dir() {
    local skill_path="$1"
    local skill_name="$2"
    
    if [[ ! -d "$skill_path" ]]; then
        return
    fi
    
    local timestamp
    timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_dir="${BACKUP_ROOT}/${timestamp}"
    mkdir -p "$backup_dir"
    
    local archive_name="${skill_name}_${timestamp}.tar.gz"
    local archive_path="${backup_dir}/${archive_name}"
    
    tar -czf "$archive_path" -C "$skill_path" . >/dev/null 2>&1
    log "Backup created for $skill_name at $archive_path"
}

get_hashes() {
    local skill_dir="$1"
    local hash_file
    hash_file=$(mktemp)
    
    find "$skill_dir" -type f ! -path "*/.git/*" -exec md5sum {} \; | \
        sed "s|${skill_dir}/||" | sort > "$hash_file"
    
    echo "$hash_file"
}

sync_skill_bidirectional() {
    local skill_name="$1"
    local dry_run="${2:-false}"
    local clawhub_path="${CLAWHUB_DIR}/${skill_name}"
    local git_path="${GIT_DIR}/${skill_name}"
    
    # Fall 1: Nur in ClawHub → zu Git
    if [[ -d "$clawhub_path" ]] && [[ ! -d "$git_path" ]]; then
        log "NEW in ClawHub: $skill_name → syncing to Git"
        if [[ "$dry_run" != "true" ]]; then
            backup_skill_dir "$clawhub_path" "${skill_name}_clawhub"
        fi
        if sync_to_git "$skill_name" "$dry_run"; then
            if [[ "$dry_run" != "true" ]]; then
                init_git_repo "$git_path" "$skill_name"
            fi
            echo "synced_to_git"
            return
        fi
        
    # Fall 2: Nur in Git → zu ClawHub
    elif [[ -d "$git_path" ]] && [[ ! -d "$clawhub_path" ]]; then
        log "NEW in Git: $skill_name → syncing to ClawHub"
        if [[ "$dry_run" != "true" ]]; then
            backup_skill_dir "$git_path" "${skill_name}_git"
        fi
        if sync_to_clawhub "$skill_name" "$dry_run"; then
            echo "synced_to_clawhub"
            return
        fi
        
    # Fall 3: In beiden vorhanden → Vergleiche Hashes
    elif [[ -d "$clawhub_path" ]] && [[ -d "$git_path" ]]; then
        # Validiere beide Skills
        if ! validate_skill "$clawhub_path"; then
            log "Validation failed for ClawHub skill: $skill_name" "ERROR"
            echo "error"
            return
        fi
        if ! validate_skill "$git_path"; then
            log "Validation failed for Git skill: $skill_name" "ERROR"
            echo "error"
            return
        fi
        
        # Berechne Hashes
        local clawhub_hash_file git_hash_file
        clawhub_hash_file=$(get_hashes "$clawhub_path")
        git_hash_file=$(get_hashes "$git_path")
        
        if ! cmp -s "$clawhub_hash_file" "$git_hash_file"; then
            log "Content difference detected for: $skill_name"
            
            local direction
            if [[ $(stat -c %Y "$clawhub_path") -ge $(stat -c %Y "$git_path") ]]; then
                direction="to-git"
            else
                direction="to-clawhub"
            fi
            
            log "UPDATE: $skill_name → syncing $direction"
            if [[ "$dry_run" != "true" ]]; then
                backup_skill_dir "$clawhub_path" "${skill_name}_clawhub"
                backup_skill_dir "$git_path" "${skill_name}_git"
            fi
            
            local sync_result=false
            if [[ "$direction" == "to-git" ]]; then
                if sync_to_git "$skill_name" "$dry_run"; then
                    sync_result=true
                    if [[ "$dry_run" != "true" ]]; then
                        (
                            cd "$git_path" || exit 1
                            git add . >/dev/null 2>&1
                            git commit -m "Sync from ClawHub content diff: $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1
                        )
                    fi
                fi
            else
                if sync_to_clawhub "$skill_name" "$dry_run"; then
                    sync_result=true
                fi
            fi
            
            rm -f "$clawhub_hash_file" "$git_hash_file"
            
            if [[ "$sync_result" == "true" ]]; then
                echo "${direction/_/-}"
            else
                log "Failed to sync $skill_name to Git after content diff" "ERROR"
                echo "error"
            fi
            return
        else
            rm -f "$clawhub_hash_file" "$git_hash_file"
            log "Content is identical for: $skill_name"
            echo "no_change"
            return
        fi
    fi
    
    echo "no_change"
}

main() {
    local dry_run="false"
    
    # Parse Argumente
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                echo "Unbekannte Option: $1"
                exit 1
                ;;
        esac
    done
    
    log "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    local state
    state=$(load_state)
    local all_skills
    mapfile -t all_skills < <(get_all_skills)
    log "Gefundene Skills: ${#all_skills[@]}"
    
    declare -A results_count=(
        ["synced_to_git"]=0
        ["synced_to_clawhub"]=0
        ["updated_git"]=0
        ["updated_clawhub"]=0
        ["no_change"]=0
        ["errors"]=0
    )
    
    for skill in "${all_skills[@]}"; do
        local result
        result=$(sync_skill_bidirectional "$skill" "$dry_run")
        
        case "$result" in
            synced_to_git)
                synced_to_git+=("$skill")
                ((results_count["synced_to_git"]++))
                ;;
            synced_to_clawhub)
                synced_to_clawhub+=("$skill")
                ((results_count["synced_to_clawhub"]++))
                ;;
            updated_git)
                updated_git+=("$skill")
                ((results_count["updated_git"]++))
                ;;
            updated_clawhub)
                updated_clawhub+=("$skill")
                ((results_count["updated_clawhub"]++))
                ;;
            no_change)
                no_change+=("$skill")
                ((results_count["no_change"]++))
                ;;
            error)
                errors+=("$skill")
                ((results_count["errors"]++))
                ;;
        esac
    done
    
    # Zusammenfassung
    log ""
    log "=== SYNC ZUSAMMENFASSUNG ==="
    log "Neu in Git: ${results_count["synced_to_git"]} - ${synced_to_git[*]:-}"
    log "Neu in ClawHub: ${results_count["synced_to_clawhub"]} - ${synced_to_clawhub[*]:-}"
    log "Git aktualisiert: ${results_count["updated_git"]} - ${updated_git[*]:-}"
    log "ClawHub aktualisiert: ${results_count["updated_clawhub"]} - ${updated_clawhub[*]:-}"
    log "Keine Änderung: ${results_count["no_change"]}"
    log "Fehler: ${results_count["errors"]} - ${errors[*]:-}"
    
    # Speichere State wenn kein Dry-Run
    if [[ "$dry_run" != "true" ]]; then
        # Aktualisiere History (max. 100 Einträge)
        local new_entry
        new_entry=$(jq -n --argjson ts "$(date -Iseconds)" \
            --argjson res "$(jq -n \
                --argjson synced_to_git "[\"$(IFS=$'\",\"'; echo "${synced_to_git[*]}")\"]" \
                --argjson synced_to_clawhub "[\"$(IFS=$'\",\"'; echo "${synced_to_clawhub[*]}")\"]" \
                --argjson updated_git "[\"$(IFS=$'\",\"'; echo "${updated_git[*]}")\"]" \
                --argjson updated_clawhub "[\"$(IFS=$'\",\"'; echo "${updated_clawhub[*]}")\"]" \
                --argjson no_change "[\"$(IFS=$'\",\"'; echo "${no_change[*]}")\"]" \
                --argjson errors "[\"$(IFS=$'\",\"'; echo "${errors[*]}")\"]" \
                '{synced_to_git: $synced_to_git, synced_to_clawhub: $synced_to_clawhub, updated_git: $updated_git, updated_clawhub: $updated_clawhub, no_change: $no_change, errors: $errors}')" \
            '{timestamp: $ts, results: $res}')
        
        state=$(echo "$state" | jq \
            --argjson entry "$new_entry" \
            '.sync_history |= (. + [$entry] | .[-100:])')
        
        save_state "$state"
    fi
    
    log "=== Sync Agent beendet ==="
    log ""
}

main "$@"
