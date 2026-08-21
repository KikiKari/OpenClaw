#!/bin/bash
# sync_agent_cron.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync

# Konfiguration
CLAWHUB_DIR="/home/openclaw/.openclaw/workspace/skills"
GIT_DIR="/home/openclaw/.openclaw/workspace/git/skills"
LOG_FILE="/home/openclaw/.openclaw/workspace/logs/sync-agent.log"
STATE_FILE="/home/openclaw/.openclaw/workspace/db/sync_state.json"

# Hilfsfunktionen
file_mtime() {
    local path="$1"
    find "$path" -type f ! -path "*/.git/*" -exec stat -c %Y {} \; 2>/dev/null | sort -n | tail -1 || echo "0"
}

write_to_log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[${timestamp}] [${level}] ${message}"
    echo "$entry"
    echo "$entry" >> "$LOG_FILE"
}

# Überschreibe Log-Funktion (Simulation)
log() {
    write_to_log "$@"
}

validate_skill() {
    local skill_path="$1"
    # Prüfe ob Skill-Verzeichnis gültig ist
    [[ -d "$skill_path" ]] && [[ -f "$skill_path/skill.json" ]]
}

sync_to_git() {
    local skill_name="$1"
    local source_dir="${CLAWHUB_DIR}/${skill_name}"
    local target_dir="${GIT_DIR}/${skill_name}"
    
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi
    
    rsync -a --delete "$source_dir/" "$target_dir/" 2>/dev/null
    return $?
}

sync_to_clawhub() {
    local skill_name="$1"
    local source_dir="${GIT_DIR}/${skill_name}"
    local target_dir="${CLAWHUB_DIR}/${skill_name}"
    
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi
    
    rsync -a --delete "$source_dir/" "$target_dir/" 2>/dev/null
    return $?
}

# Hauptprogramm
main() {
    # Initialisierung
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$STATE_FILE")"
    
    write_to_log "======================================================================"
    write_to_log "CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF"
    write_to_log "Zeitstempel: $(date --iso-8601=seconds)"
    write_to_log "======================================================================"
    
    # Skills auflisten
    mapfile -t clawhub_skills < <(find "$CLAWHUB_DIR" -maxdepth 1 -type d -not -name ".*" -exec basename {} \; | sort)
    mapfile -t git_skills < <(find "$GIT_DIR" -maxdepth 1 -type d -not -name ".*" -exec basename {} \; | sort)
    
    # Arrays für Änderungen initialisieren
    declare -a new_in_clawhub=()
    declare -a new_in_git=()
    declare -a clawhub_newer=()
    declare -a git_newer=()
    declare -a synced=()
    
    # DRY-RUN: Änderungen analysieren
    write_to_log ""
    write_to_log "[DRY-RUN] Analysiere Änderungen..."
    
    # Neue Skills finden
    for skill in "${clawhub_skills[@]}"; do
        if ! printf '%s\n' "${git_skills[@]}" | grep -q "^${skill}$"; then
            new_in_clawhub+=("$skill")
        fi
    done
    
    for skill in "${git_skills[@]}"; do
        if ! printf '%s\n' "${clawhub_skills[@]}" | grep -q "^${skill}$"; then
            new_in_git+=("$skill")
        fi
    done
    
    # Existierende Skills vergleichen
    for skill in "${clawhub_skills[@]}"; do
        if printf '%s\n' "${git_skills[@]}" | grep -q "^${skill}$"; then
            c_mtime=$(file_mtime "${CLAWHUB_DIR}/${skill}")
            g_mtime=$(file_mtime "${GIT_DIR}/${skill}")
            
            # Zeitdifferenz berechnen
            diff=$((c_mtime - g_mtime))
            abs_diff=${diff#-}
            
            if [[ $abs_diff -gt 60 ]]; then
                if [[ $diff -gt 0 ]]; then
                    clawhub_newer+=("${skill}:${diff}")
                else
                    git_newer+=("${skill}:${abs_diff}")
                fi
            else
                synced+=("$skill")
            fi
        fi
    done
    
    # Report erstellen
    write_to_log "Neu in ClawHub: ${#new_in_clawhub[@]}"
    write_to_log "Neu in Git: ${#new_in_git[@]}"
    write_to_log "ClawHub neuer: ${#clawhub_newer[@]}"
    write_to_log "Git neuer: ${#git_newer[@]}"
    write_to_log "Synchron: ${#synced[@]}"
    
    local total_changes=$(( ${#new_in_clawhub[@]} + ${#new_in_git[@]} + ${#clawhub_newer[@]} + ${#git_newer[@]} ))
    
    if [[ $total_changes -eq 0 ]]; then
        write_to_log ""
        write_to_log "✅ Keine Änderungen erkannt. Sync nicht nötig."
        write_to_log "======================================================================"
        exit 0
    fi
    
    write_to_log ""
    write_to_log "🔄 ${total_changes} Änderungen erkannt - starte Synchronisation..."
    
    # Ergebnisarrays initialisieren
    declare -a synced_to_git=()
    declare -a synced_to_clawhub=()
    declare -a up_to_date=()
    declare -a errors=()
    
    # 1. NEU in ClawHub → zu Git
    for skill in "${new_in_clawhub[@]}"; do
        if validate_skill "${CLAWHUB_DIR}/${skill}"; then
            write_to_log "→ Synchronisiere ${skill} zu Git..."
            if sync_to_git "$skill"; then
                (
                    cd "${GIT_DIR}/${skill}"
                    git init -q 2>/dev/null || true
                    git add . -f 2>/dev/null || true
                    git commit -m "Initial: ${skill}" -q 2>/dev/null || true
                )
                synced_to_git+=("$skill")
                write_to_log "  ✓ ${skill} synchronisiert"
            else
                errors+=("${skill}")
                write_to_log "  ✗ ERROR: ${skill} - Sync fehlgeschlagen" "ERROR"
            fi
        else
            errors+=("${skill} (invalid)")
            write_to_log "  ✗ ERROR: ${skill} - Invalid skill" "ERROR"
        fi
    done
    
    # 2. NEU in Git → zu ClawHub
    for skill in "${new_in_git[@]}"; do
        if validate_skill "${GIT_DIR}/${skill}"; then
            write_to_log "→ Synchronisiere ${skill} zu ClawHub..."
            if sync_to_clawhub "$skill"; then
                synced_to_clawhub+=("$skill")
                write_to_log "  ✓ ${skill} synchronisiert"
            else
                errors+=("${skill}")
                write_to_log "  ✗ ERROR: ${skill} - Sync fehlgeschlagen" "ERROR"
            fi
        else
            errors+=("${skill} (invalid)")
            write_to_log "  ✗ ERROR: ${skill} - Invalid skill" "ERROR"
        fi
    done
    
    # 3. Updates von ClawHub nach Git
    for item in "${clawhub_newer[@]}"; do
        IFS=':' read -r skill diff <<< "$item"
        write_to_log "→ Update ${skill} (ClawHub +${diff}s neuer)..."
        if sync_to_git "$skill"; then
            (
                cd "${GIT_DIR}/${skill}"
                git add . -f 2>/dev/null || true
                dt=$(date '+%Y-%m-%d %H:%M')
                git commit -m "Sync from ClawHub: ${dt}" -q 2>/dev/null || true
            )
            synced_to_git+=("$skill")
            write_to_log "  ✓ ${skill} aktualisiert"
        else
            errors+=("${skill}")
            write_to_log "  ✗ ERROR: ${skill} - Sync fehlgeschlagen" "ERROR"
        fi
    done
    
    # 4. Updates von Git nach ClawHub
    for item in "${git_newer[@]}"; do
        IFS=':' read -r skill diff <<< "$item"
        write_to_log "→ Update ${skill} (Git +${diff}s neuer)..."
        if sync_to_clawhub "$skill"; then
            synced_to_clawhub+=("$skill")
            write_to_log "  ✓ ${skill} aktualisiert"
        else
            errors+=("${skill}")
            write_to_log "  ✗ ERROR: ${skill} - Sync fehlgeschlagen" "ERROR"
        fi
    done
    
    up_to_date=("${synced[@]}")
    
    # Zusammenfassung
    write_to_log ""
    write_to_log "======================================================================"
    write_to_log "SYNCHRONISATION ABGESCHLOSSEN"
    write_to_log "======================================================================"
    write_to_log "Zu Git synchronisiert:     ${#synced_to_git[@]}"
    write_to_log "Zu ClawHub synchronisiert: ${#synced_to_clawhub[@]}"
    write_to_log "Bereits aktuell:           ${#up_to_date[@]}"
    write_to_log "Fehler:                    ${#errors[@]}"
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        error_list=$(printf '%s, ' "${errors[@]}")
        error_list=${error_list%, }
        write_to_log "  Fehlerhafte: ${error_list}"
    fi
    
    write_to_log "======================================================================"
    
    # State speichern
    {
        echo "{"
        echo "  \"last_run\": \"$(date --iso-8601=seconds)\","
        echo "  \"results\": {"
        echo "    \"synced_to_git\": [$(printf '\"%s\", ' "${synced_to_git[@]}" | sed 's/, $//')],"
        echo "    \"synced_to_clawhub\": [$(printf '\"%s\", ' "${synced_to_clawhub[@]}" | sed 's/, $//')],"
        echo "    \"up_to_date\": [$(printf '\"%s\", ' "${up_to_date[@]}" | sed 's/, $//')],"
        echo "    \"errors\": [$(printf '\"%s\", ' "${errors[@]}" | sed 's/, $//')]"
        echo "  },"
        echo "  \"changes_detected\": {"
        echo "    \"new_in_clawhub\": ${#new_in_clawhub[@]},"
        echo "    \"new_in_git\": ${#new_in_git[@]},"
        echo "    \"clawhub_newer\": ${#clawhub_newer[@]},"
        echo "    \"git_newer\": ${#git_newer[@]},"
        echo "    \"synced\": ${#synced[@]}"
        echo "  }"
        echo "}"
    } > "$STATE_FILE"
    
    write_to_log "State gespeichert: $STATE_FILE"
}

# Skript ausführen
main "$@"
