#!/bin/bash
# sync_bulk.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Bulk Sync - Synchronisiert alle Skills

# Konfiguration
CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"

# Lade externe Funktionen
SCRIPT_DIR="/home/openclaw/.openclaw/workspace/scripts"
source "$SCRIPT_DIR/sync_clawhub_git.sh"

# Globale Arrays für Ergebnisse
declare -a SYNCED=()
declare -a SKIPPED=()
declare -a FAILED=()

sync_all_skills() {
    local dry_run=${1:-true}
    
    # Alle Skills finden
    declare -A ALL_SKILLS=()
    
    if [[ -d "$CLAWHUB_DIR" ]]; then
        while IFS= read -r dir; do
            local skill_name=$(basename "$dir")
            if [[ ! "$skill_name" =~ ^\. ]]; then
                ALL_SKILLS["$skill_name"]=1
            fi
        done < <(find "$CLAWHUB_DIR" -maxdepth 1 -type d -not -path "$CLAWHUB_DIR")
    fi
    
    if [[ -d "$GIT_DIR" ]]; then
        while IFS= read -r dir; do
            local skill_name=$(basename "$dir")
            if [[ ! "$skill_name" =~ ^\. ]]; then
                ALL_SKILLS["$skill_name"]=1
            fi
        done < <(find "$GIT_DIR" -maxdepth 1 -type d -not -path "$GIT_DIR")
    fi
    
    log "Bulk Sync: ${#ALL_SKILLS[@]} Skills gefunden"
    
    # Skills verarbeiten
    for skill in $(printf '%s\n' "${!ALL_SKILLS[@]}" | sort); do
        local clawhub_path="$CLAWHUB_DIR/$skill"
        local git_path="$GIT_DIR/$skill"
        
        if [[ -d "$clawhub_path" && ! -d "$git_path" ]]; then
            # Nur in ClawHub → zu Git
            if validate_skill "$clawhub_path"; then
                log "Syncing $skill to Git..."
                if sync_to_git "$skill" "$dry_run"; then
                    SYNCED+=("$skill → Git")
                else
                    FAILED+=("$skill")
                fi
            else
                SKIPPED+=("$skill (validation failed)")
            fi
            
        elif [[ -d "$git_path" && ! -d "$clawhub_path" ]]; then
            # Nur in Git → zu ClawHub
            if validate_skill "$git_path"; then
                log "Syncing $skill to ClawHub..."
                if sync_to_clawhub "$skill" "$dry_run"; then
                    SYNCED+=("$skill → ClawHub")
                else
                    FAILED+=("$skill")
                fi
            else
                SKIPPED+=("$skill (validation failed)")
            fi
            
        elif [[ -d "$clawhub_path" && -d "$git_path" ]]; then
            # In beiden - prüfe ob Update nötig
            local clawhub_mtime=0
            local git_mtime=0
            
            # Finde neueste Datei in ClawHub
            while IFS= read -r file; do
                local mtime=$(stat -c %Y "$file")
                if (( mtime > clawhub_mtime )); then
                    clawhub_mtime=$mtime
                fi
            done < <(find "$clawhub_path" -type f)
            
            # Finde neueste Datei in Git (ohne .git Verzeichnisse)
            while IFS= read -r file; do
                if [[ "$file" != */.git/* ]]; then
                    local mtime=$(stat -c %Y "$file")
                    if (( mtime > git_mtime )); then
                        git_mtime=$mtime
                    fi
                fi
            done < <(find "$git_path" -type f)
            
            local time_diff=$((clawhub_mtime > git_mtime ? clawhub_mtime - git_mtime : git_mtime - clawhub_mtime))
            
            if (( time_diff > 60 )); then
                if (( clawhub_mtime > git_mtime )); then
                    log "Updating $skill in Git..."
                    if sync_to_git "$skill" "$dry_run"; then
                        SYNCED+=("$skill → Git (update)")
                    else
                        FAILED+=("$skill")
                    fi
                else
                    log "Updating $skill in ClawHub..."
                    if sync_to_clawhub "$skill" "$dry_run"; then
                        SYNCED+=("$skill → ClawHub (update)")
                    else
                        FAILED+=("$skill")
                    fi
                fi
            else
                SKIPPED+=("$skill (already synced)")
            fi
        fi
    done 2>/dev/null || {
        log "Error processing $skill: $?" "ERROR"
        FAILED+=("$skill")
    }
    
    # Zusammenfassung
    echo
    printf '=%.0s' {1..60}
    echo
    if [[ "$dry_run" == true ]]; then
        echo "Bulk Sync DRY-RUN - Zusammenfassung"
    else
        echo "Bulk Sync EXECUTED - Zusammenfassung"
    fi
    printf '=%.0s' {1..60}
    echo
    echo "✅ Synchronisiert: ${#SYNCED[@]}"
    for item in "${SYNCED[@]}"; do
        echo "   - $item"
    done
    
    echo
    echo "⏭️  Übersprungen: ${#SKIPPED[@]}"
    if (( ${#SKIPPED[@]} <= 10 )); then
        for item in "${SKIPPED[@]}"; do
            echo "   - $item"
        done
    else
        echo "   - ${#SKIPPED[@]} Skills (bereits synchron oder Validierung fehlgeschlagen)"
    fi
    
    echo
    echo "❌ Fehlgeschlagen: ${#FAILED[@]}"
    for item in "${FAILED[@]}"; do
        echo "   - $item"
    done
    printf '=%.0s' {1..60}
    echo
}

main() {
    local dry_run=true
    local execute=false
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --execute)
                execute=true
                dry_run=false
                shift
                ;;
            *)
                echo "Unbekanntes Argument: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ "$dry_run" == false && "$execute" == false ]]; then
        echo "Bitte --dry-run oder --execute angeben"
        exit 1
    fi
    
    sync_all_skills "$dry_run"
}

main "$@"
