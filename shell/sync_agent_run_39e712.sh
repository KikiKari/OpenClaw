#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "e1263baf2dc77c2b5b0ea98843c70297bf475c87eb4c87192239b2c6b340bfb6", "source_sha256": "39e712425a2c8c6fe6bad486ac97ef9c9d7f8a52e1abc18d11018d93ddc9d170", "target_language": "shell"}
# sync_agent_run.py — portiert nach shell
# Quelle: python, workspace@local:scripts/sync_agent_run.py
# auch in: workspace@local:scripts/sync_agent.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

# Konfiguration
CLAWHUB_DIR="/workspace/skills"
GIT_DIR="/workspace/git/skills"
STATE_FILE="/workspace/db/sync_state.json"
BACKUP_ROOT="/workspace/backups/sync_agent"

# Sicherstellen, dass das Skriptverzeichnis im PATH ist
SCRIPTS_DIR="/workspace/scripts"
PATH="$SCRIPTS_DIR:$PATH"

# Lade externe Funktionen
source "$SCRIPTS_DIR/sync_clawhub_git.sh"

# Funktion zum Laden des Sync-States
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"sync_history":[],"pending":[]}'
    fi
}

# Funktion zum Speichern des Sync-States
save_state() {
    local state_content="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$state_content" > "$STATE_FILE"
}

# Funktion zum Finden aller validen Skills
get_all_skills() {
    local skills=()
    
    # Skills aus ClawHub
    while IFS= read -r dir; do
        local skill_name
        skill_name=$(basename "$dir")
        if [[ ! "$skill_name" =~ ^[._] ]] && [[ -f "$dir/SKILL.md" ]]; then
            skills+=("$skill_name")
        fi
    done < <(find "$CLAWHUB_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    # Skills aus Git
    while IFS= read -r dir; do
        local skill_name
        skill_name=$(basename "$dir")
        if [[ ! "$skill_name" =~ ^[._] ]] && [[ -f "$dir/SKILL.md" ]]; then
            # Prüfen ob Skill noch nicht in Liste ist
            local found=false
            for existing_skill in "${skills[@]}"; do
                if [[ "$existing_skill" == "$skill_name" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == false ]]; then
                skills+=("$skill_name")
            fi
        fi
    done < <(find "$GIT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    # Sortierte Ausgabe
    printf '%s\n' "${skills[@]}" | sort -u
}

# Funktion zur Initialisierung eines Git-Repos
init_git_repo() {
    local skill_path="$1"
    local skill_name="$2"
    local git_dir="$skill_path/.git"
    
    if [[ ! -d "$git_dir" ]]; then
        pushd "$skill_path" >/dev/null || return 1
        git init >/dev/null 2>&1
        git add . >/dev/null 2>&1
        git commit -m "Initial commit: $skill_name skill" >/dev/null 2>&1
        log "Git initialized for $skill_name"
        popd >/dev/null || return 1
    fi
}

# Funktion zum Erstellen eines Backups
backup_skill_dir() {
    local skill_path="$1"
    local skill_name="$2"
    
    if [[ ! -d "$skill_path" ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_dir="$BACKUP_ROOT/$timestamp"
    mkdir -p "$backup_dir"
    local archive_name="${skill_name}_${timestamp}.tar.gz"
    local archive_path="$backup_dir/$archive_name"
    
    # Entferne .gz Endung für make_archive
    local base_name="${archive_path%.gz}"
    tar -czf "$archive_path" -C "$skill_path" .
    log "Backup created for $skill_name at $archive_path"
}

# Hilfsfunktion zum Erstellen von Datei-Hashes
get_hashes() {
    local skill_dir="$1"
    local hash_dict=""
    
    while IFS= read -r file; do
        local relative_path
        relative_path="${file#$skill_dir/}"
        # Ignoriere .git Verzeichnisse
        if [[ "$relative_path" != .git* ]]; then
            local file_hash
            file_hash=$(get_file_hash "$file")
            hash_dict+="$relative_path:$file_hash;"
        fi
    done < <(find "$skill_dir" -type f)
    
    echo "$hash_dict"
}

# Bidirektionale Synchronisation eines Skills
sync_skill_bidirectional() {
    local skill_name="$1"
    local dry_run="${2:-false}"
    local clawhub_path="$CLAWHUB_DIR/$skill_name"
    local git_path="$GIT_DIR/$skill_name"
    
    # Fall 1: Nur in ClawHub → zu Git
    if [[ -d "$clawhub_path" ]] && [[ ! -d "$git_path" ]]; then
        log "NEW in ClawHub: $skill_name → syncing to Git"
        if [[ "$dry_run" == false ]]; then
            backup_skill_dir "$clawhub_path" "${skill_name}_clawhub"
        fi
        if sync_to_git "$skill_name" "$dry_run"; then
            if [[ "$dry_run" == false ]]; then
                init_git_repo "$git_path" "$skill_name"
            fi
            echo "synced_to_git"
            return 0
        fi
        
    # Fall 2: Nur in Git → zu ClawHub
    elif [[ -d "$git_path" ]] && [[ ! -d "$clawhub_path" ]]; then
        log "NEW in Git: $skill_name → syncing to ClawHub"
        if [[ "$dry_run" == false ]]; then
            backup_skill_dir "$git_path" "${skill_name}_git"
        fi
        if sync_to_clawhub "$skill_name" "$dry_run"; then
            echo "synced_to_clawhub"
            return 0
        fi
        
    # Fall 3: In beiden vorhanden → Vergleiche Timestamps
    elif [[ -d "$clawhub_path" ]] && [[ -d "$git_path" ]]; then
        # Validierung der Skills
        if ! validate_skill "$clawhub_path"; then
            log "Validation failed for ClawHub skill: $skill_name" "ERROR"
            echo "error"
            return 0
        fi
        if ! validate_skill "$git_path"; then
            log "Validation failed for Git skill: $skill_name" "ERROR"
            echo "error"
            return 0
        fi
        
        # Berechne Hashes
        local clawhub_hashes
        local git_hashes
        clawhub_hashes=$(get_hashes "$clawhub_path")
        git_hashes=$(get_hashes "$git_path")
        
        if [[ "$clawhub_hashes" != "$git_hashes" ]]; then
            log "Content difference detected for: $skill_name"
            
            # Bestimme Richtung basierend auf Modifikationszeit
            local clawhub_mtime
            local git_mtime
            clawhub_mtime=$(stat -c %Y "$clawhub_path")
            git_mtime=$(stat -c %Y "$git_path")
            
            local direction
            if [[ "$clawhub_mtime" -ge "$git_mtime" ]]; then
                direction="to-git"
            else
                direction="to-clawhub"
            fi
            
            log "UPDATE: $skill_name → syncing $direction"
            if [[ "$dry_run" == false ]]; then
                backup_skill_dir "$clawhub_path" "${skill_name}_clawhub"
                backup_skill_dir "$git_path" "${skill_name}_git"
            fi
            
            local sync_result=false
            if [[ "$direction" == "to-git" ]]; then
                if sync_to_git "$skill_name" "$dry_run"; then
                    sync_result=true
                    if [[ "$dry_run" == false ]]; then
                        pushd "$git_path" >/dev/null || return 1
                        git add . >/dev/null 2>&1
                        git commit -m "Sync from ClawHub content diff: $(date +"%Y-%m-%d %H:%M")" >/dev/null 2>&1
                        popd >/dev/null || return 1
                    fi
                fi
            else
                if sync_to_clawhub "$skill_name" "$dry_run"; then
                    sync_result=true
                fi
            fi
            
            if [[ "$sync_result" == true ]]; then
                if [[ "$direction" == "to-git" ]]; then
                    echo "updated_git"
                else
                    echo "updated_clawhub"
                fi
                return 0
            else
                log "Failed to sync $skill_name to Git after content diff" "ERROR"
                echo "error"
                return 0
            fi
        else
            log "Content is identical for: $skill_name"
            echo "no_change"
            return 0
        fi
    fi
    
    echo "no_change"
}

# Hauptfunktion
main() {
    local dry_run=false
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    log "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    local state
    state=$(load_state)
    local all_skills
    mapfile -t all_skills < <(get_all_skills)
    log "Gefundene Skills: ${#all_skills[@]}"
    
    # Ergebnisstruktur initialisieren
    declare -A results=(
        ["synced_to_git"]=""
        ["synced_to_clawhub"]=""
        ["updated_git"]=""
        ["updated_clawhub"]=""
        ["no_change"]=""
        ["errors"]=""
    )
    
    # Jeden Skill synchronisieren
    for skill in "${all_skills[@]}"; do
        if [[ -n "$skill" ]]; then
            local result
            result=$(sync_skill_bidirectional "$skill" "$dry_run" 2>&1) || {
                log "ERROR syncing $skill: $result" "ERROR"
                results["errors"]+="$skill "
                continue
            }
            
            case "$result" in
                synced_to_git)
                    results["synced_to_git"]+="$skill "
                    ;;
                synced_to_clawhub)
                    results["synced_to_clawhub"]+="$skill "
                    ;;
                updated_git)
                    results["updated_git"]+="$skill "
                    ;;
                updated_clawhub)
                    results["updated_clawhub"]+="$skill "
                    ;;
                no_change)
                    results["no_change"]+="$skill "
                    ;;
                error)
                    results["errors"]+="$skill "
                    ;;
            esac
        fi
    done
    
    # Zusammenfassung erstellen
    local synced_to_git_count=0
    local synced_to_clawhub_count=0
    local updated_git_count=0
    local updated_clawhub_count=0
    local no_change_count=0
    local errors_count=0
    
    [[ -n "${results[synced_to_git]}" ]] && synced_to_git_count=$(echo "${results[synced_to_git]}" | wc -w) || synced_to_git_count=0
    [[ -n "${results[synced_to_clawhub]}" ]] && synced_to_clawhub_count=$(echo "${results[synced_to_clawhub]}" | wc -w) || synced_to_clawhub_count=0
    [[ -n "${results[updated_git]}" ]] && updated_git_count=$(echo "${results[updated_git]}" | wc -w) || updated_git_count=0
    [[ -n "${results[updated_clawhub]}" ]] && updated_clawhub_count=$(echo "${results[updated_clawhub]}" | wc -w) || updated_clawhub_count=0
    [[ -n "${results[no_change]}" ]] && no_change_count=$(echo "${results[no_change]}" | wc -w) || no_change_count=0
    [[ -n "${results[errors]}" ]] && errors_count=$(echo "${results[errors]}" | wc -w) || errors_count=0
    
    log ""
    log "=== SYNC ZUSAMMENFASSUNG ==="
    log "Neu in Git: $synced_to_git_count - ${results[synced_to_git]}"
    log "Neu in ClawHub: $synced_to_clawhub_count - ${results[synced_to_clawhub]}"
    log "Git aktualisiert: $updated_git_count - ${results[updated_git]}"
    log "ClawHub aktualisiert: $updated_clawhub_count - ${results[updated_clawhub]}"
    log "Keine Änderung: $no_change_count"
    log "Fehler: $errors_count - ${results[errors]}"
    
    # State speichern, wenn kein Dry-Run
    if [[ "$dry_run" == false ]]; then
        # Historie aktualisieren
        local timestamp
        timestamp=$(date -Iseconds)
        local new_entry="{\"timestamp\":\"$timestamp\",\"results\":{\"synced_to_git\":[\"${results[synced_to_git]%% }\"],\"synced_to_clawhub\":[\"${results[synced_to_clawhub]%% }\"],\"updated_git\":[\"${results[updated_git]%% }\"],\"updated_clawhub\":[\"${results[updated_clawhub]%% }\"],\"no_change\":[\"${results[no_change]%% }\"],\"errors\":[\"${results[errors]%% }\"]}}"
        
        # Aktualisiere den State
        local updated_state
        updated_state=$(echo "$state" | jq --argjson entry "$new_entry" '
            .sync_history |= (. + [$entry]) |
            .sync_history |= .[-100:]'
        )
        
        save_state "$updated_state"
    fi
    
    log "=== Sync Agent beendet ==="
    log ""
}

# Skript ausführen
main "$@"
