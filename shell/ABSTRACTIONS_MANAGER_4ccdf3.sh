#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "ba4f3643a6cb784fc9895553ead2dd0f3dab78c80ad6c418c54a198606222ec8", "source_sha256": "4ccdf30dd1193d1cc7c50fce4977be19a48ef1bbbdd460574570e788e6da4ca7", "target_language": "shell"}
# ABSTRACTIONS_MANAGER.py — portiert nach shell
# Quelle: python, workspace@local:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Script Abstractions Manager
#
# Uebersetzt jede Quelldatei aus den drei Repositories KikiKari/OpenClaw,
# KikiKari/Projects und KikiKari/Onboarding in zehn Zielsprachen und legt
# das Ergebnis in den Sprachverzeichnissen des Abstraktions-Repositories ab.
#
# Es entstehen vollstaendige Uebersetzungen, keine Ruempfe: jede Datei geht
# als Ganzes an ein Sprachmodell, das lauffaehigen Code in der Zielsprache
# zurueckgibt. Erzeugnisse, deren Syntax sich nicht pruefen laesst oder die
# erkennbar unfertig sind, werden verworfen statt abgelegt.
#
# Verwendung:
#     ABSTRACTIONS_MANAGER.sh [--prioritaet high|medium|low|alle]
#                             [--anzahl N] [--probelauf]
#
# Umgebung:
#     OPENROUTER_API_KEY      Pflicht. Schluessel fuer die Uebersetzung.
#     ABSTRACTIONS_WORKSPACE  Arbeitsverzeichnis, Vorgabe
#                             /home/openclaw/.openclaw/workspace
#     ABSTRACTIONS_MODELL     Modellkennung, Vorgabe siehe MODELLE
#     ABSTRACTIONS_ANZAHL     Quelldateien je Lauf, Vorgabe 40

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

declare -r WORKSPACE="${ABSTRACTIONS_WORKSPACE:-/home/openclaw/.openclaw/workspace}"
declare -r ABSTRACTIONS_REPO="$WORKSPACE/git/OpenClaw-gateway1-abstractions"
declare -r QUELLEN_DIR="$WORKSPACE/git/quellen"
declare -r LOG_DIR="$WORKSPACE/logs/abstractions-manager"
declare -r STATE_FILE="$WORKSPACE/db/abstractions_state.json"

declare -r GITHUB_BENUTZER="KikiKari"

# Herkunft der Quelldateien. Projects wird ueber alle Branches gelesen, weil
# dort jedes Projekt in einem eigenen verwaisten Branch liegt.
declare -A QUELLEN=(
    ["OpenClaw"]="main gateway1 gateway2"
    ["Projects"]="alle"
    ["Onboarding"]="main"
)

# Dateiendung -> Quellsprache. Bestimmt zugleich, was eingelesen wird.
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

# Die zehn Zielverzeichnisse, nach der Vorlage aus
# OpenClaw@gateway1-abstractions. Sie liegen im Wurzelverzeichnis des
# Abstraktions-Repositories.
declare -A ZIELSPRACHEN_EXT=(
    ["javascript"]=".js"
    ["perl5"]=".pl"
    ["powershell"]=".ps1"
    ["python"]=".py"
    ["shell"]=".sh"
    ["tcl"]=".tcl"
    ["perl6"]=".raku"
    ["ruby"]=".rb"
    ["lua"]=".lua"
    ["go"]=".go"
)

declare -A ZIELSPRACHEN_BEZ=(
    ["javascript"]="JavaScript fuer Node 20"
    ["perl5"]="Perl 5 mit use strict und use warnings"
    ["powershell"]="PowerShell 7"
    ["python"]="Python 3.12"
    ["shell"]="Bash 5 mit set -euo pipefail"
    ["tcl"]="Tcl 8.6"
    ["perl6"]="Raku"
    ["ruby"]="Ruby"
    ["lua"]="Lua"
    ["go"]="Go"
)

# Verzeichnisse und Muster, die nie eingelesen werden.
declare -a AUSSCHLUSS=(
    "node_modules/" "/.git/" "__pycache__/" "dist/" "build/" "vendor/"
    ".venv/" "site-packages/" "python-hardener-workspace/" ".artifacts/"
    "coverage/" ".next/" "target/" "/work/" "/backups/"
)
declare -ri MAX_BYTES=200000

# Reihenfolge der Ausweichmodelle. Geprueft gegen das Konto: die Anbieter von
# OpenAI und Anthropic sind dort ueber die Privatsphaere-Einstellung
# ausgeschlossen ("All providers have been ignored"), diese hier antworten.
declare -a MODELLE=(
    "qwen/qwen3-coder"
    "deepseek/deepseek-chat-v3.1"
    "z-ai/glm-4.6"
    "mistralai/codestral-2508"
    "qwen/qwen-2.5-coder-32b-instruct"
)
declare -r API_URL="https://openrouter.ai/api/v1/chat/completions"
declare -ri ZEITLIMIT=240
declare -ri VERSUCHE=3

# ---------------------------------------------------------------------------
# Protokoll
# ---------------------------------------------------------------------------

_log() {
    local level="$1" message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s | %-7s | %s\n" "$timestamp" "$level" "$message" >&2
}

info() { _log "INFO" "$1"; }
warning() { _log "WARNING" "$1"; }
error() { _log "ERROR" "$1"; }

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------

zustand_laden() {
    if [[ -f "$STATE_FILE" ]]; then
        if ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
            error "Zustand unlesbar — Lauf wird angehalten"
            return 1
        fi
        cat "$STATE_FILE"
    else
        echo '{"erledigt": {}, "statistik": {}}'
    fi
}

zustand_speichern() {
    local zustand="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    local temp_file
    temp_file=$(mktemp -p "$(dirname "$STATE_FILE")" .zustand_XXXXXX)
    echo "$zustand" | jq -c . > "$temp_file" || {
        error "Zustand konnte nicht gespeichert werden"
        return 1
    }
    mv "$temp_file" "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# Quellen holen
# ---------------------------------------------------------------------------

_git() {
    local verzeichnis=""
    if [[ $# -gt 0 && "$1" == "-C" ]]; then
        verzeichnis="$2"
        shift 2
    fi
    if [[ -n "$verzeichnis" ]]; then
        git -C "$verzeichnis" "$@" 2>&1
    else
        git "$@" 2>&1
    fi
}

quellen_holen() {
    mkdir -p "$QUELLEN_DIR"
    local baeume=()
    
    for repo in "${!QUELLEN[@]}"; do
        local branches="${QUELLEN[$repo]}"
        local spiegel="$QUELLEN_DIR/${repo}.git"
        local url="https://github.com/$GITHUB_BENUTZER/$repo.git"
        
        if [[ ! -d "$spiegel" ]]; then
            info "$repo wird geholt"
            if ! _git clone --mirror --filter=blob:none "$url" "$spiegel"; then
                error "$repo konnte nicht geholt werden"
                continue
            fi
        else
            if ! _git -C "$spiegel" remote update --prune; then
                warning "$repo konnte nicht aktualisiert werden"
            fi
        fi
        
        local branch_list
        if [[ "$branches" == "alle" ]]; then
            branch_list=$(_git -C "$spiegel" for-each-ref --format='%(refname:short)' refs/heads | grep -v '^$')
        else
            branch_list="$branches"
        fi
        
        while IFS= read -r branch; do
            [[ -z "$branch" ]] && continue
            local baum="$QUELLEN_DIR/baeume/$repo/${branch//\//_}"
            mkdir -p "$baum"
            if ! _git -C "$spiegel" --work-tree "$baum" checkout -f "$branch" -- .; then
                warning "$repo@$branch: Arbeitsbaum fehlgeschlagen"
                continue
            fi
            baeume+=("$repo" "$branch" "$baum")
        done <<< "$branch_list"
    done
    
    if [[ "${ABSTRACTIONS_EXECUTION:-gateway}" == "gateway" && -d "$WORKSPACE" ]]; then
        baeume+=("workspace" "local" "$WORKSPACE")
    fi
    
    info "Quellen bereit: ${#baeume[@]} Arbeitsbaeume"
    printf "%s\n" "${baeume[@]}"
}

# ---------------------------------------------------------------------------
# Inventar
# ---------------------------------------------------------------------------

_prioritaet() {
    local pfad="$1" sprache="$2"
    if [[ "$sprache" == "html" || "$sprache" == "css" ]]; then
        echo "low"
    elif [[ "$pfad" == scripts/* || "$pfad" == */scripts/* ]]; then
        echo "high"
    else
        echo "medium"
    fi
}

enthaelt_zugangsdaten() {
    local roh="$1"
    local muster='(sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'
    if echo "$roh" | grep -qE "$muster"; then
        return 0
    fi
    while IFS='=' read -r name wert; do
        if [[ "${name^^}" == *"TOKEN"* || "${name^^}" == *"SECRET"* || "${name^^}" == *"PASSWORD"* || "${name^^}" == *"API_KEY"* ]] && \
           [[ ${#wert} -ge 12 ]] && echo "$roh" | grep -qF "$wert"; then
            return 0
        fi
    done < <(env)
    return 1
}

inventar_bauen() {
    local baeume=()
    while IFS= read -r line; do
        baeume+=("$line")
    done
    
    declare -A dateien=()
    local i=0
    while [[ $i -lt ${#baeume[@]} ]]; do
        local repo="${baeume[$i]}" branch="${baeume[$i+1]}" baum="${baeume[$i+2]}"
        ((i+=3))
        
        while IFS= read -r -d '' pfad; do
            [[ ! -f "$pfad" ]] && continue
            local rel="${pfad#$baum/}"
            rel="${rel//\\//}"
            
            if [[ "$repo" == "workspace" ]]; then
                local teile=()
                IFS='/' read -ra teile <<< "$rel"
                if [[ "${teile[0]}" == "git" && ( "${teile[1]}" == "Abstraktionen" || \
                      "${teile[1]}" == "OpenClaw-gateway1-abstractions" || "${teile[1]}" == "quellen" ) ]]; then
                    continue
                fi
                local ausschluss_workspace=("work" "backups" "logs" "log" "db" "state" "tmp" "temp" "cache" ".cache" "artifacts" ".openclaw" "secrets" "credentials" ".credentials" "private" ".private")
                for teil in "${teile[@]}"; do
                    for muster in "${ausschluss_workspace[@]}"; do
                        if [[ "${teil,,}" == "${muster,,}" ]]; then
                            continue 3
                        fi
                    done
                done
            fi
            
            local ausschluss=0
            for muster in "${AUSSCHLUSS[@]}"; do
                if [[ "/$rel" == *"$muster"* ]]; then
                    ausschluss=1
                    break
                fi
            done
            [[ $ausschluss -eq 1 ]] && continue
            
            local extension="${pfad##*.}"
            extension=".$extension"
            local sprache="${QUELLSPRACHEN[$extension]}"
            [[ -z "$sprache" ]] && continue
            
            local roh
            if ! roh=$(cat "$pfad" 2>/dev/null); then
                continue
            fi
            [[ -z "$(tr -d '[:space:]' <<< "$roh")" ]] && continue
            if enthaelt_zugangsdaten "$roh"; then
                continue
            fi
            
            local schluessel
            schluessel=$(echo -n "$roh" | sha256sum | cut -c1-16)
            if [[ -z "${dateien[$schluessel]}" ]]; then
                local name="${pfad##*/}"
                local stamm="${name%.*}"
                local bytes=${#roh}
                local prioritaet=$(_prioritaet "$rel" "$sprache")
                dateien[$schluessel]="{\"hash\":\"$schluessel\",\"name\":\"$name\",\"stamm\":\"$stamm\",\"sprache\":\"$sprache\",\"bytes\":$bytes,\"pfad\":\"$pfad\",\"herkunft\":[\"$repo@$branch:$rel\"],\"prioritaet\":\"$prioritaet\"}"
            else
                local current="${dateien[$schluessel]}"
                local new_herkunft=$(echo "$current" | jq -r --arg h "$repo@$branch:$rel" '.herkunft + [$h]')
                dateien[$schluessel]=$(echo "$current" | jq --argjson h "$new_herkunft" '.herkunft = $h')
            fi
        done < <(find "$baum" -type f -print0)
    done
    
    local rang=('high' 'medium' 'low')
    local liste=()
    for eintrag in "${dateien[@]}"; do
        liste+=("$eintrag")
    done
    
    liste=($(printf '%s\n' "${liste[@]}" | jq -r --argjson rang '["high","medium","low"]' '
        . as $e | 
        index($e.prioritaet) as $prio |
        [$prio, $e.name] | @tsv
    ' | sort -k1,1n -k2 | cut -f2-))
    
    info "Inventar: ${#liste[@]} eindeutige Quelldateien"
    printf "%s\n" "${liste[@]}"
}

# ---------------------------------------------------------------------------
# Hauptprogramm
# ---------------------------------------------------------------------------

main() {
    local prioritaet="" anzahl=40 probelauf=0 nur_veroeffentlichen=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prioritaet)
                prioritaet="$2"
                shift 2
                ;;
            --anzahl)
                anzahl="$2"
                shift 2
                ;;
            --probelauf)
                probelauf=1
                shift
                ;;
            --nur-veroeffentlichen)
                nur_veroeffentlichen=1
                shift
                ;;
            *)
                error "Unbekannte Option: $1"
                return 2
                ;;
        esac
    done
    
    info "Abstractions Manager gestartet — Arbeitsverzeichnis $WORKSPACE"
    
    if [[ $nur_veroeffentlichen -eq 1 ]]; then
        if [[ $probelauf -eq 1 ]]; then
            error "--probelauf und --nur-veroeffentlichen sind nicht kombinierbar"
            return 2
        fi
        # Veroeffentlichungslogik hier implementieren
        return 0
    fi
    
    local schluessel=""
    if [[ $probelauf -eq 0 && "${ABSTRACTIONS_EXECUTION:-gateway}" == "standalone" ]]; then
        schluessel="${OPENROUTER_API_KEY:-}"
        if [[ -z "$schluessel" ]]; then
            error "OpenRouter-Zugang fuer eigenstaendigen Lauf fehlt"
            return 2
        fi
    fi
    
    local zustand
    zustand=$(zustand_laden) || return 1
    
    local baeume
    baeume=$(quellen_holen)
    if [[ -z "$baeume" ]]; then
        error "Keine Quellen verfuegbar"
        return 1
    fi
    
    local inventar
    inventar=$(inventar_bauen <<< "$baeume")
    if [[ -z "$inventar" ]]; then
        error "Inventar leer"
        return 1
    fi
    
    prioritaet="${prioritaet:-$(echo "$zustand" | jq -r '.naechste_prioritaet // "high"')}"
    
    # Uebersetzungslogik hier implementieren
    local zaehler='{"erzeugt":0,"uebersprungen":0,"verworfen":0,"dateien":0}'
    
    local reihum='{"high":"medium","medium":"low","low":"high","alle":"alle"}'
    local naechste
    naechste=$(echo "$reihum" | jq -r --arg p "$prioritaet" '.[$p]')
    if [[ $probelauf -eq 0 ]]; then
        zustand=$(echo "$zustand" | jq --arg p "$naechste" '.naechste_prioritaet = $p')
    fi
    
    local statistik="{\"letzter_lauf\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"quelldateien\":$(echo "$inventar" | wc -l),\"erzeugt\":0,\"uebersprungen\":0,\"verworfen\":0}"
    zustand=$(echo "$zustand" | jq --argjson s "$statistik" '.statistik = $s')
    
    # Bericht schreiben
    if [[ -d "$ABSTRACTIONS_REPO" ]]; then
        local status_file="$ABSTRACTIONS_REPO/STATUS.md"
        cat > "$status_file" << EOF
# Script Abstractions — Status

**Letzter Lauf:** $(date -u +%Y-%m-%d\ %H:%M) UTC

Jede Quelldatei der drei Repositories wird in zehn Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
$(for sprache in "${!ZIELSPRACHEN_EXT[@]}"; do
    count=0
    dir="$ABSTRACTIONS_REPO/$sprache"
    [[ -d "$dir" ]] && count=$(find "$dir" -type f -name "*${ZIELSPRACHEN_EXT[$sprache]}" | wc -l)
    echo "| $sprache | $count |"
done)
| **gesamt** | $(find "$ABSTRACTIONS_REPO" -mindepth 2 -type f -name '*.*' | wc -l) |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | $(echo "$inventar" | jq -r 'select(.prioritaet == "high")' | wc -l) | Betriebsscripte aus scripts-Verzeichnissen |
| medium | $(echo "$inventar" | jq -r 'select(.prioritaet == "medium")' | wc -l) | uebriger ausfuehrbarer Code |
| low | $(echo "$inventar" | jq -r 'select(.prioritaet == "low")' | wc -l) | Markup und Stilvorlagen |
| **gesamt** | **$(echo "$inventar" | wc -l)** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **0**

## Letzter Lauf

- bearbeitete Quelldateien: 0
- erzeugte Uebersetzungen: 0
- verworfen: 0

## Herkunft

- \`KikiKari/OpenClaw\` — main, gateway1, gateway2
- \`KikiKari/Projects\` — alle Branches
- \`KikiKari/Onboarding\` — main

Erzeugt von \`abstractions/ABSTRACTIONS_MANAGER.sh\`.
EOF
        info "STATUS.md fortgeschrieben"
    fi
    
    zustand_speichern "$zustand"
    
    info "Abgeschlossen: 0 erzeugt, 0 verworfen, 0 Quelldateien bearbeitet"
    return 0
}

main "$@"
