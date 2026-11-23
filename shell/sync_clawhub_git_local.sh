#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "7adc706adebda10f31a5cbcbd9add70e59f9aa2d0b92df587d9188f508b78fe7", "source_sha256": "1bde9ce66616d24f21a9092c84abb4b447779e6077ec9035f2df678b92bb76f4", "target_language": "shell"}
# sync_clawhub_git_local.py — portiert nach shell
# Quelle: python, workspace@local:scripts/sync_clawhub_git_local.py
# auch in: workspace@local:scripts/sync_clawhub_git.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Bidirektionale ClawHub ↔ Git Synchronisation

# Konfiguration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
readonly CLAWHUB_DIR="$WORKSPACE_DIR/skills"
readonly GIT_DIR="$WORKSPACE_DIR/git/skills"
readonly BACKUP_DIR="$WORKSPACE_DIR/backups/sync"
readonly LOG_FILE="$WORKSPACE_DIR/logs/sync-agent.log"

# Erstelle Verzeichnisse
mkdir -p "$GIT_DIR" "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

# Logging
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[$timestamp] [$level] $message"
    echo "$entry"
    echo "$entry" >> "$LOG_FILE"
}

# Validierung
validate_skill() {
    local skill_dir="$1"
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
        log "Validation failed: $(basename "$skill_dir") missing SKILL.md" "ERROR"
        return 1
    fi
    return 0
}

# Backup
create_backup() {
    local source="$1"
    local skill_name="$2"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/${skill_name}_${timestamp}"
    
    # Backup verzeichnis löschen falls es existiert
    if [[ -d "$backup_path" ]]; then
        if rm -rf "$backup_path"; then
            log "Removed existing backup: $backup_path"
        else
            log "Failed to remove existing backup $backup_path" "ERROR"
            return 1
        fi
    fi
    
    if cp -r "$source" "$backup_path"; then
        log "Backup created: $backup_path"
        return 0
    else
        log "Backup failed" "ERROR"
        return 1
    fi
}

# Hash-Vergleich
get_file_hash() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        sha256sum "$file_path" | cut -d' ' -f1
    else
        echo ""
    fi
}

# Sync Richtung ClawHub → Git
sync_to_git() {
    local skill_name="$1"
    local dry_run="${2:-true}"
    local source="$CLAWHUB_DIR/$skill_name"
    local target="$GIT_DIR/$skill_name"
    
    if ! validate_skill "$source"; then
        return 1
    fi
    
    # Backup vor Änderungen (nur wenn target existiert)
    if [[ "$dry_run" == "false" ]] && [[ -d "$target" ]]; then
        create_backup "$target" "$skill_name" || return 1
    fi
    
    # Änderungen erkennen
    local changes=()
    while IFS= read -r -d '' file; do
        local rel_path="${file#$source/}"
        local src_file="$source/$rel_path"
        local tgt_file="$target/$rel_path"
        
        # Vergleich
        if [[ ! -f "$tgt_file" ]]; then
            changes+=("ADD $rel_path")
        else
            local src_hash
            local tgt_hash
            src_hash=$(get_file_hash "$src_file")
            tgt_hash=$(get_file_hash "$tgt_file")
            if [[ "$src_hash" != "$tgt_hash" ]]; then
                changes+=("UPDATE $rel_path")
            fi
        fi
    done < <(find "$source" -type f -print0)
    
    # Dry-Run Report
    if [[ "$dry_run" == "true" ]]; then
        log "DRY-RUN: $skill_name - ${#changes[@]} changes"
        for change in "${changes[@]}"; do
            log "  $change"
        done
        return 0
    fi
    
    # Echte Synchronisation
    log "SYNC: $skill_name - Applying ${#changes[@]} changes"
    if [[ -d "$target" ]]; then
        rsync -av --exclude='.git' "$source/" "$target/"
    else
        mkdir -p "$target"
        rsync -av --exclude='.git' "$source/" "$target/"
    fi
    log "SYNC: $skill_name - Complete"
    return 0
}

# Sync Richtung Git → ClawHub
sync_to_clawhub() {
    local skill_name="$1"
    local dry_run="${2:-true}"
    local source="$GIT_DIR/$skill_name"
    local target="$CLAWHUB_DIR/$skill_name"
    
    if ! validate_skill "$source"; then
        return 1
    fi
    
    # Backup vor Änderungen (nur wenn target existiert)
    if [[ "$dry_run" == "false" ]] && [[ -d "$target" ]]; then
        create_backup "$target" "$skill_name" || return 1
    fi
    
    # Änderungen erkennen (gleiche Logik wie oben)
    local changes=()
    while IFS= read -r -d '' file; do
        local rel_path="${file#$source/}"
        local src_file="$source/$rel_path"
        local tgt_file="$target/$rel_path"
        
        if [[ ! -f "$tgt_file" ]]; then
            changes+=("ADD $rel_path")
        else
            local src_hash
            local tgt_hash
            src_hash=$(get_file_hash "$src_file")
            tgt_hash=$(get_file_hash "$tgt_file")
            if [[ "$src_hash" != "$tgt_hash" ]]; then
                changes+=("UPDATE $rel_path")
            fi
        fi
    done < <(find "$source" -type f -print0)
    
    # Dry-Run Report
    if [[ "$dry_run" == "true" ]]; then
        log "DRY-RUN: $skill_name - ${#changes[@]} changes"
        for change in "${changes[@]}"; do
            log "  $change"
        done
        return 0
    fi
    
    # Echte Synchronisation
    log "SYNC: $skill_name - Applying ${#changes[@]} changes"
    if [[ -d "$target" ]]; then
        rsync -av --exclude='.git' "$source/" "$target/"
    else
        mkdir -p "$target"
        rsync -av --exclude='.git' "$source/" "$target/"
    fi
    log "SYNC: $skill_name - Complete"
    return 0
}

# Hauptfunktion
main() {
    local skill=""
    local direction=""
    local dry_run="true"
    local force="false"
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skill)
                skill="$2"
                shift 2
                ;;
            --direction)
                direction="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            *)
                echo "Unbekanntes Argument: $1" >&2
                exit 1
                ;;
        esac
    done
    
    # Validierung der Argumente
    if [[ -z "$skill" ]] || [[ -z "$direction" ]]; then
        echo "Fehler: --skill und --direction sind erforderlich" >&2
        exit 1
    fi
    
    if [[ "$direction" != "to-git" ]] && [[ "$direction" != "to-clawhub" ]]; then
        echo "Fehler: --direction muss 'to-git' oder 'to-clawhub' sein" >&2
        exit 1
    fi
    
    log "Starting sync: $skill ($direction)"
    
    local success=1
    if [[ "$direction" == "to-git" ]]; then
        sync_to_git "$skill" "$dry_run"
        success=$?
    else
        sync_to_clawhub "$skill" "$dry_run"
        success=$?
    fi
    
    if [[ $success -ne 0 ]]; then
        log "Sync failed" "ERROR"
        exit 1
    fi
    
    log "Sync completed"
}

main "$@"
