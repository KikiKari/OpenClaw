#!/bin/bash
# test_external_speech_filter.cjs — portiert nach shell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Funktionen aus der JavaScript-Bibliothek simulieren

# shouldFilterExternalSpeechTrigger
filter() {
    local text="$1"
    local enabled="$2"
    local prefixes="${3:-.}" # Standardwert ist "."

    if [[ "$enabled" != "true" ]]; then
        echo "false"
        return
    fi

    # Entferne führende Leerzeichen
    local trimmed_text="${text#"${text%%[![:space:]]*}"}"

    # Prüfe, ob der Text mit einem der Präfixe beginnt
    case "$prefixes" in
        *"."*)
            if [[ "$trimmed_text" == .* ]]; then
                echo "true"
                return
            fi
            ;;
        *","*)
            if [[ "$trimmed_text" == ,* ]]; then
                echo "true"
                return
            fi
            ;;
        *"-"*)
            if [[ "$trimmed_text" == -* ]]; then
                echo "true"
                return
            fi
            ;;
        *";"*)
            if [[ "$trimmed_text" == \;* ]]; then
                echo "true"
                return
            fi
            ;;
        *"["*)
            if [[ "$trimmed_text" == [* ]]; then
                echo "true"
                return
            fi
            ;;
        *)
            if [[ "$trimmed_text" == .* ]]; then
                echo "true"
                return
            fi
            ;;
    esac

    echo "false"
}

# normalizeExternalSpeechTriggerCharacters
normalize() {
    local input="$1"

    if [[ -z "$input" ]]; then
        if [[ "$input" == "" ]]; then
            echo ""
        else
            echo "."
        fi
        return
    fi

    # Entferne alle Zeichen außer .,-;:! und Emojis (vereinfacht)
    local result=""
    local i=0
    while [[ $i -lt ${#input} ]]; do
        char="${input:$i:1}"
        case "$char" in
            "."|","|"-"|";"|":"|"!")
                result+="$char"
                ;;
            "\""|"'"|" ")
                # Ignoriere diese Zeichen
                ;;
            *)
                # Füge andere Zeichen hinzu (vereinfachte Emoji-Behandlung)
                result+="$char"
                ;;
        esac
        ((i++))
    done

    # Kürze auf maximal 5 Zeichen
    echo "${result:0:5}"
}

# Testfälle ausführen
run_tests() {
    local failed=0

    # Erster Testsatz
    for enabled in false true; do
        for text in ".Text" ". Text" "  .Text" $'\t\n. Text' "Normal" "Ein Satz. Noch einer" ""; do
            expected="false"
            if [[ "$enabled" == "true" ]] && [[ "${text#"${text%%[![:space:]]*}"}" == .* ]]; then
                expected="true"
            fi
            
            result=$(filter "$text" "$enabled")
            if [[ "$result" != "$expected" ]]; then
                echo "FAIL: filter($text,$enabled) = $result, expected $expected"
                ((failed++))
            fi
        done
    done

    # Zweiter Testsatz (0PE-187)
    for enabled in false true; do
        # Teste Präfixe
        for text in ".Hallo" ",Hallo" "- Hallo" "  , Hallo"; do
            result=$(filter "$text" "$enabled" ".,-")
            expected="false"
            if [[ "$enabled" == "true" ]]; then
                expected="true"
            fi
            if [[ "$result" != "$expected" ]]; then
                echo "FAIL: filter($text,$enabled,.,-) = $result, expected $expected"
                ((failed++))
            fi
        done
        
        # Negative Tests
        for text in "Hallo, zusammen." "Normal-Text" "Hallo" "."; do
            result=$(filter "$text" "$enabled" ",-")
            if [[ "$result" != "false" ]]; then
                echo "FAIL: filter($text,$enabled,,-) = $result, expected false"
                ((failed++))
            fi
        done
        
        # Spezielle Zeichen
        result=$(filter ";Hallo" "$enabled" ";")
        expected="false"
        if [[ "$enabled" == "true" ]]; then
            expected="true"
        fi
        if [[ "$result" != "$expected" ]]; then
            echo "FAIL: filter(;Hallo,$enabled,;) = $result, expected $expected"
            ((failed++))
        fi
        
        result=$(filter "[Hallo" "$enabled" "[")
        expected="false"
        if [[ "$enabled" == "true" ]]; then
            expected="true"
        fi
        if [[ "$result" != "$expected" ]]; then
            echo "FAIL: filter([Hallo,$enabled,[) = $result, expected $expected"
            ((failed++))
        fi
        
        result=$(filter "Hallo" "$enabled" "[")
        if [[ "$result" != "false" ]]; then
            echo "FAIL: filter(Hallo,$enabled,[) = $result, expected false"
            ((failed++))
        fi
    done

    # Dritter Testsatz (0PE-187)
    result=$(normalize "")
    if [[ "$result" != "" ]]; then
        echo "FAIL: normalize(\"\") = $result, expected \"\""
        ((failed++))
    fi
    
    result=$(normalize ".,-;:!")
    if [[ "$result" != ".,-;:" ]]; then
        echo "FAIL: normalize(.,-;:!) = $result, expected .,-;:"
        ((failed++))
    fi
    
    result=$(normalize " a1 \"'.,- ")
    if [[ "$result" != ".,-" ]]; then
        echo "FAIL: normalize( a1 \"'.,- ) = $result, expected .,-"
        ((failed++))
    fi
    
    result=$(normalize "😀😁😂😃😄😅")
    if [[ "$result" != "😀😁😂😃😄" ]]; then
        echo "FAIL: normalize(😀😁😂😃😄😅) = $result, expected 😀😁😂😃😄"
        ((failed++))
    fi
    
    result=$(filter "😀Hallo" "true" "😀")
    if [[ "$result" != "true" ]]; then
        echo "FAIL: filter(😀Hallo,true,😀) = $result, expected true"
        ((failed++))
    fi
    
    result=$(filter ".Hallo" "true" "")
    if [[ "$result" != "false" ]]; then
        echo "FAIL: filter(.Hallo,true,) = $result, expected false"
        ((failed++))
    fi
    
    result=$(filter ".Hallo" "true" ",")
    if [[ "$result" != "false" ]]; then
        echo "FAIL: filter(.Hallo,true,,) = $result, expected false"
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        echo "$failed tests failed"
        exit 1
    else
        echo "All tests passed"
    fi
}

run_tests
