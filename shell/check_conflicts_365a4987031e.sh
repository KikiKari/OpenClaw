#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "b2ac7f2521837f1336ae1d7753a8b0e11e573de60d4002f1bfb6f3f782f34789", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "shell"}
# check_conflicts.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Check Conflicts - Erkennt Sync-Konflikte

CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"

# Funktion zur Berechnung des Hashes einer Datei
get_file_hash() {
    local file="$1"
    md5sum "$file" | cut -d' ' -f1
}

# Funktion zur Prüfung auf Konflikte zwischen ClawHub und Git
check_conflicts() {
    local conflicts=()
    local common_skills=()
    
    # Alle Skills finden, die in beiden Orten existieren
    if [[ -d "$CLAWHUB_DIR" && -d "$GIT_DIR" ]]; then
        local clawhub_skills=()
        local git_skills=()
        
        while IFS= read -r dir; do
            [[ -d "$dir" ]] && clawhub_skills+=("$(basename "$dir")")
        done < <(find "$CLAWHUB_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
        
        while IFS= read -r dir; do
            [[ -d "$dir" ]] && git_skills+=("$(basename "$dir")")
        done < <(find "$GIT_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
        
        # Gemeinsame Skills bestimmen
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
    
    for skill in "${common_skills[@]}"; do
        local clawhub_path="$CLAWHUB_DIR/$skill"
        local git_path="$GIT_DIR/$skill"
        
        # Alle Dateien sammeln
        declare -A clawhub_files=()
        declare -A git_files=()
        
        # ClawHub Dateien
        while IFS= read -r file; do
            local rel_path="${file#$clawhub_path/}"
            if [[ "$rel_path" != *.git/* ]]; then
                clawhub_files["$rel_path"]="$file"
            fi
        done < <(find "$clawhub_path" -type f 2>/dev/null)
        
        # Git Dateien
        while IFS= read -r file; do
            local rel_path="${file#$git_path/}"
            if [[ "$rel_path" != *.git/* ]]; then
                git_files["$rel_path"]="$file"
            fi
        done < <(find "$git_path" -type f 2>/dev/null)
        
        # Gemeinsame Dateien vergleichen
        local skill_conflicts=()
        for rel_path in "${!clawhub_files[@]}"; do
            if [[ -n "${git_files[$rel_path]+isset}" ]]; then
                local clawhub_file="${clawhub_files[$rel_path]}"
                local git_file="${git_files[$rel_path]}"
                
                if [[ "$(get_file_hash "$clawhub_file")" != "$(get_file_hash "$git_file")" ]]; then
                    local clawhub_mtime
                    local git_mtime
                    clawhub_mtime=$(stat -c %y "$clawhub_file" 2>/dev/null | cut -d'.' -f1)
                    git_mtime=$(stat -c %y "$git_file" 2>/dev/null | cut -d'.' -f1)
                    
                    local newer="git"
                    if [[ "$clawhub_mtime" > "$git_mtime" ]]; then
                        newer="clawhub"
                    fi
                    
                    skill_conflicts+=(
                        "file:$rel_path"
                        "clawhub_modified:$clawhub_mtime"
                        "git_modified:$git_mtime"
                        "newer:$newer"
                    )
                fi
            fi
        done
        
        if (( ${#skill_conflicts[@]} > 0 )); then
            conflicts+=("skill:$skill")
            conflicts+=("${skill_conflicts[@]}")
        fi
        
        # Arrays zurücksetzen
        unset clawhub_files
        unset git_files
    done
    
    # Ausgabe
    if (( ${#conflicts[@]} > 0 )); then
        echo "⚠️  KONFLIKTE GEFUNDEN:"
        echo "================================================================================"
        
        local current_skill=""
        local file_info=()
        for item in "${conflicts[@]}"; do
            if [[ "$item" == skill:* ]]; then
                if [[ -n "$current_skill" && ${#file_info[@]} -gt 0 ]]; then
                    echo
                    for info in "${file_info[@]}"; do
                        case "$info" in
                            file:*)
                                echo "  📄 ${info#file:}"
                                ;;
                            clawhub_modified:*)
                                echo "     ClawHub: ${info#clawhub_modified:}"
                                ;;
                            git_modified:*)
                                echo "     Git:     ${info#git_modified:}"
                                ;;
                            newer:*)
                                echo "     Neuer:   ${info#newer:}"
                                ;;
                        esac
                    done
                    file_info=()
                fi
                current_skill="${item#skill:}"
                echo
                echo "📦 Skill: $current_skill"
                echo "----------------------------------------"
            else
                file_info+=("$item")
            fi
        done
        
        # Letzten Skill ausgeben
        if [[ -n "$current_skill" && ${#file_info[@]} -gt 0 ]]; then
            echo
            for info in "${file_info[@]}"; do
                case "$info" in
                    file:*)
                        echo "  📄 ${info#file:}"
                        ;;
                    clawhub_modified:*)
                        echo "     ClawHub: ${info#clawhub_modified:}"
                        ;;
                    git_modified:*)
                        echo "     Git:     ${info#git_modified:}"
                        ;;
                    newer:*)
                        echo "     Neuer:   ${info#newer:}"
                        ;;
                esac
            done
        fi
        
        echo
        echo "================================================================================"
        # Anzahl der konfliktbehafteten Skills zählen
        local conflict_count=0
        for item in "${conflicts[@]}"; do
            [[ "$item" == skill:* ]] && ((conflict_count++))
        done
        echo "Gesamt: $conflict_count Skills mit Konflikten"
        echo
        echo "Nutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen."
    else
        echo "✅ Keine Konflikte gefunden!"
        echo "Alle gemeinsamen Skills sind synchron."
    fi
}

# Hauptfunktion
main() {
    check_conflicts
}

main "$@"
