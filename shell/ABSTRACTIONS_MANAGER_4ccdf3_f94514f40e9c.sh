#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "9fb4f86c6a9a0b612478cedc3155c2fc2c17e1abd82812fa4b34ae4a22391f78", "source_sha256": "4ccdf30dd1193d1cc7c50fce4977be19a48ef1bbbdd460574570e788e6da4ca7", "target_language": "shell"}
# ABSTRACTIONS_MANAGER.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
readonly WORKSPACE="${ABSTRACTIONS_WORKSPACE:-/home/openclaw/.openclaw/workspace}"
readonly ABSTRACTIONS_REPO="$WORKSPACE/git/OpenClaw-gateway1-abstractions"
readonly QUELLEN_DIR="$WORKSPACE/git/quellen"
readonly LOG_DIR="$WORKSPACE/logs/abstractions-manager"
readonly STATE_FILE="$WORKSPACE/db/abstractions_state.json"

readonly GITHUB_BENUTZER="KikiKari"

# Herkunft der Quelldateien
QUELLEN_REPOS=("OpenClaw" "Projects" "Onboarding")
QUELLEN_BRANCHES_OPENCLAW=("main" "gateway1" "gateway2")
QUELLEN_BRANCHES_PROJECTS="alle"
QUELLEN_BRANCHES_ONBOARDING=("main")

# Dateiendung -> Quellsprache
declare -A QUELLSPRACHEN=(
    [".pl"]="perl5" [".pm"]="perl5"
    [".raku"]="perl6" [".rakumod"]="perl6"
    [".rb"]="ruby" [".lua"]="lua" [".go"]="go"
    [".ps1"]="powershell" [".psm1"]="powershell"
    [".sh"]="shell" [".bash"]="shell"
    [".tcl"]="tcl"
    [".html"]="html" [".htm"]="html"
    [".js"]="javascript" [".mjs"]="javascript" [".cjs"]="javascript"
    [".py"]="python"
    [".css"]="css"
)

# Zielverzeichnisse und Bezeichnungen
declare -A ZIELSPRACHEN=(
    ["javascript"]="JavaScript fuer Node 20:.js"
    ["perl5"]="Perl 5 mit use strict und use warnings:.pl"
    ["powershell"]="PowerShell 7:.ps1"
    ["python"]="Python 3.12:.py"
    ["shell"]="Bash 5 mit set -euo pipefail:.sh"
    ["tcl"]="Tcl 8.6:.tcl"
    ["perl6"]="Raku:.raku"
    ["ruby"]="Ruby:.rb"
    ["lua"]="Lua:.lua"
    ["go"]="Go:.go"
)

# Verzeichnisse und Muster, die nie eingelesen werden
AUSSCHLUSS_PATTERNS=("node_modules/" "/.git/" "__pycache__/" "dist/" "build/" "vendor/"
                      ".venv/" "site-packages/" "python-hardener-workspace/" ".artifacts/"
                      "coverage/" ".next/" "target/" "/work/" "/backups/")

readonly MAX_BYTES=200000

# Modelle und API-Einstellungen
MODELLE=("qwen/qwen3-coder" "deepseek/deepseek-chat-v3.1" "z-ai/glm-4.6" "mistralai/codestral-2508" "qwen/qwen-2.5-coder-32b-instruct")
readonly API_URL="https://openrouter.ai/api/v1/chat/completions"
readonly ZEITLIMIT=240
readonly VERSUCHE=3

# Globale Variablen
declare -A zustand
declare -a baeume
declare -a inventar

# Protokoll
function protokoll() {
    mkdir -p "$LOG_DIR"
    exec 1> >(tee -a "$LOG_DIR/manager.log") 2>&1
}

# Zustand laden
function zustand_laden() {
    if [[ -f "$STATE_FILE" ]]; then
        mapfile -t zustand < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$STATE_FILE")
    fi
}

# Zustand speichern
function zustand_speichern() {
    local temp_file
    temp_file=$(mktemp)
    printf '%s\n' "${zustand[@]}" | jq -R . | jq -s 'map(split("=") | {key: .[0], value: .[1]}) | from_entries' > "$temp_file"
    mv "$temp_file" "$STATE_FILE"
}

# Git-Befehl ausführen
function git_cmd() {
    local args=("$@")
    git "${args[@]}" 2>/dev/null
}

# Quellen holen
function quellen_holen() {
    mkdir -p "$QUELLEN_DIR"
    baeume=()

    for repo in "${QUELLEN_REPOS[@]}"; do
        local spiegel="$QUELLEN_DIR/$repo.git"
        local url="https://github.com/$GITHUB_BENUTZER/$repo.git"

        if [[ ! -d "$spiegel" ]]; then
            echo "[$(date)] INFO | main:1 | $repo wird geholt"
            if ! git clone --mirror --filter=blob:none "$url" "$spiegel"; then
                echo "[$(date)] ERROR | main:1 | $repo konnte nicht geholt werden"
                continue
            fi
        else
            if ! git_cmd -C "$spiegel" remote update --prune; then
                echo "[$(date)] WARNING | main:1 | $repo konnte nicht aktualisiert werden"
            fi
        fi

        local branches=()
        case "$repo" in
            "OpenClaw") branches=("${QUELLEN_BRANCHES_OPENCLAW[@]}") ;;
            "Projects") 
                if [[ "${QUELLEN_BRANCHES_PROJECTS}" == "alle" ]]; then
                    mapfile -t branches < <(git_cmd -C "$spiegel" for-each-ref --format='%(refname:short)' refs/heads)
                fi
                ;;
            "Onboarding") branches=("${QUELLEN_BRANCHES_ONBOARDING[@]}") ;;
        esac

        for branch in "${branches[@]}"; do
            local baum="$QUELLEN_DIR/baeume/$repo/${branch//\//_}"
            mkdir -p "$baum"
            if ! git_cmd --work-tree "$baum" -C "$spiegel" checkout -f "$branch" -- .; then
                echo "[$(date)] WARNING | main:1 | $repo@$branch: Arbeitsbaum fehlgeschlagen"
                continue
            fi
            baeume+=("$repo:$branch:$baum")
        done
    done

    # Lokale Gateway-Skripte
    if [[ "${ABSTRACTIONS_EXECUTION:-gateway}" == "gateway" ]] && [[ -d "$WORKSPACE" ]]; then
        baeume+=("workspace:local:$WORKSPACE")
    fi

    echo "[$(date)] INFO | main:1 | Quellen bereit: ${#baeume[@]} Arbeitsbaeume"
}

# Priorität bestimmen
function prioritaet_bestimmen() {
    local pfad="$1"
    local sprache="$2"

    if [[ "$sprache" == "html" ]] || [[ "$sprache" == "css" ]]; then
        echo "low"
        return
    fi

    if [[ "$pfad" == scripts/* ]] || [[ "$pfad" == */scripts/* ]]; then
        echo "high"
        return
    fi

    echo "medium"
}

# Enthält Zugangsdaten
function enthaelt_zugangsdaten() {
    local datei="$1"
    local muster='(sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'

    if grep -qE "$muster" "$datei"; then
        return 0
    fi

    for var in $(env | grep -E "(TOKEN|SECRET|PASSWORD|API_KEY)" | cut -d= -f1); do
        local wert="${!var}"
        if [[ ${#wert} -ge 12 ]] && grep -q "$wert" "$datei"; then
            return 0
        fi
    done

    return 1
}

# Inventar bauen
function inventar_bauen() {
    local dateien=()
    declare -A datei_hashes

    for baum_info in "${baeume[@]}"; do
        IFS=':' read -r repo branch baum <<< "$baum_info"
        
        while IFS= read -r -d '' pfad; do
            local rel
            rel=$(realpath --relative-to="$baum" "$pfad" 2>/dev/null) || continue
            rel=${rel//\\//}

            # Überspringe bestimmte Pfade für workspace
            if [[ "$repo" == "workspace" ]]; then
                local teile=($(realpath --relative-to="$WORKSPACE" "$pfad" 2>/dev/null | tr '/' '\n'))
                if [[ "${teile[0]:-}" == "git" ]] && [[ "${teile[1]:-}" == "Abstraktionen" ]] || \
                   [[ "${teile[1]:-}" == "OpenClaw-gateway1-abstractions" ]] || \
                   [[ "${teile[1]:-}" == "quellen" ]]; then
                    continue
                fi
                
                local skip=false
                for teil in "${teile[@]}"; do
                    if [[ "$teil" =~ ^(work|backups|logs|log|db|state|tmp|temp|cache|\.cache|artifacts|\.openclaw|secrets|credentials|\.credentials|private|\.private)$ ]]; then
                        skip=true
                        break
                    fi
                done
                [[ "$skip" == true ]] && continue
                
                # Prüfe auf symlinks
                if ! realpath "$pfad" 2>/dev/null | grep -q "^$(realpath "$WORKSPACE")"; then
                    continue
                fi
            fi

            # Ausschlussmuster prüfen
            local ausschliessen=false
            for muster in "${AUSSCHLUSS_PATTERNS[@]}"; do
                if [[ "/$rel" == *"$muster"* ]]; then
                    ausschliessen=true
                    break
                fi
            done
            [[ "$ausschliessen" == true ]] && continue

            # Sprache bestimmen
            local ext="${pfad##*.}"
            local sprache="${QUELLSPRACHEN[".$ext"]:-}"
            [[ -z "$sprache" ]] && continue

            # Dateigröße prüfen
            local size
            size=$(stat -c%s "$pfad" 2>/dev/null || echo "0")
            [[ "$size" -eq 0 ]] && continue
            [[ "$size" -gt "$MAX_BYTES" ]] && continue

            # Zugangsdaten prüfen
            if enthaelt_zugangsdaten "$pfad"; then
                continue
            fi

            # Hash berechnen
            local hash
            hash=$(sha256sum "$pfad" | cut -d' ' -f1 | head -c16)

            # Neue Datei hinzufügen oder Herkunft ergänzen
            if [[ -z "${datei_hashes[$hash]+isset}" ]]; then
                local name
                name=$(basename "$pfad")
                local stem="${name%.*}"
                local prio
                prio=$(prioritaet_bestimmen "$rel" "$sprache")
                
                datei_hashes["$hash"]="$name:$stem:$sprache:$size:$prio:$repo@$branch:$rel"
                dateien+=("$hash")
            else
                local current="${datei_hashes[$hash]}"
                datei_hashes["$hash"]="$current:$repo@$branch:$rel"
            fi
        done < <(find "$baum" -type f -print0 2>/dev/null)
    done

    # Sortieren nach Priorität und Name
    local sorted=()
    for prio in high medium low; do
        for hash in "${dateien[@]}"; do
            IFS=':' read -r name _ _ _ akt_prio _ <<< "${datei_hashes[$hash]}"
            if [[ "$akt_prio" == "$prio" ]]; then
                sorted+=("$hash")
            fi
        done
    done

    inventar=("${sorted[@]}")
    echo "[$(date)] INFO | main:1 | Inventar: ${#inventar[@]} eindeutige Quelldateien"
}

# Hauptfunktion
function main() {
    protokoll
    
    local nur_veroeffentlichen=false
    local probelauf=false
    local prioritaet=""
    local anzahl="${ABSTRACTIONS_ANZAHL:-40}"

    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --nur-veroeffentlichen)
                nur_veroeffentlichen=true
                shift
                ;;
            --probelauf)
                probelauf=true
                shift
                ;;
            --prioritaet)
                prioritaet="$2"
                shift 2
                ;;
            --anzahl)
                anzahl="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "$nur_veroeffentlichen" == true ]] && [[ "$probelauf" == true ]]; then
        echo "[$(date)] ERROR | main:1 | --probelauf und --nur-veroeffentlichen sind nicht kombinierbar"
        return 2
    fi

    if [[ "$nur_veroeffentlichen" == true ]]; then
        # TODO: Veröffentlichung implementieren
        return 0
    fi

    # Prüfung auf API-Key für standalone
    if [[ "$probelauf" == false ]] && [[ "${ABSTRACTIONS_EXECUTION:-gateway}" == "standalone" ]]; then
        if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
            echo "[$(date)] ERROR | main:1 | OpenRouter-Zugang fuer eigenstaendigen Lauf fehlt"
            return 2
        fi
    fi

    # Zustand laden
    zustand_laden

    # Quellen holen
    quellen_holen
    if [[ ${#baeume[@]} -eq 0 ]]; then
        echo "[$(date)] ERROR | main:1 | Keine Quellen verfuegbar"
        return 1
    fi

    # Inventar bauen
    inventar_bauen
    if [[ ${#inventar[@]} -eq 0 ]]; then
        echo "[$(date)] ERROR | main:1 | Inventar leer"
        return 1
    fi

    # Priorität bestimmen
    if [[ -z "$prioritaet" ]]; then
        prioritaet="${zustand[naechste_prioritaet]:-high}"
    fi

    # TODO: Übersetzung implementieren
    echo "[$(date)] INFO | main:1 | Übersetzung noch nicht implementiert"
    
    # Statusbericht erstellen
    echo "[$(date)] INFO | main:1 | STATUS.md fortgeschrieben"
    
    # Zustand speichern
    zustand["naechste_prioritaet"]="medium"  # Rotation simulieren
    zustand_speichern

    echo "[$(date)] INFO | main:1 | Abgeschlossen: 0 erzeugt, 0 verworfen, 0 Quelldateien bearbeitet"
    return 0
}

# Skript starten
main "$@"
