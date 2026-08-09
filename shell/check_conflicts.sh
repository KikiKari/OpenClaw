#!/usr/bin/env bash
# check_conflicts.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Check Conflicts - Erkennt Sync-Konflikte

CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"

# Lade sync Funktionen
SCRIPTS_DIR="/home/openclaw/.openclaw/workspace/scripts"
if [[ ! -f "$SCRIPTS_DIR/sync_clawhub_git.sh" ]]; then
    echo "Fehler: sync_clawhub_git.sh nicht gefunden in $SCRIPTS_DIR" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/sync_clawhub_git.sh"

get_file_hash() {
    local file="$1"
    if [[ -f "$file" ]]; then
        md5sum "$file" | cut -d' ' -f1
    else
        echo "Datei nicht gefunden: $file" >&2
        return 1
    fi
}

check_conflicts() {
    local conflicts=()
    local common_skills=()
    
    # Alle Skills die in beiden Orten existieren
    if [[ -d "$CLAWHUB_DIR" && -d "$GIT_DIR" ]]; then
        local clawhub_skills=()
        local git_skills=()
        
        while IFS= read -r dir; do
            if [[ -d "$dir" ]]; then
                clawhub_skills+=("$(basename "$dir")")
            fi
        done < <(find "$CLAWHUB_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
        
        while IFS= read -r dir; do
            if [[ -d "$dir" ]]; then
                git_skills+=("$(basename "$dir")")
            fi
        done < <(find "$GIT_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
        
        # Finde gemeinsame Skills
        for skill in "${clawhub_skills[@]}"; do
            for git_skill in "${git_skills[@]}"; do
                if [[ "$skill" == "$git_skill" ]]; then
                    common_skills+=("$skill")
                    break
                fi
            done
        done
    fi
    
    echo "Prüfe ${#common_skills[@]} Skills auf Konflikte..."
    echo
    
    local skill_conflicts
    local conflict_found
    
    for skill in "${common_skills[@]}"; do
        local clawhub_path="$CLAWHUB_DIR/$skill"
        local git_path="$GIT_DIR/$skill"
        skill_conflicts=()
        
        # Hole Dateien aus beiden Verzeichnissen (ohne .git)
        local clawhub_files=()
        local git_files=()
        
        while IFS= read -r file; do
            local rel_path="${file#$clawhub_path/}"
            if [[ "$rel_path" != .git* ]]; then
                clawhub_files+=("$rel_path")
            fi
        done < <(find "$clawhub_path" -type f 2>/dev/null)
        
        while IFS= read -r file; do
            local rel_path="${file#$git_path/}"
            if [[ "$rel_path" != .git* ]]; then
                git_files+=("$rel_path")
            fi
        done < <(find "$git_path" -type f 2>/dev/null)
        
        # Vergleiche gemeinsame Dateien
        for rel_path in "${clawhub_files[@]}"; do
            for git_file in "${git_files[@]}"; do
                if [[ "$rel_path" == "$git_file" ]]; then
                    local clawhub_file="$clawhub_path/$rel_path"
                    local git_file_path="$git_path/$rel_path"
                    
                    if [[ "$(get_file_hash "$clawhub_file")" != "$(get_file_hash "$git_file_path")" ]]; then
                        local clawhub_mtime
                        local git_mtime
                        local newer
                        
                        clawhub_mtime=$(stat -c %Y "$clawhub_file" 2>/dev/null)
                        git_mtime=$(stat -c %Y "$git_file_path" 2>/dev/null)
                        
                        # Konvertiere Zeitstempel zu lesbarer Form
                        local clawhub_date
                        local git_date
                        clawhub_date=$(date -d @"$clawhub_mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
                        git_date=$(date -d @"$git_mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
                        
                        if [[ $clawhub_mtime -gt $git_mtime ]]; then
                            newer="clawhub"
                        else
                            newer="git"
                        fi
                        
                        skill_conflicts+=("$rel_path|$clawhub_date|$git_date|$newer")
                    fi
                    break
                fi
            done
        done
        
        if [[ ${#skill_conflicts[@]} -gt 0 ]]; then
            conflicts+=("$skill|${skill_conflicts[*]}")
        fi
    done
    
    # Ausgabe
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo "⚠️  KONFLIKTE GEFUNDEN:"
        echo "================================================================================"
        
        for conflict in "${conflicts[@]}"; do
            IFS='|' read -r skill rest <<< "$conflict"
            echo
            echo "📦 Skill: $skill"
            echo "----------------------------------------"
            
            IFS='*' read -ra file_conflicts <<< "$rest"
            for file_conflict in "${file_conflicts[@]}"; do
                IFS='|' read -r file clawhub_modified git_modified newer <<< "$file_conflict"
                echo "  📄 $file"
                echo "     ClawHub: $clawhub_modified"
                echo "     Git:     $git_modified"
                echo "     Neuer:   ${newer^^}"
                echo
            done
        done
        
        echo "================================================================================"
        echo "Gesamt: ${#conflicts[@]} Skills mit Konflikten"
        echo
        echo "Nutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen."
    else
        echo "✅ Keine Konflikte gefunden!"
        echo "Alle gemeinsamen Skills sind synchron."
    fi
}

main() {
    check_conflicts
}

main "$@"
