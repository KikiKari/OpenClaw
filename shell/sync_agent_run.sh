#!/usr/bin/env bash
# sync_agent_run.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# ClawHub ↔ Git Sync Agent - Produktionslauf

SCRIPTS_DIR="/home/openclaw/.openclaw/workspace/scripts"
CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"
STATE_FILE="/home/openclaw/.openclaw/workspace/db/sync_state.json"

# Lade Hilfsfunktionen
source "$SCRIPTS_DIR/sync_clawhub_git.sh"

# Funktion zur Bestimmung der neuesten Dateiänderung in einem Verzeichnis
file_mtime() {
    local path="$1"
    local latest=0
    local file_time

    while IFS= read -r -d '' file; do
        if [[ "$file" != *".git"* ]]; then
            file_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
            if (( file_time > latest )); then
                latest=$file_time
            fi
        fi
    done < <(find "$path" -type f -print0 2>/dev/null || true)

    echo "$latest"
}

# Logging-Funktion
log() {
    echo "$1"
}

# Hauptlogging
log "======================================================================"
log "CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF"
log "Zeitstempel: $(date --iso-8601=seconds)"
log "======================================================================"

# Hole Skill-Verzeichnisse
mapfile -t clawhub_skills < <(find "$CLAWHUB_DIR" -maxdepth 1 -type d -not -name ".*" -exec basename {} \; 2>/dev/null || true)
mapfile -t git_skills < <(find "$GIT_DIR" -maxdepth 1 -type d -not -name ".*" -exec basename {} \; 2>/dev/null || true)

# Initialisiere Ergebnisarrays
synced_to_git=()
synced_to_clawhub=()
up_to_date=()
errors=()

# 1. NEU in ClawHub → zu Git syncen
log ""
log "[PHASE 1] ClawHub → Git Synchronisation"
log "----------------------------------------"

declare -A git_skill_map
for skill in "${git_skills[@]}"; do
    git_skill_map["$skill"]=1
done

new_in_clawhub=()
for skill in "${clawhub_skills[@]}"; do
    if [[ -z "${git_skill_map[$skill]:-}" ]]; then
        new_in_clawhub+=("$skill")
    fi
done

IFS=$'\n' new_in_clawhub_sorted=($(sort <<<"${new_in_clawhub[*]}"))
unset IFS

for skill in "${new_in_clawhub_sorted[@]}"; do
    if validate_skill "$CLAWHUB_DIR/$skill"; then
        log "→ Synchronisiere $skill zu Git..."
        if sync_to_git "$skill" "false"; then
            git_path="$GIT_DIR/$skill"
            cd "$git_path" || { errors+=("$skill (cd failed)"); continue; }
            git init -q 2>/dev/null || true
            git add . -f 2>/dev/null || true
            dt=$(date "+%Y-%m-%d %H:%M")
            git commit -m "Initial: $skill" -q 2>/dev/null || true
            synced_to_git+=("$skill")
            log "  ✓ $skill synchronisiert & Git initialisiert"
        else
            errors+=("$skill (sync failed)")
        fi
    else
        errors+=("$skill (invalid)")
    fi
done

# 2. In beiden - prüfe Änderungen
log ""
log "[PHASE 2] Prüfe existierende Skills auf Änderungen"
log "----------------------------------------"

declare -A clawhub_skill_map
for skill in "${clawhub_skills[@]}"; do
    clawhub_skill_map["$skill"]=1
done

in_both=()
for skill in "${git_skills[@]}"; do
    if [[ -n "${clawhub_skill_map[$skill]:-}" ]]; then
        in_both+=("$skill")
    fi
done

IFS=$'\n' in_both_sorted=($(sort <<<"${in_both[*]}"))
unset IFS

for skill in "${in_both_sorted[@]}"; do
    c_mtime=$(file_mtime "$CLAWHUB_DIR/$skill")
    g_mtime=$(file_mtime "$GIT_DIR/$skill")
    diff=$((c_mtime - g_mtime))

    if (( diff > 60 || diff < -60 )); then
        if (( diff > 0 )); then
            log "→ $skill: ClawHub neuer (+${diff}s) → sync zu Git"
            if sync_to_git "$skill" "false"; then
                git_path="$GIT_DIR/$skill"
                cd "$git_path" || { errors+=("$skill (cd failed)"); continue; }
                git add . -f 2>/dev/null || true
                dt=$(date "+%Y-%m-%d %H:%M")
                git commit -m "Sync from ClawHub: $dt" -q 2>/dev/null || true
                synced_to_git+=("$skill")
            else
                errors+=("$skill (update failed)")
            fi
        else
            log "→ $skill: Git neuer (+$(( -diff ))s) → sync zu ClawHub"
            if sync_to_clawhub "$skill" "false"; then
                synced_to_clawhub+=("$skill")
            else
                errors+=("$skill (update failed)")
            fi
        fi
    else
        up_to_date+=("$skill")
    fi
done

# ZUSAMMENFASSUNG
log ""
log "======================================================================"
log "SYNCHRONISATION ABGESCHLOSSEN"
log "======================================================================"
log "Zu Git synchronisiert:     ${#synced_to_git[@]}"
if (( ${#synced_to_git[@]} > 0 )); then
    log "  $(IFS=', '; echo "${synced_to_git[*]}")"
fi
log "Zu ClawHub synchronisiert: ${#synced_to_clawhub[@]}"
if (( ${#synced_to_clawhub[@]} > 0 )); then
    log "  $(IFS=', '; echo "${synced_to_clawhub[*]}")"
fi
log "Bereits aktuell:           ${#up_to_date[@]}"
log "Fehler:                    ${#errors[@]}"
if (( ${#errors[@]} > 0 )); then
    log "  $(IFS=', '; echo "${errors[*]}")"
fi
log "======================================================================"

# Speichere State
mkdir -p "$(dirname "$STATE_FILE")"

# Erstelle JSON-ähnlichen State-String
{
    echo "{"
    echo "  \"last_run\": \"$(date --iso-8601=seconds)\","
    echo "  \"results\": {"
    echo "    \"synced_to_git\": [$(printf '"%s",' "${synced_to_git[@]}" | sed 's/,$//')],"
    echo "    \"synced_to_clawhub\": [$(printf '"%s",' "${synced_to_clawhub[@]}" | sed 's/,$//')],"
    echo "    \"up_to_date\": [$(printf '"%s",' "${up_to_date[@]}" | sed 's/,$//')],"
    echo "    \"errors\": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')]"
    echo "  }"
    echo "}"
} > "$STATE_FILE"

log "State gespeichert: $STATE_FILE"
