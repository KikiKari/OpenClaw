#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "e8d85f85e866b19311a7e2f14e7735c2aa34378b6dd77d016f2504585fbb0db4", "source_sha256": "e4175dbdf28a308cedabfa7374f4d36f53303dc9e8e653e949cb7c42ca54d44c", "target_language": "shell"}
# ABSTRACTIONS_MANAGER.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
readonly WORKSPACE="${ABSTRACTIONS_WORKSPACE:-/home/openclaw/.openclaw/workspace}"
readonly ABSTRACTIONS_REPO="$WORKSPACE/git/OpenClaw-gateway1-abstractions"
readonly QUELLEN_DIR="$WORKSPACE/git/quellen"
readonly LOG_DIR="$WORKSPACE/logs/abstractions-manager"
readonly STATE_FILE="$WORKSPACE/db/abstractions_state.json"

readonly GITHUB_BENUTZER="KikiKari"

# Herkunft der Quelldateien
declare -A QUELLEN=(
    ["OpenClaw"]="main,gateway1,gateway2"
    ["Projects"]="alle"
    ["Onboarding"]="main"
)

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

# Zielverzeichnisse und Endungen
declare -A ZIELSPRACHEN=(
    ["javascript"]="js|JavaScript fuer Node 20"
    ["perl5"]="pl|Perl 5 mit use strict und use warnings"
    ["powershell"]="ps1|PowerShell 7"
    ["python"]="py|Python 3.12"
    ["shell"]="sh|Bash 5 mit set -euo pipefail"
    ["tcl"]="tcl|Tcl 8.6"
    ["perl6"]="raku|Raku"
    ["ruby"]="rb|Ruby"
    ["lua"]="lua|Lua"
    ["go"]="go|Go"
)

# Verzeichnisse und Muster, die nie eingelesen werden
readonly AUSSCHLUSS=("node_modules/" "/.git/" "__pycache__/" "dist/" "build/" "vendor/"
                     ".venv/" "site-packages/" "python-hardener-workspace/" ".artifacts/"
                     "coverage/" ".next/" "target/" "/work/" "/backups/")

readonly MAX_BYTES=200000

# Modelle und API-Konfiguration
readonly MODELLE=("qwen/qwen3-coder" "deepseek/deepseek-chat-v3.1" "z-ai/glm-4.6" 
                  "mistralai/codestral-2508" "qwen/qwen-2.5-coder-32b-instruct")
readonly API_URL="https://openrouter.ai/api/v1/chat/completions"
readonly ZEITLIMIT=240
readonly VERSUCHE=3

# Globale Variablen
declare -A zustand_erledigt
declare -A statistik
declare -A belegt
declare -A pruefbelegele
declare -a inventar_liste
declare -a herkunft_liste

# Protokoll
function protokoll() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ${level//-7s} | $(basename "${BASH_SOURCE[1]}"):${BASH_LINENO[0]} | $*" >&2
}

function info() { protokoll "INFO   " "$@"; }
function warn() { protokoll "WARNING" "$@"; }
function error() { protokoll "ERROR  " "$@"; }

# Zustand
function zustand_laden() {
    if [[ -f "$STATE_FILE" ]]; then
        if ! jq -e . >/dev/null 2>&1 < "$STATE_FILE"; then
            error "Zustand unlesbar — Lauf wird angehalten"
            exit 1
        fi
        mapfile -t lines < <(jq -r '.erledigt | to_entries[] | "\(.key):\(.value[])"' "$STATE_FILE" 2>/dev/null || true)
        for line in "${lines[@]}"; do
            IFS=':' read -r hash sprache <<< "$line"
            zustand_erledigt["$hash,$sprache"]=1
        done
    fi
}

function zustand_speichern() {
    mkdir -p "$(dirname "$STATE_FILE")"
    local tmpfile
    tmpfile=$(mktemp -p "$(dirname "$STATE_FILE")" ".zustand_XXXXXX")
    
    {
        echo "{"
        echo "  \"erledigt\": {"
        local first=1
        for key in "${!zustand_erledigt[@]}"; do
            IFS=',' read -r hash sprache <<< "$key"
            if [[ $first -eq 1 ]]; then
                echo "    \"$hash\": [\"$sprache\"]"
                first=0
            else
                echo "    ,\"$hash\": [\"$sprache\"]"
            fi
        done
        echo "  }"
        echo "  ,\"statistik\": {"
        for key in "${!statistik[@]}"; do
            echo "    \"$key\": \"${statistik[$key]}\""
        done
        echo "  }"
        echo "}"
    } > "$tmpfile"
    
    mv "$tmpfile" "$STATE_FILE"
}

# Git-Funktionen
function git_cmd() {
    local dir=""
    if [[ "$1" == "-C" ]]; then
        dir="$2"
        shift 2
    fi
    
    if [[ -n "$dir" ]]; then
        git -C "$dir" "$@"
    else
        git "$@"
    fi
}

function quellen_holen() {
    mkdir -p "$QUELLEN_DIR"
    local baeume=()
    
    for repo in "${!QUELLEN[@]}"; do
        local spiegel="$QUELLEN_DIR/${repo}.git"
        local url="https://github.com/$GITHUB_BENUTZER/${repo}.git"
        
        if [[ ! -d "$spiegel" ]]; then
            info "$repo wird geholt"
            if ! git clone --mirror --filter=blob:none "$url" "$spiegel" 2>/dev/null; then
                error "$repo konnte nicht geholt werden"
                continue
            fi
        else
            if ! git_cmd -C "$spiegel" remote update --prune 2>/dev/null; then
                warn "$repo konnte nicht aktualisiert werden"
            fi
        fi
        
        local branches_str="${QUELLEN[$repo]}"
        local branches=()
        if [[ "$branches_str" == "alle" ]]; then
            mapfile -t branches < <(git_cmd -C "$spiegel" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | sed '/^$/d')
        else
            IFS=',' read -ra branches <<< "$branches_str"
        fi
        
        for branch in "${branches[@]}"; do
            local baum="$QUELLEN_DIR/baeume/$repo/${branch//\//_}"
            mkdir -p "$baum"
            if ! git_cmd -C "$spiegel" --work-tree "$baum" checkout -f "$branch" -- . 2>/dev/null; then
                warn "$repo@$branch: Arbeitsbaum fehlgeschlagen"
                continue
            fi
            baeume+=("$repo|$branch|$baum")
        done
    done
    
    # Lokale Gateway-Skripte
    if [[ "${ABSTRACTIONS_EXECUTION:-gateway}" == "gateway" ]] && [[ -d "$WORKSPACE" ]]; then
        baeume+=("workspace|local|$WORKSPACE")
    fi
    
    info "Quellen bereit: ${#baeume[@]} Arbeitsbaeume"
    printf '%s\n' "${baeume[@]}"
}

# Inventar
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

function enthaelt_zugangsdaten() {
    local file="$1"
    local content
    content=$(cat "$file" 2>/dev/null || echo "")
    
    # Prüfe auf bekannte Token-Muster
    if grep -qE '(sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' "$file" 2>/dev/null; then
        return 0
    fi
    
    # Prüfe Umgebungsvariablen
    for var in "${!env[@]}"; do
        if [[ "${var^^}" =~ (TOKEN|SECRET|PASSWORD|API_KEY) ]] && [[ ${#env[$var]} -ge 12 ]]; then
            if grep -q "${env[$var]}" "$file" 2>/dev/null; then
                return 0
            fi
        fi
    done
    
    return 1
}

function inventar_bauen() {
    local baeume_str="$1"
    declare -A dateien
    
    while IFS='|' read -r repo branch baum; do
        if [[ -z "$repo" ]]; then continue; fi
        
        while IFS= read -r -d '' pfad; do
            if [[ ! -f "$pfad" ]]; then continue; fi
            
            local rel
            rel=$(realpath --relative-to="$baum" "$pfad" 2>/dev/null | sed 's/\\/\//g')
            
            if [[ "$repo" == "workspace" ]]; then
                # Überspringe bestimmte Pfade
                local skip=0
                IFS='/' read -ra teile <<< "$rel"
                for teil in "${teile[@]}"; do
                    if [[ "$teil" =~ ^(git|work|backups|logs|log|db|state|tmp|temp|cache|\.cache|artifacts|\.openclaw|secrets|credentials|\.credentials|private|\.private)$ ]]; then
                        skip=1
                        break
                    fi
                done
                
                if [[ $skip -eq 1 ]] || [[ "$rel" =~ ^(git/Abstraktionen|git/OpenClaw-gateway1-abstractions|git/quellen) ]]; then
                    continue
                fi
            fi
            
            local ausschliessen=0
            for muster in "${AUSSCHLUSS[@]}"; do
                if [[ "/$rel" == *"$muster"* ]]; then
                    ausschliessen=1
                    break
                fi
            done
            if [[ $ausschliessen -eq 1 ]]; then continue; fi
            
            local ext="${pfad##*.}"
            local sprache="${QUELLSPRACHEN[.$ext]}"
            if [[ -z "$sprache" ]]; then continue; fi
            
            if ! enthaelt_zugangsdaten "$pfad"; then
                local roh
                roh=$(cat "$pfad" 2>/dev/null || echo "")
                if [[ -n "${roh// /}" ]]; then
                    local schluessel
                    schluessel=$(echo -n "$roh" | sha256sum | cut -d' ' -f1 | head -c16)
                    
                    if [[ -z "${dateien[$schluessel]+isset}" ]]; then
                        dateien["$schluessel"]="$pfad|$sprache|${pfad##*/}|$(dirname "$rel")"
                    fi
                    
                    herkunft_liste+=("$schluessel|$repo@$branch:$rel")
                fi
            fi
        done < <(find "$baum" -type f -print0 2>/dev/null || true)
    done <<< "$baeume_str"
    
    # Sortiere nach Priorität
    local sorted=()
    for key in "${!dateien[@]}"; do
        IFS='|' read -r pfad sprache name rel_path <<< "${dateien[$key]}"
        local prio
        prio=$(prioritaet_bestimmen "$rel_path" "$sprache")
        sorted+=("$prio|$name|$key")
    done
    
    IFS=$'\n' sorted=($(sort <<<"${sorted[*]}"))
    inventar_liste=("${sorted[@]}")
    
    info "Inventar: ${#inventar_liste[@]} eindeutige Quelldateien"
}

# Übersetzung
function modell_fragen() {
    local quelle="$1"
    local quellsprache="$2"
    local zielsprache="$3"
    local name="$4"
    local schluessel="$5"
    
    local ziel_bezeichnung=""
    IFS='|' read -r _ ziel_bezeichnung <<< "${ZIELSPRACHEN[$zielsprache]}"
    
    local auftrag="Portiere die folgende Datei $name von $quellsprache nach $ziel_bezeichnung."
    if [[ "$quellsprache" == "html" ]] || [[ "$quellsprache" == "css" ]]; then
        auftrag+=" Das Original ist $quellsprache. Erzeuge ein Programm in der Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine nachvollziehbare Erzeugung der Struktur."
    fi
    auftrag+="\n\n----- Beginn $name -----\n$quelle\n----- Ende $name -----"
    
    local modelle=("${MODELLE[@]}")
    if [[ -n "${ABSTRACTIONS_MODELL:-}" ]]; then
        modelle=("$ABSTRACTIONS_MODELL")
    fi
    
    for modell in "${modelle[@]}"; do
        for ((versuch=1; versuch<=VERSUCHE; versuch++)); do
            local body
            body=$(jq -n --arg model "$modell" --arg auftrag "$auftrag" '{
                model: $model,
                messages: [
                    {role: "system", content: "Du portierst Quellcode zwischen Programmiersprachen.\n\nRegeln:\n1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine Erklaerung davor oder danach, keine Code-Zaeune.\n2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein \"hier waere\", kein leerer Rumpf, kein Platzhalter.\n3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.\n4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift. Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.\n5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.\n6. Beginne mit der passenden Shebang-Zeile."},
                    {role: "user", content: $auftrag}
                ],
                temperature: 0.1,
                max_tokens: 8000
            }')
            
            local response
            response=$(curl -s -X POST "$API_URL" \
                -H "Authorization: Bearer $schluessel" \
                -H "Content-Type: application/json" \
                -H "HTTP-Referer: https://github.com/KikiKari/Projects" \
                -H "X-Title: Abstractions Manager" \
                --data-binary "$body" \
                --max-time "$ZEITLIMIT" 2>/dev/null || echo "")
            
            if [[ -n "$response" ]] && jq -e . >/dev/null 2>&1 <<< "$response"; then
                local inhalt
                inhalt=$(jq -r '.choices[0].message.content' <<< "$response" 2>/dev/null)
                if [[ -n "${inhalt// /}" ]]; then
                    # Entferne Code-Zäune
                    inhalt=$(sed 's/^```.*//g' <<< "$inhalt" | sed '/^```$/d' | sed '/^[[:space:]]*$/d')
                    # Für Go entferne Shebang
                    if [[ "$zielsprache" == "go" ]] && [[ "$inhalt" == "#!"* ]]; then
                        inhalt=$(tail -n +2 <<< "$inhalt")
                    fi
                    echo "$inhalt"
                    return 0
                fi
            fi
            
            sleep $((2**versuch < 20 ? 2**versuch : 20))
        done
    done
    
    error "$name -> $zielsprache: kein Modell hat geliefert"
    return 1
}

# Prüfung
function erzeugnis_pruefen() {
    local code="$1"
    local zielsprache="$2"
    local quelle="${3:-}"
    
    local quellzeilen=0
    if [[ -n "$quelle" ]]; then
        quellzeilen=$(wc -l <<< "$quelle" | tr -d ' ')
    fi
    
    local zeilen
    zeilen=$(grep -c '[^[:space:]]' <<< "$code" 2>/dev/null || echo "0")
    
    local mindestens=$((quellzeilen/3 > 6 ? 6 : (quellzeilen/3 < 2 ? 2 : quellzeilen/3)))
    if [[ $zeilen -lt $mindestens ]]; then
        echo "false|zu kurz ($zeilen statt mindestens $mindestens Zeilen)"
        return
    fi
    
    # Prüfe auf Platzhalter
    local verdacht=("TODO: Implementiere" "TODO: implement" "not implemented" "hier waere" "Platzhalter" "your code here" "pass  # TODO")
    local quelle_lower="${quelle,,}"
    for muster in "${verdacht[@]}"; do
        if [[ "${code,,}" == *"${muster,,}"* ]] && [[ "$quelle_lower" != *"${muster,,}"* ]]; then
            echo "false|unfertig ($muster)"
            return
        fi
    done
    
    # Sprachspezifische Prüfung
    case "$zielsprache" in
        "python")
            if python3 -m py_compile <(echo "$code") 2>/dev/null; then
                echo "true|syntax ok"
            else
                echo "false|Syntaxfehler"
            fi
            ;;
        "javascript")
            if node --check <(echo "$code") 2>/dev/null; then
                echo "true|syntax ok"
            else
                echo "false|Syntaxfehler"
            fi
            ;;
        "perl5")
            if perl -c <(echo "$code") 2>/dev/null; then
                echo "true|syntax ok"
            else
                echo "false|Syntaxfehler"
            fi
            ;;
        "shell")
            if bash -n <(echo "$code") 2>/dev/null; then
                echo "true|syntax ok"
            else
                echo "false|Syntaxfehler"
            fi
            ;;
        *)
            echo "true|syntax ok"
            ;;
    esac
}

# Ablage
function zieldatei_bestimmen() {
    local eintrag_hash="$1"
    local zielsprache="$2"
    local stamm="$3"
    
    IFS='|' read -r ext _ <<< "${ZIELSPRACHEN[$zielsprache]}"
    local verzeichnis="$ABSTRACTIONS_REPO/$zielsprache"
    local ziel="$verzeichnis/${stamm}.${ext}"
    
    if [[ -e "$ziel" ]]; then
        stamm="${stamm}_${eintrag_hash:0:6}"
        ziel="$verzeichnis/${stamm}.${ext}"
        local zaehler=2
        while [[ -e "$ziel" ]]; do
            ziel="$verzeichnis/${stamm}_${zaehler}.${ext}"
            ((zaehler++))
        done
    fi
    
    echo "$ziel"
}

function kopf_erstellen() {
    local eintrag_name="$1"
    local eintrag_sprache="$2"
    local eintrag_herkunft="$3"
    local zielsprache="$4"
    
    local zeichen="#"
    case "$zielsprache" in
        "javascript"|"go") zeichen="//" ;;
        "lua") zeichen="--" ;;
    esac
    
    local heute
    heute=$(date -u +%Y-%m-%d)
    
    echo "${zeichen} ${eintrag_name} — portiert nach ${zielsprache}"
    echo "${zeichen} Quelle: ${eintrag_sprache}, ${eintrag_herkunft}"
    echo "${zeichen} Erzeugt: ${heute} durch ABSTRACTIONS_MANAGER.py"
}

function ablegen() {
    local eintrag_hash="$1"
    local zielsprache="$2"
    local code="$3"
    local eintrag_name="$4"
    local eintrag_sprache="$5"
    local eintrag_herkunft="$6"
    local eintrag_stamm="$7"
    
    local ziel
    ziel=$(zieldatei_bestimmen "$eintrag_hash" "$zielsprache" "$eintrag_stamm")
    
    mkdir -p "$(dirname "$ziel")"
    
    local inhalt=""
    local zeilen=()
    IFS=$'\n' read -d '' -ra zeilen <<< "$code"
    
    if [[ ${#zeilen[@]} -gt 0 ]] && [[ "${zeilen[0]}" == "#!"* ]]; then
        inhalt="${zeilen[0]}"$'\n'
        inhalt+=$(kopf_erstellen "$eintrag_name" "$eintrag_sprache" "$eintrag_herkunft" "$zielsprache")$'\n\n'
        inhalt+=$(printf '%s\n' "${zeilen[@]:1}")
    else
        inhalt=$(kopf_erstellen "$eintrag_name" "$eintrag_sprache" "$eintrag_herkunft" "$zielsprache")$'\n'
        inhalt+="$code"
    fi
    
    local tmpfile
    tmpfile=$(mktemp -p "$(dirname "$ziel")" ".neu_XXXXXXXX.${ZIELSPRACHEN[$zielsprache]%%|*}")
    echo "$inhalt" > "$tmpfile"
    mv "$tmpfile" "$ziel"
    
    echo "$ziel"
}

# Hauptfunktion
function uebersetzen() {
    local prioritaet="${1:-alle}"
    local anzahl="${2:-40}"
    local probelauf="${3:-false}"
    local schluessel="${4:-}"
    
    local zaehler_erzeugt=0
    local zaehler_uebersprungen=0
    local zaehler_verworfen=0
    local zaehler_dateien=0
    
    local offen=()
    for item in "${inventar_liste[@]}"; do
        IFS='|' read -r prio name key <<< "$item"
        if [[ "$prioritaet" == "alle" ]] || [[ "$prio" == "$prioritaet" ]]; then
            offen+=("$item")
        fi
    done
    
    info "Prioritaet $prioritaet: ${#offen[@]} Quelldateien im Bestand"
    
    for item in "${offen[@]}"; do
        if [[ $zaehler_dateien -ge $anzahl ]]; then
            info "Kontingent von $anzahl Quelldateien erreicht"
            break
        fi
        
        IFS='|' read -r prio name key <<< "$item"
        
        # Finde die entsprechende Datei
        local datei_info=""
        for di in "${!dateien[@]}"; do
            if [[ "$di" == "$key" ]]; then
                datei_info="${dateien[$di]}"
                break
            fi
        done
        
        if [[ -z "$datei_info" ]]; then
            continue
        fi
        
        IFS='|' read -r pfad sprache dateiname _ <<< "$datei_info"
        
        # Prüfe ob bereits erledigt
        local fertig=()
        for ziel in "${!ZIELSPRACHEN[@]}"; do
            if [[ "$ziel" != "$sprache" ]] && [[ -z "${zustand_erledigt[$key,$ziel]+isset}" ]]; then
                fertig+=("$ziel")
            fi
        done
        
        if [[ ${#fertig[@]} -eq 0 ]]; then
            continue
        fi
        
        # Prüfe Dateigröße
        local bytes
        bytes=$(stat -c%s "$pfad" 2>/dev/null || echo "0")
        if [[ $bytes -gt $MAX_BYTES ]]; then
            warn "$dateiname: $bytes Bytes überschreiten das Auftragslimit von $MAX_BYTES Bytes"
            ((zaehler_verworfen++))
            continue
        fi
        
        # Lese Quelltext
        local quelle
        quelle=$(cat "$pfad" 2>/dev/null || echo "")
        if enthaelt_zugangsdaten "$pfad"; then
            warn "$dateiname enthaelt Zugangsdaten und wird nicht gesendet"
            ((zaehler_verworfen++))
            continue
        fi
        
        ((zaehler_dateien++))
        
        info "[$prio] $dateiname ($sprache, $bytes B) -> ${fertig[*]}"
        
        for zielsprache in "${fertig[@]}"; do
            if [[ "$probelauf" == "true" ]]; then
                info "  $zielsprache: Probelauf, nichts gesendet"
                ((zaehler_uebersprungen++))
                continue
            fi
            
            local code
            code=$(modell_fragen "$quelle" "$sprache" "$zielsprache" "$dateiname" "$schluessel")
            if [[ $? -ne 0 ]]; then
                ((zaehler_verworfen++))
                continue
            fi
            
            local pruefung
            pruefung=$(erzeugnis_pruefen "$code" "$zielsprache" "$quelle")
            IFS='|' read -r angenommen grund <<< "$pruefung"
            
            if [[ "$angenommen" != "true" ]]; then
                warn "  $zielsprache: verworfen — $grund"
                ((zaehler_verworfen++))
                continue
            fi
            
            local ziel
            ziel=$(ablegen "$key" "$zielsprache" "$code" "$dateiname" "$sprache" "${herkunft_liste[0]#*$key|}" "$dateiname")
            if [[ $? -eq 0 ]]; then
                info "  $zielsprache: $(basename "$ziel") ($grund)"
                ((zaehler_erzeugt++))
                zustand_erledigt["$key,$zielsprache"]=1
            else
                ((zaehler_verworfen++))
            fi
        done
    done
    
    statistik["erzeugt"]=$zaehler_erzeugt
    statistik["uebersprungen"]=$zaehler_uebersprungen
    statistik["verworfen"]=$zaehler_verworfen
    statistik["dateien"]=$zaehler_dateien
}

# Bericht
function bericht_schreiben() {
    if [[ ! -d "$ABSTRACTIONS_REPO" ]]; then
        warn "Abstraktions-Repository fehlt: $ABSTRACTIONS_REPO"
        return
    fi
    
    local status_file="$ABSTRACTIONS_REPO/STATUS.md"
    
    {
        echo "# Script Abstractions — Status"
        echo ""
        echo "**Letzter Lauf:** $(date -u +%Y-%m-%d\ %H:%M) UTC"
        echo ""
        echo "Jede Quelldatei der drei Repositories wird in zehn Zielsprachen portiert."
        echo "Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige"
        echo "Syntax oder mit Platzhaltern werden verworfen."
        echo ""
        echo "## Bestand"
        echo ""
        echo "| Zielsprache | Dateien |"
        echo "|---|---:|"
        
        local gesamt=0
        for sprache in "${!ZIELSPRACHEN[@]}"; do
            local count=0
            if [[ -d "$ABSTRACTIONS_REPO/$sprache" ]]; then
                count=$(find "$ABSTRACTIONS_REPO/$sprache" -type f 2>/dev/null | wc -l)
            fi
            echo "| $sprache | $count |"
            ((gesamt+=count))
        done
        echo "| **gesamt** | **$gesamt** |"
        echo ""
        echo "## Quellen"
        echo ""
        echo "| Prioritaet | Quelldateien | Bedeutung |"
        echo "|---|---:|---|"
        echo "| high | TBD | Betriebsscripte aus scripts-Verzeichnissen |"
        echo "| medium | TBD | uebriger ausfuehrbarer Code |"
        echo "| low | TBD | Markup und Stilvorlagen |"
        echo "| **gesamt** | TBD | nach Inhalt dedupliziert |"
        echo ""
        echo "Noch offene Sprachpaare: **TBD**"
        echo ""
        echo "## Letzter Lauf"
        echo ""
        echo "- bearbeitete Quelldateien: ${statistik[dateien]:-0}"
        echo "- erzeugte Uebersetzungen: ${statistik[erzeugt]:-0}"
        echo "- verworfen: ${statistik[verworfen]:-0}"
        echo ""
        echo "## Herkunft"
        echo ""
        echo "- \`KikiKari/OpenClaw\` — main, gateway1, gateway2"
        echo "- \`KikiKari/Projects\` — alle Branches"
        echo "- \`KikiKari/Onboarding\` — main"
        echo ""
        echo "Erzeugt von \`abstractions/ABSTRACTIONS_MANAGER.py\`."
        echo ""
    } > "$status_file"
    
    info "STATUS.md fortgeschrieben"
}

# Hauptprogramm
function main() {
    local prioritaet=""
    local anzahl="${ABSTRACTIONS_ANZAHL:-40}"
    local probelauf=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --prioritaet)
                prioritaet="$2"
                shift 2
                ;;
            --anzahl)
                anzahl="$2"
                shift 2
                ;;
            --probelauf)
                probelauf=true
                shift
                ;;
            *)
                echo "Unbekannte Option: $1" >&2
                return 2
                ;;
        esac
    done
    
    info "Abstractions Manager gestartet — Arbeitsverzeichnis $WORKSPACE"
    
    if [[ "$probelauf" == "false" ]] && [[ "${ABSTRACTIONS_EXECUTION:-gateway}" == "standalone" ]]; then
        if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
            error "OpenRouter-Zugang fuer eigenstaendigen Lauf fehlt"
            return 2
        fi
    fi
    
    zustand_laden
    
    local baeume
    baeume=$(quellen_holen)
    if [[ -z "$baeume" ]]; then
        error "Keine Quellen verfuegbar"
        return 1
    fi
    
    inventar_bauen "$baeume"
    if [[ ${#inventar_liste[@]} -eq 0 ]]; then
        error "Inventar leer"
        return 1
    fi
    
    if [[ -z "$prioritaet" ]]; then
        prioritaet="${zustand_naechste_prioritaet:-high}"
    fi
    
    uebersetzen "$prioritaet" "$anzahl" "$probelauf" "${OPENROUTER_API_KEY:-}"
    
    local reihum_high="medium"
    local reihum_medium="low"
    local reihum_low="high"
    
    case "$prioritaet" in
        "high") statistik["naechste_prioritaet"]="$reihum_high" ;;
        "medium") statistik["naechste_prioritaet"]="$reihum_medium" ;;
        "low") statistik["naechste_prioritaet"]="$reihum_low" ;;
        *) statistik["naechste_prioritaet"]="$prioritaet" ;;
    esac
    
    statistik["letzter_lauf"]=$(date -u +%Y-%m-%dT%H:%M:%S)
    statistik["quelldateien"]=${#inventar_liste[@]}
    
    bericht_schreiben
    zustand_speichern
    
    info "Abgeschlossen: ${statistik[erzeugt]:-0} erzeugt, ${statistik[verworfen]:-0} verworfen, ${statistik[dateien]:-0} Quelldateien bearbeitet"
    
    if [[ ${statistik[verworfen]:-0} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

main "$@"
