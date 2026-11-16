#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "8fd5eb573df0bc6b618d08b21a7f23494b49bd18c31464e0b82eb0422d9c869d", "source_sha256": "fc4ce94d8389188be8aa35f040d616ca2baa44095f057fa78606f347d342ff4b", "target_language": "shell"}
# ABSTRACTIONS_MANAGER.py — portiert nach shell
# Quelle: python, workspace@local:git/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
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
    ["javascript"]="js:JavaScript fuer Node 20"
    ["perl5"]="pl:Perl 5 mit use strict und use warnings"
    ["powershell"]="ps1:PowerShell 7"
    ["python"]="py:Python 3.12"
    ["shell"]="sh:Bash 5 mit set -euo pipefail"
    ["tcl"]="tcl:Tcl 8.6"
)

# Verzeichnisse und Muster, die nie eingelesen werden
readonly AUSSCHLUSS=("node_modules/" "/.git/" "__pycache__/" "dist/" "build/" "vendor/"
                     ".venv/" "site-packages/" "python-hardener-workspace/" ".artifacts/"
                     "coverage/" ".next/" "target/")
readonly MAX_BYTES=200000

# Modelle in Reihenfolge
readonly MODELLE=("qwen/qwen3-coder" "deepseek/deepseek-chat-v3.1" "z-ai/glm-4.6"
                  "mistralai/codestral-2508" "qwen/qwen-2.5-coder-32b-instruct")
readonly API_URL="https://openrouter.ai/api/v1/chat/completions"
readonly ZEITLIMIT=240
readonly VERSUCHE=3

# Globale Variablen
declare -A STATISTIK
declare -A BELEGT
declare -A ERLEDIGT
declare -a INVENTAR
declare NAECHSTE_PRIO="high"

# Logging-Funktionen
log() {
    local level="$1"; shift
    local msg="$*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ${level//-7s} | $(caller 0 | cut -d' ' -f2):$(caller 0 | cut -d' ' -f1) | $msg" >&2
}

log_info() { log "INFO   " "$@"; }
log_warn() { log "WARNING" "$@"; }
log_error() { log "ERROR  " "$@"; }

# Zustandsmanagement
zustand_laden() {
    if [[ -f "$STATE_FILE" ]]; then
        local json_content
        json_content=$(<"$STATE_FILE") || {
            log_warn "Zustand unlesbar — es wird neu begonnen"
            return
        }
        
        # Parsen des JSON (vereinfacht)
        if [[ "$json_content" =~ \"naechste_prioritaet\" ]]; then
            NAECHSTE_PRIO=$(echo "$json_content" | grep -o '"naechste_prioritaet"[^}]*}' | cut -d'"' -f4)
        fi
        
        # Statistik laden
        if [[ "$json_content" =~ \"statistik\" ]]; then
            local stat_block
            stat_block=$(echo "$json_content" | sed -n '/"statistik"/,/}/p')
            STATISTIK[letzter_lauf]=$(echo "$stat_block" | grep '"letzter_lauf"' | cut -d'"' -f4)
            STATISTIK[quelldateien]=$(echo "$stat_block" | grep '"quelldateien"' | grep -o '[0-9]*')
        fi
    fi
}

zustand_speichern() {
    mkdir -p "$(dirname "$STATE_FILE")"
    
    local tmpfile
    tmpfile=$(mktemp -p "$(dirname "$STATE_FILE")" ".zustand_XXXXXX")
    
    cat >"$tmpfile" <<EOF
{
  "naechste_prioritaet": "$NAECHSTE_PRIO",
  "statistik": {
    "letzter_lauf": "$(date -u +%Y-%m-%dT%H:%M:%S)",
    "quelldateien": ${#INVENTAR[@]}
  }
}
EOF
    
    mv "$tmpfile" "$STATE_FILE"
}

# Git-Hilfsfunktion
_git() {
    local dir=""
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir=*)
                dir="${1#--dir=}"
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    if [[ -n "$dir" ]]; then
        git -C "$dir" "${args[@]}"
    else
        git "${args[@]}"
    fi
}

# Quellen holen
quellen_holen() {
    mkdir -p "$QUELLEN_DIR"
    
    local baeume=()
    
    for repo in "${!QUELLEN[@]}"; do
        local spiegel="$QUELLEN_DIR/${repo}.git"
        local url="https://github.com/$GITHUB_BENUTZER/${repo}.git"
        
        if [[ ! -d "$spiegel" ]]; then
            log_info "$repo wird geholt"
            if ! _git clone --mirror --filter=blob:none "$url" "$spiegel" 2>/dev/null; then
                log_error "$repo konnte nicht geholt werden"
                continue
            fi
        else
            if ! _git remote update --prune --dir="$spiegel" 2>/dev/null; then
                log_warn "$repo konnte nicht aktualisiert werden"
            fi
        fi
        
        local branches_str="${QUELLEN[$repo]}"
        local branches=()
        
        if [[ "$branches_str" == "alle" ]]; then
            mapfile -t branches < <(_git for-each-ref --format='%(refname:short)' refs/heads --dir="$spiegel" 2>/dev/null | grep -v '^$')
        else
            IFS=',' read -ra branches <<< "$branches_str"
        fi
        
        for branch in "${branches[@]}"; do
            local baum="$QUELLEN_DIR/baeume/$repo/${branch//\//_}"
            mkdir -p "$baum"
            
            if ! _git --work-tree="$baum" checkout -f "$branch" -- . --dir="$spiegel" 2>/dev/null; then
                log_warn "$repo@$branch: Arbeitsbaum fehlgeschlagen"
                continue
            fi
            
            baeume+=("$repo:$branch:$baum")
        done
    done
    
    log_info "Quellen bereit: ${#baeume[@]} Arbeitsbaeume"
    echo "${baeume[@]}"
}

# Prioritätsbestimmung
_prioritaet() {
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

# Inventar erstellen
inventar_bauen() {
    local baeume=("$@")
    local dateien=()
    local seen_hashes=()
    
    for baum_entry in "${baeume[@]}"; do
        IFS=':' read -r repo branch baum <<< "$baum_entry"
        
        while IFS= read -r -d '' file; do
            local rel_path
            rel_path=$(realpath --relative-to="$baum" "$file")
            rel_path=${rel_path//\\//}
            
            # Ausschlussprüfung
            local skip=false
            for muster in "${AUSSCHLUSS[@]}"; do
                if [[ "/$rel_path" == *"$muster"* ]]; then
                    skip=true
                    break
                fi
            done
            [[ "$skip" == true ]] && continue
            
            # Sprache bestimmen
            local ext="${file##*.}"
            local sprache="${QUELLSPRACHEN[.$ext]}"
            [[ -z "$sprache" ]] && continue
            
            # Dateigröße prüfen
            local size
            size=$(stat -c%s "$file" 2>/dev/null) || continue
            [[ $size -eq 0 ]] || [[ $size -gt $MAX_BYTES ]] && continue
            
            # Hash berechnen
            local hash
            hash=$(sha256sum "$file" | cut -c1-16)
            
            # Deduplizierung
            if [[ " ${seen_hashes[*]} " =~ " $hash " ]]; then
                # Nur Herkunft hinzufügen
                for i in "${!dateien[@]}"; do
                    if [[ "${dateien[$i]}" == *"$hash"* ]]; then
                        dateien[$i]+="|$repo@$branch:$rel_path"
                        break
                    fi
                done
                continue
            fi
            
            seen_hashes+=("$hash")
            
            # Neue Datei hinzufügen
            local prio
            prio=$(_prioritaet "$rel_path" "$sprache")
            local name
            name=$(basename "$file")
            local stem="${name%.*}"
            dateien+=("$hash:$name:$stem:$sprache:$size:$file:$prio:$repo@$branch:$rel_path")
        done < <(find "$baum" -type f -print0 2>/dev/null)
    done
    
    # Sortieren
    local sorted=()
    for entry in "${dateien[@]}"; do
        IFS=':' read -r hash name stem sprache size file prio rest <<< "$entry"
        case "$prio" in
            high) sorted=("HIGH:$entry" "${sorted[@]}") ;;
            medium) sorted+=("MED:$entry") ;;
            low) sorted+=("LOW:$entry") ;;
        esac
    done
    
    # Alphabetisch innerhalb jeder Priorität
    local final_sorted=()
    local high_entries=() med_entries=() low_entries=()
    
    for entry in "${sorted[@]}"; do
        if [[ "$entry" == HIGH:* ]]; then
            high_entries+=("${entry#HIGH:}")
        elif [[ "$entry" == MED:* ]]; then
            med_entries+=("${entry#MED:}")
        else
            low_entries+=("${entry#LOW:}")
        fi
    done
    
    IFS=$'\n' sorted_high=($(sort <<<"${high_entries[*]}"))
    IFS=$'\n' sorted_med=($(sort <<<"${med_entries[*]}"))
    IFS=$'\n' sorted_low=($(sort <<<"${low_entries[*]}"))
    
    INVENTAR=("${sorted_high[@]}" "${sorted_med[@]}" "${sorted_low[@]}")
    log_info "Inventar: ${#INVENTAR[@]} eindeutige Quelldateien"
}

# Modell-Anfrage
modell_fragen() {
    local quelle="$1"
    local quellsprache="$2"
    local zielsprache="$3"
    local name="$4"
    local schluessel="$5"
    
    local ziel_bezeichnung
    ziel_bezeichnung=$(echo "${ZIELSPRACHEN[$zielsprache]}" | cut -d':' -f2)
    
    local auftrag="Portiere die folgende Datei $name von $quellsprache nach $ziel_bezeichnung."
    
    if [[ "$quellsprache" == "html" ]] || [[ "$quellsprache" == "css" ]]; then
        auftrag+=" Das Original ist $quellsprache. Erzeuge ein Programm in der Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine nachvollziehbare Erzeugung der Struktur."
    fi
    
    auftrag+="\n\n----- Beginn $name -----\n$quelle\n----- Ende $name -----"
    
    local modelle
    if [[ -n "${ABSTRACTIONS_MODELL:-}" ]]; then
        modelle=("$ABSTRACTIONS_MODELL")
    else
        modelle=("${MODELLE[@]}")
    fi
    
    for modell in "${modelle[@]}"; do
        for ((versuch=1; versuch<=VERSUCHE; versuch++)); do
            local json_body
            json_body=$(jq -n --arg model "$modell" --arg content "$auftrag" '{
                model: $model,
                messages: [
                    {role: "system", content: "Du portierst Quellcode zwischen Programmiersprachen.\n\nRegeln:\n1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine\n   Erklaerung davor oder danach, keine Code-Zaeune.\n2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein \"hier waere\",\n   kein leerer Rumpf, kein Platzhalter.\n3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.\n4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift.\n   Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.\n5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.\n6. Beginne mit der passenden Shebang-Zeile."},
                    {role: "user", content: $content}
                ],
                temperature: 0.1,
                max_tokens: 8000
            }')
            
            local response
            if response=$(curl -s -X POST "$API_URL" \
                -H "Authorization: Bearer $schluessel" \
                -H "Content-Type: application/json" \
                -H "HTTP-Referer: https://github.com/KikiKari/Projects" \
                -H "X-Title: Abstractions Manager" \
                -d "$json_body" --max-time "$ZEITLIMIT"); then
                
                local content
                content=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null)
                
                if [[ -n "$content" ]] && [[ "$content" != "null" ]]; then
                    # Code-Zäune entfernen
                    echo "$content" | sed '/^```.*$/d' | sed '/^``.*$/d'
                    return 0
                fi
                
                log_warn "$name -> $zielsprache: leere Antwort von $modell"
            else
                log_warn "$name -> $zielsprache: Fehler bei Anfrage an $modell"
            fi
            
            sleep $((2**versuch < 20 ? 2**versuch : 20))
        done
    done
    
    log_error "$name -> $zielsprache: kein Modell hat geliefert"
    return 1
}

# Erzeugnis prüfen
erzeugnis_pruefen() {
    local code="$1"
    local zielsprache="$2"
    local quelle="${3:-}"
    
    local quellzeilen=${#quelle}
    local zeilen
    zeilen=$(echo "$code" | wc -l)
    local mindestens=$((quellzeilen > 0 ? (quellzeilen/3 > 6 ? 6 : (quellzeilen/3 < 2 ? 2 : quellzeilen/3)) : 5))
    
    if [[ $zeilen -lt $mindestens ]]; then
        echo "zu kurz ($zeilen statt mindestens $mindestens Zeilen)"
        return 1
    fi
    
    # Platzhalter prüfen
    local verdacht_muster=("TODO: Implementiere" "TODO: implement" "not implemented"
                          "hier waere" "Platzhalter" "your code here" "pass  # TODO")
    
    local niedrig
    niedrig=$(echo "$quelle" | tr '[:upper:]' '[:lower:]')
    
    for muster in "${verdacht_muster[@]}"; do
        local muster_lower
        muster_lower=$(echo "$muster" | tr '[:upper:]' '[:lower:]')
        if [[ $(echo "$code" | tr '[:upper:]' '[:lower:]') == *"$muster_lower"* ]] && 
           [[ ! "$niedrig" == *"$muster_lower"* ]]; then
            echo "unfertig ($muster)"
            return 1
        fi
    done
    
    # Syntaxprüfung
    case "$zielsprache" in
        python)
            if python3 -c "compile(open('/dev/stdin').read(), '<erzeugnis>', 'exec')" <<< "$code" 2>/dev/null; then
                echo "syntax ok"
                return 0
            else
                echo "Syntaxfehler"
                return 1
            fi
            ;;
        javascript)
            if command -v node >/dev/null 2>&1; then
                if echo "$code" | node --check >/dev/null 2>&1; then
                    echo "syntax ok"
                    return 0
                else
                    echo "Syntaxfehler"
                    return 1
                fi
            else
                echo "ohne Syntaxpruefung angenommen"
                return 0
            fi
            ;;
        perl5)
            if command -v perl >/dev/null 2>&1; then
                if echo "$code" | perl -c >/dev/null 2>&1; then
                    echo "syntax ok"
                    return 0
                else
                    echo "Syntaxfehler"
                    return 1
                fi
            else
                echo "ohne Syntaxpruefung angenommen"
                return 0
            fi
            ;;
        powershell)
            if command -v pwsh >/dev/null 2>&1; then
                local tmpfile
                tmpfile=$(mktemp --suffix=.ps1)
                echo "$code" > "$tmpfile"
                if pwsh -NoProfile -Command "\$null = [ScriptBlock]::Create((Get-Content -Raw '$tmpfile'))" >/dev/null 2>&1; then
                    rm -f "$tmpfile"
                    echo "syntax ok"
                    return 0
                else
                    rm -f "$tmpfile"
                    echo "Syntaxfehler"
                    return 1
                fi
            else
                echo "ohne Syntaxpruefung angenommen"
                return 0
            fi
            ;;
        shell)
            if command -v bash >/dev/null 2>&1; then
                if echo "$code" | bash -n >/dev/null 2>&1; then
                    echo "syntax ok"
                    return 0
                else
                    echo "Syntaxfehler"
                    return 1
                fi
            else
                echo "ohne Syntaxpruefung angenommen"
                return 0
            fi
            ;;
        tcl)
            if command -v tclsh >/dev/null 2>&1; then
                local tmpfile
                tmpfile=$(mktemp --suffix=.tcl)
                echo "$code" > "$tmpfile"
                if tclsh -eval "if {[catch {info complete [read [open $tmpfile]]}]} {exit 1}" >/dev/null 2>&1; then
                    rm -f "$tmpfile"
                    echo "syntax ok"
                    return 0
                else
                    rm -f "$tmpfile"
                    echo "Syntaxfehler"
                    return 1
                fi
            else
                echo "ohne Syntaxpruefung angenommen"
                return 0
            fi
            ;;
        *)
            echo "ohne Syntaxpruefung angenommen"
            return 0
            ;;
    esac
}

# Ablage
ablegen() {
    local eintrag="$1"
    local zielsprache="$2"
    local code="$3"
    
    IFS=':' read -r hash name stem sprache size file prio herkunft <<< "$eintrag"
    
    local ext
    ext=$(echo "${ZIELSPRACHEN[$zielsprache]}" | cut -d':' -f1)
    
    local schluessel="$zielsprache/$stem"
    local vorher="${BELEGT[$schluessel]:-}"
    
    local stamm="$stem"
    if [[ -n "$vorher" ]] && [[ "$vorher" != "$hash" ]]; then
        stamm="${stem}_${hash:0:6}"
    else
        BELEGT[$schluessel]="$hash"
    fi
    
    local ziel="$ABSTRACTIONS_REPO/$zielsprache/${stamm}.${ext}"
    mkdir -p "$(dirname "$ziel")"
    
    local heute
    heute=$(date -u +%Y-%m-%d)
    
    local kopf="# $name — portiert nach $zielsprache
# Quelle: $sprache, ${herkunft%%|*}"
    
    # Weitere Herkünfte
    local herkunft_array
    IFS='|' read -ra herkunft_array <<< "$herkunft"
    local count=0
    for h in "${herkunft_array[@]:1}"; do
        if [[ $count -lt 3 ]]; then
            kopf+="
# auch in: $h"
            ((count++))
        fi
    done
    
    if [[ ${#herkunft_array[@]} -gt 4 ]]; then
        kopf+="
# auch in: $(( ${#herkunft_array[@]} - 4 )) weiteren Fundstellen"
    fi
    
    kopf+="
# Erzeugt: $heute durch ABSTRACTIONS_MANAGER.py"
    
    # Shebang behandeln
    local inhalt
    if [[ "$code" == '#!'* ]]; then
        local first_line
        first_line=$(echo "$code" | head -n1)
        local rest
        rest=$(echo "$code" | tail -n +2 | sed 's/^[[:space:]]*//')
        inhalt="$first_line
$kopf

$rest"
    else
        inhalt="$kopf
$code"
    fi
    
    echo "$inhalt" > "$ziel"
    echo "$ziel"
}

# Übersetzen
uebersetzen() {
    local prioritaet="$1"
    local anzahl="$2"
    local probelauf="$3"
    local schluessel="$4"
    
    local zaehler_erzeugt=0
    local zaehler_uebersprungen=0
    local zaehler_verworfen=0
    local zaehler_dateien=0
    
    local offen=()
    for entry in "${INVENTAR[@]}"; do
        IFS=':' read -r hash name stem sprache size file prio rest <<< "$entry"
        if [[ "$prioritaet" == "alle" ]] || [[ "$prio" == "$prioritaet" ]]; then
            offen+=("$entry")
        fi
    done
    
    log_info "Prioritaet $prioritaet: ${#offen[@]} Quelldateien im Bestand"
    
    for entry in "${offen[@]}"; do
        if [[ $zaehler_dateien -ge $anzahl ]]; then
            log_info "Kontingent von $anzahl Quelldateien erreicht"
            break
        fi
        
        IFS=':' read -r hash name stem sprache size file prio herkunft <<< "$entry"
        
        # Prüfen ob bereits erledigt
        if [[ -n "${ERLEDIGT[$hash]:-}" ]]; then
            local fertig=("${ERLEDIGT[$hash]}")
        else
            local fertig=()
        fi
        
        local ziele=()
        for ziel in "${!ZIELSPRACHEN[@]}"; do
            if [[ "$ziel" != "$sprache" ]]; then
                local gefunden=false
                for f in "${fertig[@]}"; do
                    if [[ "$f" == "$ziel" ]]; then
                        gefunden=true
                        break
                    fi
                done
                if [[ "$gefunden" == false ]]; then
                    ziele+=("$ziel")
                fi
            fi
        done
        
        if [[ ${#ziele[@]} -eq 0 ]]; then
            continue
        fi
        
        local quelle
        if ! quelle=$(<"$file"); then
            log_warn "$name nicht lesbar: $file"
            continue
        fi
        
        ((zaehler_dateien++))
        log_info "[$prio] $name ($sprache, $size B) -> ${ziele[*]}"
        
        for zielsprache in "${ziele[@]}"; do
            if [[ "$probelauf" == true ]]; then
                log_info "  $zielsprache: Probelauf, nichts gesendet"
                ((zaehler_uebersprungen++))
                continue
            fi
            
            local code
            if ! code=$(modell_fragen "$quelle" "$sprache" "$zielsprache" "$name" "$schluessel"); then
                ((zaehler_verworfen++))
                continue
            fi
            
            local grund
            if ! grund=$(erzeugnis_pruefen "$code" "$zielsprache" "$quelle" 2>&1); then
                log_warn "  $zielsprache: verworfen — $grund"
                ((zaehler_verworfen++))
                continue
            fi
            
            local ziel
            if ! ziel=$(ablegen "$entry" "$zielsprache" "$code"); then
                ((zaehler_verworfen++))
                continue
            fi
            
            log_info "  $zielsprache: $(basename "$ziel") ($grund)"
            ((zaehler_erzeugt++))
            
            # Markiere als erledigt
            ERLEDIGT[$hash]+="|$zielsprache"
        done
    done
    
    STATISTIK[erzeugt]=$zaehler_erzeugt
    STATISTIK[uebersprungen]=$zaehler_uebersprungen
    STATISTIK[verworfen]=$zaehler_verworfen
    STATISTIK[dateien]=$zaehler_dateien
}

# Bericht schreiben
bericht_schreiben() {
    if [[ ! -d "$ABSTRACTIONS_REPO" ]]; then
        log_warn "Abstraktions-Repository fehlt: $ABSTRACTIONS_REPO"
        return
    fi
    
    local status_file="$ABSTRACTIONS_REPO/STATUS.md"
    
    # Zähle Dateien pro Sprache
    declare -A je_sprache
    for sprache in "${!ZIELSPRACHEN[@]}"; do
        if [[ -d "$ABSTRACTIONS_REPO/$sprache" ]]; then
            je_sprache[$sprache]=$(find "$ABSTRACTIONS_REPO/$sprache" -type f 2>/dev/null | wc -l)
        else
            je_sprache[$sprache]=0
        fi
    done
    
    # Zähle Quellen pro Priorität
    local je_prio_high=0 je_prio_medium=0 je_prio_low=0
    for entry in "${INVENTAR[@]}"; do
        IFS=':' read -r _ _ _ _ _ _ prio _ <<< "$entry"
        case "$prio" in
            high) ((je_prio_high++)) ;;
            medium) ((je_prio_medium++)) ;;
            low) ((je_prio_low++)) ;;
        esac
    done
    
    local heute
    heute=$(date -u +%Y-%m-%d\ %H:%M)
    
    cat >"$status_file" <<EOF
# Script Abstractions — Status

**Letzter Lauf:** $heute UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
EOF
    
    local gesamt=0
    for sprache in "${!ZIELSPRACHEN[@]}"; do
        echo "| $sprache | ${je_sprache[$sprache]} |" >> "$status_file"
        ((gesamt += je_sprache[$sprache]))
    done
    echo "| **gesamt** | **$gesamt** |" >> "$status_file"
    
    cat >>"$status_file" <<EOF

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | $je_prio_high | Betriebsscripte aus scripts-Verzeichnissen |
| medium | $je_prio_medium | uebriger ausfuehrbarer Code |
| low | $je_prio_low | Markup und Stilvorlagen |
| **gesamt** | $((je_prio_high + je_prio_medium + je_prio_low)) | nach Inhalt dedupliziert |

## Letzter Lauf

- bearbeitete Quelldateien: ${STATISTIK[dateien]:-0}
- erzeugte Uebersetzungen: ${STATISTIK[erzeugt]:-0}
- verworfen: ${STATISTIK[verworfen]:-0}

## Herkunft

- \`KikiKari/OpenClaw\` — main, gateway1, gateway2
- \`KikiKari/Projects\` — alle Branches
- \`KikiKari/Onboarding\` — main

Erzeugt von \`abstractions/ABSTRACTIONS_MANAGER.py\`.
EOF

    log_info "STATUS.md fortgeschrieben"
}

# Veröffentlichen
veroeffentlichen() {
    local nachricht="$1"
    
    if [[ ! -d "$ABSTRACTIONS_REPO/.git" ]]; then
        log_info "Kein Git-Arbeitsbaum in $ABSTRACTIONS_REPO — nichts zu veroeffentlichen"
        return
    fi
    
    if [[ -z "$(_git status --porcelain --dir="$ABSTRACTIONS_REPO")" ]]; then
        log_info "Keine Aenderungen zu veroeffentlichen"
        return
    fi
    
    for sprache in "${!ZIELSPRACHEN[@]}"; do
        _git add "$sprache" --dir="$ABSTRACTIONS_REPO" 2>/dev/null || true
    done
    _git add "STATUS.md" --dir="$ABSTRACTIONS_REPO" 2>/dev/null || true
    
    if ! _git commit -m "$nachricht" --dir="$ABSTRACTIONS_REPO" 2>/dev/null; then
        log_warn "Commit fehlgeschlagen"
        return
    fi
    log_info "Commit gesetzt: $nachricht"
    
    local token="${GITHUB_TOKEN:-${ABSTRACTIONS_PUSH_TOKEN:-}}"
    if [[ -z "$token" ]]; then
        log_info "Kein Token in der Umgebung — Commit bleibt lokal"
        return
    fi
    
    local url="https://x-access-token:$token@github.com/$GITHUB_BENUTZER/OpenClaw.git"
    if _git push "$url" "HEAD:gateway1-abstractions" --dir="$ABSTRACTIONS_REPO" 2>/dev/null; then
        log_info "Nach OpenClaw@gateway1-abstractions veroeffentlicht"
    else
        log_error "Push fehlgeschlagen"
    fi
}

# Hauptfunktion
main() {
    local prioritaet=""
    local anzahl="${ABSTRACTIONS_ANZAHL:-40}"
    local probelauf=false
    
    # Argumente parsen
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
                probelauf=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    log_info "Abstractions Manager gestartet — Arbeitsverzeichnis $WORKSPACE"
    
    # API-Key prüfen
    local schluessel="${OPENROUTER_API_KEY:-}"
    schluessel=$(echo "$schluessel" | xargs) # trim whitespace
    
    if [[ "$probelauf" != true ]]; then
        if [[ -z "$schluessel" ]]; then
            log_error "OPENROUTER_API_KEY ist leer oder besteht nur aus Leerraum — ohne Schluessel keine Uebersetzung"
            return 2
        fi
        if [[ "$schluessel" != sk-or-* ]]; then
            log_error "OPENROUTER_API_KEY sieht nicht nach einem OpenRouter-Schluessel aus (${#schluessel} Zeichen) — erwartet wird sk-or-..."
            return 2
        fi
        log_info "Schluessel erkannt: ${#schluessel} Zeichen"
    fi
    
    # Zustand laden
    zustand_laden
    
    # Quellen holen
    local baeume
    mapfile -t baeume < <(quellen_holen)
    if [[ ${#baeume[@]} -eq 0 ]]; then
        log_error "Keine Quellen verfuegbar"
        return 1
    fi
    
    # Inventar bauen
    inventar_bauen "${baeume[@]}"
    if [[ ${#INVENTAR[@]} -eq 0 ]]; then
        log_error "Inventar leer"
        return 1
    fi
    
    # Priorität bestimmen
    if [[ -z "$prioritaet" ]]; then
        prioritaet="$NAECHSTE_PRIO"
    fi
    
    # Übersetzen
    uebersetzen "$prioritaet" "$anzahl" "$probelauf" "$schluessel"
    
    # Nächste Priorität setzen
    case "$prioritaet" in
        high) NAECHSTE_PRIO="medium" ;;
        medium) NAECHSTE_PRIO="low" ;;
        low) NAECHSTE_PRIO="high" ;;
        alle) NAECHSTE_PRIO="alle" ;;
    esac
    
    # Bericht schreiben
    bericht_schreiben
    
    # Zustand speichern
    zustand_speichern
    
    # Veröffentlichen
    if [[ ${STATISTIK[erzeugt]:-0} -gt 0 ]] && [[ "$probelauf" != true ]]; then
        veroeffentlichen "auto: ${STATISTIK[erzeugt]} Uebersetzungen ($prioritaet) aus ${STATISTIK[dateien]:-0} Quelldateien"
    fi
    
    log_info "Abgeschlossen: ${STATISTIK[erzeugt]:-0} erzeugt, ${STATIK[verworfen]:-0} verworfen, ${STATISTIK[dateien]:-0} Quelldateien bearbeitet"
    return 0
}

# Start
main "$@"
