#!/usr/bin/env bash
# sync_status.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_status.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_status.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Sync Status - Zeigt Status aller Skills

readonly CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
readonly GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"
readonly STATE_FILE="/home/openclaw/.openclaw/workspace/db/sync_state.json"

# Funktion zur Berechnung des maximalen Mtime eines Verzeichnisses
get_max_mtime() {
    local dir="$1"
    find "$dir" -type f -not -path "*/.git/*" -exec stat -c %Y {} \; | sort -n | tail -1
}

# Prüft Status eines Skills
check_skill_status() {
    local skill_name="$1"
    local clawhub_path="${CLAWHUB_DIR}/${skill_name}"
    local git_path="${GIT_DIR}/${skill_name}"
    
    local in_clawhub=0
    local in_git=0
    local has_git_repo=0
    local status="unknown"
    local clawhub_mtime=""
    local git_mtime=""
    
    # Existenz prüfen
    [[ -d "$clawhub_path" ]] && in_clawhub=1
    [[ -d "$git_path" ]] && in_git=1
    
    # Git Repo prüfen
    if [[ $in_git -eq 1 && -d "${git_path}/.git" ]]; then
        has_git_repo=1
    fi
    
    # Status bestimmen
    if [[ $in_clawhub -eq 1 && $in_git -eq 0 ]]; then
        status="only_clawhub"
    elif [[ $in_clawhub -eq 0 && $in_git -eq 1 ]]; then
        status="only_git"
    elif [[ $in_clawhub -eq 1 && $in_git -eq 1 ]]; then
        # Timestamps vergleichen
        if [[ -n "$(find "$clawhub_path" -type f 2>/dev/null)" ]] && [[ -n "$(find "$git_path" -type f -not -path "*/.git/*" 2>/dev/null)" ]]; then
            clawhub_mtime=$(get_max_mtime "$clawhub_path" 2>/dev/null || echo "")
            git_mtime=$(get_max_mtime "$git_path" 2>/dev/null || echo "")
            
            if [[ -n "$clawhub_mtime" && -n "$git_mtime" ]]; then
                local diff
                diff=$((clawhub_mtime - git_mtime))
                # Betrag berechnen
                [[ $diff -lt 0 ]] && diff=$((diff * -1))
                
                if [[ $diff -lt 60 ]]; then
                    status="synced"
                elif [[ $clawhub_mtime -gt $git_mtime ]]; then
                    status="clawhub_newer"
                else
                    status="git_newer"
                fi
            else
                status="error"
            fi
        else
            status="error"
        fi
    fi
    
    # Ergebnis als JSON-ähnlicher String zurückgeben
    echo "{\"name\":\"$skill_name\",\"in_clawhub\":$in_clawhub,\"in_git\":$in_git,\"has_git_repo\":$has_git_repo,\"status\":\"$status\",\"last_modified\":{\"clawhub\":\"$clawhub_mtime\",\"git\":\"$git_mtime\"}}"
}

# Hauptfunktion
main() {
    echo "================================================================================"
    echo "ClawHub ↔ Git Sync Status"
    echo "================================================================================"
    echo "Zeitpunkt: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    # Alle Skills finden
    declare -A all_skills
    
    if [[ -d "$CLAWHUB_DIR" ]]; then
        while IFS= read -r dir; do
            [[ -n "$dir" ]] && all_skills["$dir"]=1
        done < <(find "$CLAWHUB_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" -printf "%f\n" 2>/dev/null || true)
    fi
    
    if [[ -d "$GIT_DIR" ]]; then
        while IFS= read -r dir; do
            [[ -n "$dir" ]] && all_skills["$dir"]=1
        done < <(find "$GIT_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" -printf "%f\n" 2>/dev/null || true)
    fi
    
    # Arrays für Status-Kategorien
    declare -a synced=()
    declare -a clawhub_newer=()
    declare -a git_newer=()
    declare -a only_clawhub=()
    declare -a only_git=()
    declare -a error=()
    
    # Status für jeden Skill prüfen
    for skill in "${!all_skills[@]}"; do
        status_json=$(check_skill_status "$skill")
        
        # Status auslesen (rudimentärer JSON-Parser)
        status=$(echo "$status_json" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
        
        case "$status" in
            synced) synced+=("$status_json") ;;
            clawhub_newer) clawhub_newer+=("$status_json") ;;
            git_newer) git_newer+=("$status_json") ;;
            only_clawhub) only_clawhub+=("$status_json") ;;
            only_git) only_git+=("$status_json") ;;
            error|*) error+=("$status_json") ;;
        esac
    done
    
    # Ausgabe
    echo "📊 Gesamt: ${#all_skills[@]} Skills"
    echo
    
    # Synchronisiert
    if [[ ${#synced[@]} -gt 0 ]]; then
        echo "✅ Synchronisiert (${#synced[@]})"
        for item in "${synced[@]}"; do
            name=$(echo "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
            echo "   - $name"
        done
        echo
    fi
    
    # ClawHub neuer
    if [[ ${#clawhub_newer[@]} -gt 0 ]]; then
        echo "🔄 ClawHub neuer (${#clawhub_newer[@]})"
        for item in "${clawhub_newer[@]}"; do
            name=$(echo "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
            mtime=$(echo "$item" | sed -n 's/.*"clawhub":"\([^"]*\)".*/\1/p')
            date_str=$(date -d "@$mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$mtime")
            echo "   - $name (ClawHub: $date_str)"
        done
        echo
    fi
    
    # Git neuer
    if [[ ${#git_newer[@]} -gt 0 ]]; then
        echo "🔄 Git neuer (${#git_newer[@]})"
        for item in "${git_newer[@]}"; do
            name=$(echo "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
            mtime=$(echo "$item" | sed -n 's/.*"git":"\([^"]*\)".*/\1/p')
            date_str=$(date -d "@$mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$mtime")
            echo "   - $name (Git: $date_str)"
        done
        echo
    fi
    
    # Nur in ClawHub
    if [[ ${#only_clawhub[@]} -gt 0 ]]; then
        echo "📦 Nur in ClawHub (${#only_clawhub[@]})"
        for item in "${only_clawhub[@]}"; do
            name=$(echo "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
            echo "   - $name"
        done
        echo
    fi
    
    # Nur in Git
    if [[ ${#only_git[@]} -gt 0 ]]; then
        echo "📁 Nur in Git (${#only_git[@]})"
        for item in "${only_git[@]}"; do
            name=$(echo "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
            echo "   - $name"
        done
        echo
    fi
    
    # Fehler
    if [[ ${#error[@]} -gt 0 ]]; then
        echo "❌ Fehler (${#error[@]})"
        for item in "${error[@]}"; do
            name=$(echo "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
            echo "   - $name"
        done
        echo
    fi
    
    # State-File Info
    if [[ -f "$STATE_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            last_run=$(jq -r 'if .last_sync | keys | length > 0 then .last_sync | keys | .[-1] else empty end' "$STATE_FILE" 2>/dev/null || echo "")
            if [[ -n "$last_run" ]]; then
                echo "📅 Letzter automatischer Sync: $last_run"
            fi
        else
            # Fallback ohne jq
            last_run=$(grep -o '"[0-9-T:.Z]*"' "$STATE_FILE" | tail -1 | tr -d '"' 2>/dev/null || echo "")
            if [[ -n "$last_run" ]]; then
                echo "📅 Letzter automatischer Sync: $last_run"
            fi
        fi
    fi
    
    echo "================================================================================"
}

main "$@"
