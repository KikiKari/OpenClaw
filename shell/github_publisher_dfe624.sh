#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "485ca6942528be8e00db5458433e3b00d2c4cba5f4cce194e53d286272642bc7", "source_sha256": "dfe62418dcbef9ea8aa7f18ada4f57d0ef73593432b7c7cefd85ee87eee622b4", "target_language": "shell"}
# github_publisher.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
declare -A LANGUAGES=([perl5]=1 [powershell]=1 [perl6]=1 [tcl]=1 [javascript]=1 [ruby]=1 [python]=1 [lua]=1 [shell]=1 [go]=1 [java]=1 [c]=1 [cpp]=1 [php]=1 [fsharp]=1 [css]=1)

# Funktion zur Synchronisation des Checkouts
synchronize_checkout() {
    local root="$1"
    local remote="${2:-https://github.com/KikiKari/OpenClaw.git}"
    local branch="${3:-gateway1-abstractions}"
    
    # Erstelle temporäres Verzeichnis
    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/abstractions-snapshot-XXXXXX")
    local snapshot="$tmp/repo"
    
    # Clone Repository
    git clone --quiet --depth=1 --single-branch --branch "$branch" -- "$remote" "$snapshot" &>/dev/null || {
        rm -rf "$tmp"
        return 1
    }
    
    # Hole Revision
    local revision
    revision=$(git -C "$snapshot" rev-parse HEAD) || {
        rm -rf "$tmp"
        return 1
    }
    
    declare -A counts
    
    # Iteriere durch Sprachen
    for language in $(printf '%s\n' "${!LANGUAGES[@]}" | sort); do
        local source="$snapshot/$language"
        local target="$root/$language"
        
        # Prüfe auf Symlinks
        if [[ -L "$source" ]] || [[ -L "$target" ]]; then
            echo "Fehler: Sprachverzeichnis ist ein Symlink" >&2
            rm -rf "$tmp"
            return 1
        fi
        
        # Prüfe Quellverzeichnis
        if [[ -e "$source" ]] && [[ ! -d "$source" ]]; then
            echo "Fehler: Ungültiges Remote-Sprachverzeichnis" >&2
            rm -rf "$tmp"
            return 1
        fi
        
        # Erstelle Zielverzeichnis
        mkdir -p "$target"
        
        # Sammle bekannte Hashes
        declare -A known
        if [[ -d "$target" ]]; then
            while IFS= read -r -d '' file; do
                if [[ ! -L "$file" ]] && [[ -f "$file" ]]; then
                    local hash
                    hash=$(sha256sum < "$file" | cut -d' ' -f1)
                    known["$hash"]=1
                fi
            done < <(find "$target" -maxdepth 1 -type f -print0 2>/dev/null || true)
        fi
        
        # Verarbeite Dateien
        local files=()
        if [[ -d "$source" ]]; then
            while IFS= read -r -d '' file; do
                if [[ -L "$file" ]] || [[ ! -f "$file" ]]; then
                    echo "Fehler: Ungültige Remote-Abstraktion" >&2
                    rm -rf "$tmp"
                    return 1
                fi
                files+=("$file")
            done < <(find "$source" -maxdepth 1 -type f -print0 2>/dev/null || true)
        fi
        
        # Sortiere Dateien
        IFS=$'\n' files=($(sort <<<"${files[*]}"))
        unset IFS
        
        counts["$language"]="${#files[@]}"
        
        # Kopiere neue Dateien
        for item in "${files[@]}"; do
            local filename
            filename=$(basename "$item")
            local data
            data=$(cat "$item")
            
            # Berechne Hash
            local digest
            digest=$(echo -n "$data" | sha256sum | cut -d' ' -f1)
            
            # Überspringe bekannte Dateien
            if [[ -n "${known[$digest]:-}" ]]; then
                continue
            fi
            
            local destination="$target/$filename"
            
            # Prüfe auf Namenskonflikte
            if [[ -e "$destination" ]] || [[ -L "$destination" ]]; then
                local stem="${filename%.*}"
                local suffix=""
                if [[ "$filename" != "$stem" ]]; then
                    suffix=".${filename##*.}"
                fi
                destination="$target/${stem}__pool_${digest}${suffix}"
            fi
            
            # Schreibe Datei
            if [[ -e "$destination" ]] || [[ -L "$destination" ]]; then
                local existing_data
                existing_data=$(cat "$destination")
                if [[ "$existing_data" != "$data" ]]; then
                    echo "Fehler: Lokaler Abstraktionskonflikt" >&2
                    rm -rf "$tmp"
                    return 1
                fi
            else
                echo -n "$data" > "$destination"
            fi
            
            known["$digest"]=1
        done
    done
    
    # Rückgabe
    echo "$revision"
    for lang in $(printf '%s\n' "${!LANGUAGES[@]}" | sort); do
        echo "${counts[$lang]:-0}"
    done
    
    rm -rf "$tmp"
    return 0
}

# Funktion zum Aktualisieren der Statuszähler
update_status_counts() {
    local path="$1"
    local revision="$2"
    shift 2
    local counts=("$@")
    
    # Lese Dateiinhalt
    local text
    text=$(cat "$path")
    
    # Erstelle neue Zeilen
    local rows=(
        "## Bestand"
        ""
        "GitHub-Stand: \`$revision\`"
        ""
        "| Zielsprache | Dateien |"
        "|---|---:|"
    )
    
    local i=0
    for language in $(printf '%s\n' "${!LANGUAGES[@]}" | sort); do
        rows+=("| $language | ${counts[$i]:-0} |")
        ((i++))
    done
    
    local total=0
    for count in "${counts[@]}"; do
        ((total += count))
    done
    
    rows+=(
        "| **gesamt** | **$total** |"
        ""
        ""
    )
    
    # Ersetze Abschnitt im Text
    local new_text=""
    local in_section=false
    local replaced=false
    
    while IFS= read -r line; do
        if [[ "$line" == "## Bestand" ]]; then
            in_section=true
            if [[ "$replaced" == false ]]; then
                printf '%s\n' "${rows[@]}"
                replaced=true
            fi
            continue
        elif [[ "$in_section" == true ]] && [[ "$line" == "## Quellen" ]]; then
            in_section=false
            echo "$line"
        elif [[ "$in_section" == false ]]; then
            echo "$line"
        fi
    done <<< "$text"
    
    if [[ "$replaced" == false ]]; then
        echo "Fehler: Status-Bestandsabschnitt fehlt" >&2
        return 1
    fi
}

# Funktion zum Einreihen eines Artefakts
queue_artifact() {
    local state_ref="$1"
    local root="$2"
    local path="$3"
    
    # Prüfe auf Symlink
    if [[ -L "$path" ]]; then
        echo "Fehler: Artefakt darf kein Symlink sein" >&2
        return 1
    fi
    
    # Bestimme relativen Pfad
    local absolute_path
    absolute_path=$(realpath "$path")
    local root_absolute
    root_absolute=$(realpath "$root")
    
    local relative
    relative=$(realpath --relative-to="$root_absolute" "$absolute_path")
    
    # Prüfe Pfad
    if [[ "$relative" != "STATUS.md" ]]; then
        if [[ -z "$relative" ]] || [[ ! "${LANGUAGES[${relative%%/*}]:-}" ]]; then
            echo "Fehler: Artefakt befindet sich außerhalb eines Sprachverzeichnisses" >&2
            return 1
        fi
    fi
    
    # Berechne Hash
    local hash
    hash=$(sha256sum < "$path" | cut -d' ' -f1)
    
    # Füge zur Warteschlange hinzu
    eval "$state_ref['ausstehende_veroeffentlichungen'][\"$relative\"]=\"$hash\""
}

# Funktion zur Veröffentlichung ausstehender Elemente
publish_pending() {
    local root="$1"
    local state_ref="$2"
    local save_func="$3"
    local token="$4"
    
    # Prüfe Token
    if [[ -z "${token:-}" ]] || [[ -z "${token// /}" ]]; then
        return 1
    fi
    
    # Lese Warteschlange
    eval "declare -A pending=(\"\${${state_ref}_ausstehende_veroeffentlichungen[@]}\")"
    
    # Prüfe Warteschlange
    if [[ "${#pending[@]}" -eq 0 ]]; then
        return 0
    fi
    
    local root_absolute
    root_absolute=$(realpath "$root")
    
    # Header für API-Anfragen
    local headers=(
        "Authorization: Bearer $token"
        "Accept: application/vnd.github+json"
        "X-GitHub-Api-Version: 2022-11-28"
        "User-Agent: abstractions-manager"
    )
    
    local success=0
    
    # Sortiere Einträge (STATUS.md zuletzt)
    local entries=()
    local status_entry=""
    
    for key in "${!pending[@]}"; do
        if [[ "$key" == "STATUS.md" ]]; then
            status_entry="$key:${pending[$key]}"
        else
            entries+=("$key:${pending[$key]}")
        fi
    done
    
    if [[ -n "$status_entry" ]]; then
        entries+=("$status_entry")
    fi
    
    local synced=0
    
    # Verarbeite Einträge
    for entry in "${entries[@]}"; do
        local name="${entry%%:*}"
        local expected="${entry#*:}"
        
        # Prüfe Pfad
        local path="$root_absolute/$name"
        if [[ -L "$path" ]]; then
            echo "Fehler: Ungültiger eingereihter Pfad" >&2
            success=1
            continue
        fi
        
        local path_absolute
        path_absolute=$(realpath "$path")
        local relative_check
        relative_check=$(realpath --relative-to="$root_absolute" "$path_absolute" 2>/dev/null || echo "")
        
        if [[ "$relative_check" != "$name" ]]; then
            echo "Fehler: Ungültiger eingereihter Pfad" >&2
            success=1
            continue
        fi
        
        # Prüfe Hash
        local data
        data=$(cat "$path")
        local actual_hash
        actual_hash=$(echo -n "$data" | sha256sum | cut -d' ' -f1)
        
        if [[ "$actual_hash" != "$expected" ]]; then
            echo "Fehler: Eingereihtes Artefakt hat sich geändert" >&2
            success=1
            continue
        fi
        
        # Synchronisiere bei STATUS.md
        if [[ "$name" == "STATUS.md" ]]; then
            if [[ $success -ne 0 ]]; then
                echo "Fehler: Artefaktveröffentlichung unvollständig" >&2
                success=1
                continue
            fi
            
            # Führe Synchronisation durch
            mapfile -t sync_result < <(synchronize_checkout "$root_absolute")
            local revision="${sync_result[0]}"
            local counts=("${sync_result[@]:1}")
            
            synced=1
            
            # Aktualisiere Status
            update_status_counts "$path" "$revision" "${counts[@]}"
            
            # Lese aktualisierte Daten
            data=$(cat "$path")
            expected=$(echo -n "$data" | sha256sum | cut -d' ' -f1)
            eval "$state_ref['_ausstehende_veroeffentlichungen'][\"$name\"]=\"$expected\""
            "$save_func" "$state_ref"
        fi
        
        # Lookup-Funktion für GitHub-API
        lookup() {
            local remote_name="$1"
            local encoded_name
            encoded_name=$(printf '%s' "$remote_name" | sed 's/\//%2F/g')
            local endpoint="https://api.github.com/repos/KikiKari/OpenClaw/contents/$encoded_name"
            
            # Führe GET-Anfrage durch
            local response
            response=$(curl -s -H "${headers[0]}" -H "${headers[1]}" -H "${headers[2]}" -H "${headers[3]}" \
                "$endpoint?ref=gateway1-abstractions" 2>/dev/null || echo "{}")
            
            # Prüfe auf 404
            if [[ "$response" == *"404"* ]] || [[ "$response" == *"Not Found"* ]]; then
                echo "{}"
            else
                echo "$response"
            fi
        }
        
        # Prüfe Existenz-Funktion
        same() {
            local existing="$1"
            if [[ "$existing" == "{}" ]] || [[ -z "$existing" ]]; then
                return 1
            fi
            
            # Extrahiere encoding und content
            local encoding
            encoding=$(echo "$existing" | grep -o '"encoding":"[^"]*"' | cut -d'"' -f4)
            local content
            content=$(echo "$existing" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
            
            if [[ "$encoding" != "base64" ]]; then
                return 1
            fi
            
            # Dekodiere Content
            local decoded_content
            decoded_content=$(echo "$content" | base64 -d)
            
            if [[ "$decoded_content" != "$data" ]]; then
                return 1
            fi
            
            return 0
        }
        
        # Hole existierende Datei
        local existing_response
        existing_response=$(lookup "$name")
        
        # Prüfe auf Konflikt bei STATUS.md
        if [[ "$name" == "STATUS.md" ]] && [[ "$existing_response" != "{}" ]] && ! same "$existing_response"; then
            # Extrahiere SHA
            local sha
            sha=$(echo "$existing_response" | grep -o '"sha":"[^"]*"' | cut -d'"' -f4)
            
            if [[ -z "$sha" ]]; then
                echo "Fehler: Fehlende Remote-Statusversion" >&2
                success=1
                continue
            fi
            
            # Kodiere Daten
            local encoded_data
            encoded_data=$(echo -n "$data" | base64)
            
            # Erstelle PUT-Anfrage
            local put_data
            put_data="{\"message\":\"Update abstraction status\",\"branch\":\"gateway1-abstractions\",\"content\":\"$encoded_data\",\"sha\":\"$sha\"}"
            
            # Führe PUT-Anfrage durch
            curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -H "${headers[2]}" -H "${headers[3]}" \
                -d "$put_data" "https://api.github.com/repos/KikiKari/OpenClaw/contents/$name" >/dev/null 2>&1 || {
                echo "Fehler bei PUT-Anfrage" >&2
                success=1
                continue
            }
        elif [[ "$existing_response" != "{}" ]] && ! same "$existing_response"; then
            # Erstelle alternativen Namen
            local candidate="$name"
            local stem="${candidate%.*}"
            local suffix=""
            if [[ "$candidate" != "$stem" ]]; then
                suffix=".${candidate##*.}"
            fi
            local alternate="${stem}_${expected:0:12}${suffix}"
            
            # Prüfe alternativen Namen
            local alt_existing
            alt_existing=$(lookup "$alternate")
            
            if [[ "$alt_existing" != "{}" ]] && ! same "$alt_existing"; then
                echo "Fehler: Remote-Artefaktkonflikt" >&2
                success=1
                continue
            fi
        fi
        
        # Erstelle neue Datei wenn nicht existent
        if [[ "$existing_response" == "{}" ]] || [[ -z "$existing_response" ]]; then
            # Kodiere Daten
            local encoded_data
            encoded_data=$(echo -n "$data" | base64)
            
            # Erstelle PUT-Anfrage
            local put_data
            put_data="{\"message\":\"Publish script abstraction\",\"branch\":\"gateway1-abstractions\",\"content\":\"$encoded_data\"}"
            
            # Führe PUT-Anfrage durch
            curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" -H "${headers[2]}" -H "${headers[3]}" \
                -d "$put_data" "https://api.github.com/repos/KikiKari/OpenClaw/contents/$name" >/dev/null 2>&1 || {
                echo "Fehler bei PUT-Anfrage" >&2
                success=1
                continue
            }
        fi
        
        # Entferne aus Warteschlange
        unset "pending[$name]"
        eval "$state_ref['_ausstehende_veroeffentlichungen']=(\"\${pending[@]}\")"
        "$save_func" "$state_ref"
    done
    
    # Synchronisiere falls noch nicht geschehen
    if [[ $synced -eq 0 ]]; then
        synchronize_checkout "$root_absolute" >/dev/null 2>&1 || success=1
    fi
    
    return $success
}
