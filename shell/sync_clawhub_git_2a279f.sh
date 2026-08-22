#!/usr/bin/env bash
# sync_clawhub_git.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
# auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Bidirektionale ClawHub ↔ Git Synchronisation

# Konfiguration
# Resolve paths relative to this repository so the helper works both in the
# hosted workspace and in environments without a /workspace mount.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKSPACE_ROOT=$(dirname "$SCRIPT_DIR")
CLAWHUB_DIR="$WORKSPACE_ROOT/skills"
GIT_DIR="$WORKSPACE_ROOT/git/skills"
BACKUP_DIR="$WORKSPACE_ROOT/backups/sync"
LOG_FILE="$WORKSPACE_ROOT/logs/sync-agent.log"
IGNORED_NAMES=(".git" ".clawhub" "node_modules" "__pycache__" ".pytest_cache")
RESERVED_SKILL_NAMES=("github-clones" "skills" "backups" ".restore" "git" "Abstraktionen")
PRESERVED_TARGET_NAMES=("${IGNORED_NAMES[@]}")

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
    local skill_name
    skill_name=$(basename "$skill_dir")
    
    for reserved in "${RESERVED_SKILL_NAMES[@]}"; do
        if [[ "$skill_name" == "$reserved" ]]; then
            log "Validation failed: $skill_name is reserved and must not be synced as a skill" "ERROR"
            return 1
        fi
    done
    
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
        log "Validation failed: $skill_name missing SKILL.md" "ERROR"
        return 1
    fi
    return 0
}

_is_ignored_path() {
    local path="$1"
    local IFS='/'
    read -ra parts <<< "$path"
    for part in "${parts[@]}"; do
        for ignored in "${IGNORED_NAMES[@]}"; do
            if [[ "$part" == "$ignored" ]] || [[ "$part" == "__pycache__"* ]]; then
                return 0
            fi
        done
        if [[ "$part" == *.pyc ]]; then
            return 0
        fi
    done
    return 1
}

_is_generated_duplicate_path() {
    local root="$1"
    local rel_path="$2"
    local root_name
    root_name=$(basename "$root")
    
    local IFS='/'
    read -ra parts <<< "$rel_path"
    
    if [[ ${#parts[@]} -eq 0 ]]; then
        return 1
    fi
    
    if [[ "${parts[0]}" == "$root_name" ]]; then
        return 0
    fi
    
    for ((i=1; i<${#parts[@]}; i++)); do
        if [[ "${parts[i]}" == "${parts[$((i-1))]}" ]]; then
            return 0
        fi
    done
    
    return 1
}

iter_sync_files() {
    local root="$1"
    local current_root dirs files dir file rel_root rel_dir rel_path
    
    while IFS= read -r -d '' current_root; do
        rel_root=${current_root#$root/}
        if [[ "$rel_root" == "." ]]; then
            rel_root=""
        fi
        
        if _is_ignored_path "$rel_root"; then
            continue
        fi
        
        # Get directories
        mapfile -t dirs < <(find "$current_root" -maxdepth 1 -type d -not -path "$current_root" -printf '%f\n' 2>/dev/null || true)
        
        # Filter directories
        local kept_dirs=()
        for dir in "${dirs[@]}"; do
            if [[ " ${IGNORED_NAMES[*]} " =~ " $dir " ]] || [[ "$dir" == __pycache__* ]]; then
                continue
            fi
            rel_dir="$rel_root/$dir"
            if [[ -n "$rel_root" ]] && [[ "$rel_dir" == "$dir/$dir" ]]; then
                continue
            fi
            if _is_generated_duplicate_path "$root" "$rel_dir"; then
                continue
            fi
            kept_dirs+=("$dir")
        done
        
        # Get files
        mapfile -t files < <(find "$current_root" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true)
        
        for file in "${files[@]}"; do
            if [[ " ${IGNORED_NAMES[*]} " =~ " $file " ]] || [[ "$file" == *.pyc ]]; then
                continue
            fi
            rel_path="$rel_root/$file"
            if _is_ignored_path "$rel_path"; then
                continue
            fi
            if _is_generated_duplicate_path "$root" "$rel_path"; then
                continue
            fi
            if [[ "$file" == "SKILL.md" ]] && [[ "$rel_path" != "SKILL.md" ]]; then
                continue
            fi
            echo "$current_root/$file:$rel_path"
        done
    done < <(find "$root" -type d -print0 2>/dev/null || true)
}

reset_sync_target() {
    local target="$1"
    mkdir -p "$target"
    
    local children
    mapfile -t children < <(find "$target" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null || true)
    
    for child in "${children[@]}"; do
        local child_path="$target/$child"
        local preserve=false
        
        for preserved in "${PRESERVED_TARGET_NAMES[@]}"; do
            if [[ "$child" == "$preserved" ]]; then
                preserve=true
                break
            fi
        done
        
        if [[ "$preserve" == false ]]; then
            if [[ -d "$child_path" ]] && [[ ! -L "$child_path" ]]; then
                rm -rf "$child_path"
            else
                rm -f "$child_path"
            fi
        fi
    done
}

copy_sync_files() {
    local source="$1"
    local target="$2"
    
    reset_sync_target "$target"
    
    local line src_file rel_path dest_file
    while IFS=: read -r src_file rel_path; do
        dest_file="$target/$rel_path"
        mkdir -p "$(dirname "$dest_file")"
        cp -p "$src_file" "$dest_file"
    done < <(iter_sync_files "$source")
}

# Backup
create_backup() {
    local source="$1"
    local skill_name="$2"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/${skill_name}_${timestamp}"
    
    # Backup verzeichnis löschen falls es existiert
    if [[ -e "$backup_path" ]]; then
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
    
    # Ensure the path points to a regular file.
    if [[ ! -f "$file_path" ]]; then
        echo ""
        return
    fi
    
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | cut -d' ' -f1
    else
        log "No SHA256 utility found" "ERROR"
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
    if [[ "$dry_run" == false ]] && [[ -e "$target" ]]; then
        create_backup "$target" "$skill_name"
    fi
    
    # Änderungen erkennen
    local changes=()
    local line src_file rel_path tgt_file src_hash tgt_hash
    while IFS=: read -r src_file rel_path; do
        tgt_file="$target/$rel_path"
        if [[ ! -e "$tgt_file" ]]; then
            changes+=("ADD $rel_path")
        else
            src_hash=$(get_file_hash "$src_file")
            tgt_hash=$(get_file_hash "$tgt_file")
            if [[ "$src_hash" != "$tgt_hash" ]]; then
                changes+=("UPDATE $rel_path")
            fi
        fi
    done < <(iter_sync_files "$source")
    
    # Dry-Run Report
    if [[ "$dry_run" == true ]]; then
        log "DRY-RUN: $skill_name - ${#changes[@]} changes"
        for change in "${changes[@]}"; do
            log "  $change"
        done
        return 0
    fi
    
    # Echte Synchronisation
    log "SYNC: $skill_name - Applying ${#changes[@]} changes"
    copy_sync_files "$source" "$target"
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
    if [[ "$dry_run" == false ]] && [[ -e "$target" ]]; then
        create_backup "$target" "$skill_name"
    fi
    
    # Änderungen erkennen (gleiche Logik wie oben)
    local changes=()
    local line src_file rel_path tgt_file src_hash tgt_hash
    while IFS=: read -r src_file rel_path; do
        tgt_file="$target/$rel_path"
        if [[ ! -e "$tgt_file" ]]; then
            changes+=("ADD $rel_path")
        else
            src_hash=$(get_file_hash "$src_file")
            tgt_hash=$(get_file_hash "$tgt_file")
            if [[ "$src_hash" != "$tgt_hash" ]]; then
                changes+=("UPDATE $rel_path")
            fi
        fi
    done < <(iter_sync_files "$source")
    
    # Dry-Run Report
    if [[ "$dry_run" == true ]]; then
        log "DRY-RUN: $skill_name - ${#changes[@]} changes"
        for change in "${changes[@]}"; do
            log "  $change"
        done
        return 0
    fi
    
    # Echte Synchronisation
    log "SYNC: $skill_name - Applying ${#changes[@]} changes"
    copy_sync_files "$source" "$target"
    log "SYNC: $skill_name - Complete"
    return 0
}

# Hauptfunktion
main() {
    local skill=""
    local direction=""
    local dry_run=true
    local force=false
    
    # Parse arguments
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
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$skill" ]] || [[ -z "$direction" ]]; then
        echo "Error: --skill and --direction are required" >&2
        exit 1
    fi
    
    if [[ "$direction" != "to-git" ]] && [[ "$direction" != "to-clawhub" ]]; then
        echo "Error: --direction must be either 'to-git' or 'to-clawhub'" >&2
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
