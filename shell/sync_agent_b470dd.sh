#!/bin/bash
# sync_agent.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

readonly SCRIPT_DIR="/home/openclaw/.openclaw/workspace/scripts"
readonly CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
readonly GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"
readonly STATE_FILE="/home/openclaw/.openclaw/workspace/db/sync_state.json"

# Lade externe Funktionen
source "${SCRIPT_DIR}/sync_clawhub_git.sh"

# Globale Variablen für Ergebnisstatistik
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
        echo '{"sync_history": [], "pending": []}'
    fi
}

save_state() {
    local state="$1"
    # Stelle sicher, dass das Verzeichnis existiert
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$state" > "$STATE_FILE"
}

get_all_skills() {
    # Findet alle Skills in beiden Verzeichnissen
    local skills=()
    
    # Skills aus ClawHub
    while IFS= read -r dir; do
        local skill_name
        skill_name=$(basename "$dir")
        
        # Prüfe ob es sich um einen gültigen Skill handelt
        if [[ ! "$skill_name" =~ ^\. ]] && 
           ! is_reserved_skill "$skill_name" && 
           [[ -f "$dir/SKILL.md" ]]; then
            skills+=("$skill_name")
        fi
    done < <(find "$CLAWHUB_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    # Skills aus Git hinzufügen
    while IFS= read -r dir; do
        local skill_name
        skill_name=$(basename "$dir")
        
        # Prüfe ob es sich um einen gültigen Skill handelt
        if [[ ! "$skill_name" =~ ^\. ]] && 
           ! is_reserved_skill "$skill_name" && 
           [[ -f "$dir/SKILL.md" ]]; then
            # Vermeide Duplikate
            local found=false
            for existing in "${skills[@]}"; do
                if [[ "$existing" == "$skill_name" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == false ]]; then
                skills+=("$skill_name")
            fi
        fi
    done < <(find "$GIT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    # Sortiere und gib zurück
    printf '%s\n' "${skills[@]}" | sort -u
}

init_git_repo() {
    local skill_path="$1"
    local skill_name="$2"
    
    # Initialisiert Git-Repo wenn nötig
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

sync_skill_bidirectional() {
    local skill_name="$1"
    local clawhub_path="${CLAWHUB_DIR}/${skill_name}"
    local git_path="${GIT_DIR}/${skill_name}"
    
    # Fall 1: Nur in ClawHub → zu Git
    if [[ -d "$clawhub_path" ]] && [[ ! -d "$git_path" ]]; then
        log "NEW in ClawHub: $skill_name → syncing to Git"
        if sync_to_git "$skill_name" "false"; then
            init_git_repo "$git_path" "$skill_name"
            echo "synced_to_git"
            return
        fi
    
    # Fall 2: Nur in Git → zu ClawHub
    elif [[ -d "$git_path" ]] && [[ ! -d "$clawhub_path" ]]; then
        log "NEW in Git: $skill_name → syncing to ClawHub"
        if sync_to_clawhub "$skill_name" "false"; then
            echo "synced_to_clawhub"
            return
        fi
    
    # Fall 3: In beiden vorhanden
    elif [[ -d "$clawhub_path" ]] && [[ -d "$git_path" ]]; then
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

        local clawhub_changes
        clawhub_changes=$(preview_changes "$clawhub_path" "$git_path")
        local git_changes
        git_changes=$(preview_changes "$git_path" "$clawhub_path")

        if [[ -z "$clawhub_changes" ]] && [[ -z "$git_changes" ]]; then
            log "Content is identical for: $skill_name"
            echo "no_change"
            return
        fi

        if [[ -n "$clawhub_changes" ]] && [[ -z "$git_changes" ]]; then
            log "Content difference detected for: $skill_name"
            log "UPDATE: $skill_name ClawHub content is newer or different → syncing to Git"
            if sync_to_git "$skill_name" "false"; then
                (
                    cd "$git_path" || exit 1
                    git add . >/dev/null 2>&1
                    git commit -m "Sync from ClawHub content diff: $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1
                )
                echo "updated_git"
                return
            fi
            log "Failed to sync $skill_name to Git after content diff" "ERROR"
            echo "error"
            return
        fi

        if [[ -z "$clawhub_changes" ]] && [[ -n "$git_changes" ]]; then
            log "Content difference detected for: $skill_name"
            log "UPDATE: $skill_name Git content is newer or different → syncing to ClawHub"
            if sync_to_clawhub "$skill_name" "false"; then
                echo "updated_clawhub"
                return
            fi
            log "Failed to sync $skill_name to ClawHub after content diff" "ERROR"
            echo "error"
            return
        fi

        log "Content difference detected for: $skill_name"
        local clawhub_mtime
        clawhub_mtime=$(newest_mtime "$clawhub_path")
        local git_mtime
        git_mtime=$(newest_mtime "$git_path")

        if (( $(echo "$clawhub_mtime >= $git_mtime" | bc -l) )); then
            log "UPDATE: $skill_name ClawHub content is newer or different → syncing to Git"
            if sync_to_git "$skill_name" "false"; then
                (
                    cd "$git_path" || exit 1
                    git add . >/dev/null 2>&1
                    git commit -m "Sync from ClawHub content diff: $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1
                )
                echo "updated_git"
                return
            fi
        else
            log "UPDATE: $skill_name Git content is newer or different → syncing to ClawHub"
            if sync_to_clawhub "$skill_name" "false"; then
                echo "updated_clawhub"
                return
            fi
        fi

        log "Failed to resolve content diff for $skill_name" "ERROR"
        echo "error"
        return
    fi
    
    echo "no_change"
}

preview_changes() {
    local source_dir="$1"
    local target_dir="$2"
    local changes=""
    
    # Berechnet Sync-Änderungen in einer Richtung, ohne zu schreiben
    while IFS= read -r file_info; do
        local src_file
        src_file=$(echo "$file_info" | cut -d'|' -f1)
        local rel_path
        rel_path=$(echo "$file_info" | cut -d'|' -f2)
        local tgt_file="${target_dir}/${rel_path}"
        
        if [[ ! -f "$tgt_file" ]]; then
            changes+="$changes ADD $rel_path"$'\n'
        else
            local src_hash
            src_hash=$(get_file_hash "$src_file")
            local tgt_hash
            tgt_hash=$(get_file_hash "$tgt_file")
            
            if [[ "$src_hash" != "$tgt_hash" ]]; then
                changes+="$changes UPDATE $rel_path"$'\n'
            fi
        fi
    done < <(iter_sync_files "$source_dir")
    
    echo -n "$changes"
}

newest_mtime() {
    local skill_dir="$1"
    local max_mtime=0
    
    # Ermittelt die neueste mtime über alle relevanten Dateien
    while IFS= read -r file_info; do
        local file_path
        file_path=$(echo "$file_info" | cut -d'|' -f1)
        if [[ -f "$file_path" ]]; then
            local mtime
            mtime=$(stat -c %Y "$file_path" 2>/dev/null || echo "0")
            if (( mtime > max_mtime )); then
                max_mtime=$mtime
            fi
        fi
    done < <(iter_sync_files "$skill_dir")
    
    echo "$max_mtime"
}

main() {
    log "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    # Load previous state
    local state
    state=$(load_state)
    local all_skills
    mapfile -t all_skills < <(get_all_skills)
    log "Gefundene Skills: ${#all_skills[@]}"
    
    # Dry-Run Phase: only report changes, no actual modifications
    log "--- Dry-Run Phase Start ---"
    for skill in "${all_skills[@]}"; do
        # Perform dry-run sync in both directions to capture potential changes
        sync_to_git "$skill" "true" >/dev/null 2>&1 || true
        sync_to_clawhub "$skill" "true" >/dev/null 2>&1 || true
    done
    log "--- Dry-Run Phase End ---"
    
    # Actual Sync Phase
    for skill in "${all_skills[@]}"; do
        local result
        result=$(sync_skill_bidirectional "$skill" 2>&1) || true
        
        case "$result" in
            "synced_to_git")
                synced_to_git+=("$skill")
                ;;
            "synced_to_clawhub")
                synced_to_clawhub+=("$skill")
                ;;
            "updated_git")
                updated_git+=("$skill")
                ;;
            "updated_clawhub")
                updated_clawhub+=("$skill")
                ;;
            "no_change")
                no_change+=("$skill")
                ;;
            *)
                errors+=("$skill")
                ;;
        esac
    done
    
    # Zusammenfassung
    log "\n=== SYNC ZUSAMMENFASSUNG ==="
    log "Neu in Git: ${#synced_to_git[@]} - ${synced_to_git[*]:-[]}"
    log "Neu in ClawHub: ${#synced_to_clawhub[@]} - ${synced_to_clawhub[*]:-[]}"
    log "Git aktualisiert: ${#updated_git[@]} - ${updated_git[*]:-[]}"
    log "ClawHub aktualisiert: ${#updated_clawhub[@]} - ${updated_clawhub[*]:-[]}"
    log "Keine Änderung: ${#no_change[@]}"
    log "Fehler: ${#errors[@]} - ${errors[*]:-[]}"
    
    # State speichern
    local timestamp
    timestamp=$(date --iso-8601=seconds)
    local new_entry="{\"timestamp\":\"$timestamp\",\"results\":{\"synced_to_git\":[\"$(IFS='","'; echo "${synced_to_git[*]}")\"],\"synced_to_clawhub\":[\"$(IFS='","'; echo "${synced_to_clawhub[*]}")\"],\"updated_git\":[\"$(IFS='","'; echo "${updated_git[*]}")\"],\"updated_clawhub\":[\"$(IFS='","'; echo "${updated_clawhub[*]}")\"],\"no_change\":[\"$(IFS='","'; echo "${no_change[*]}")\"],\"errors\":[\"$(IFS='","'; echo "${errors[*]}")\"]}}"
    
    # Füge neuen Eintrag hinzu und behalte nur letzte 100
    local history
    history=$(echo "$state" | jq -r '.sync_history // []' 2>/dev/null || echo "[]")
    local updated_history
    updated_history=$(echo "$history" | jq ". + [$new_entry]" 2>/dev/null || echo "[$new_entry]")
    local trimmed_history
    trimmed_history=$(echo "$updated_history" | jq '.[-100:]' 2>/dev/null || echo "$updated_history")
    
    local new_state
    new_state=$(echo "{}" | jq --argjson hist "$trimmed_history" '.sync_history = $hist')
    save_state "$new_state"
    
    log "=== Sync Agent beendet ==="
}

# Starte Hauptprogramm
main "$@"
