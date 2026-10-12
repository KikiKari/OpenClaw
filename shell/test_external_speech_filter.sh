#!/bin/bash
# test_external_speech_filter.cjs — portiert nach shell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Funktion zur Überprüfung, ob ein Text gefiltert werden soll
should_filter_external_speech_trigger() {
    local text="$1"
    local enabled="$2"
    
    # Wenn nicht aktiviert, nie filtern
    if [[ "$enabled" != "true" ]]; then
        return 1  # false
    fi
    
    # Text trimmen und prüfen, ob er mit '.' beginnt
    local trimmed_text="${text#"${text%%[![:space:]]*}"}"  # ltrim
    if [[ "$trimmed_text" == .* ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Testfälle durchführen
run_test() {
    local enabled="$1"
    local text="$2"
    local expected="$3"
    
    local result=1
    should_filter_external_speech_trigger "$text" "$enabled" && result=0 || result=1
    
    if [[ "$result" -eq "$expected" ]]; then
        echo "PASS: {\"enabled\":\"$enabled\",\"text\":\"$text\"}"
    else
        echo "FAIL: {\"enabled\":\"$enabled\",\"text\":\"$text\"} - expected $expected, got $result"
        exit 1
    fi
}

# Alle Kombinationen testen
for enabled in false true; do
    for text in ".Text" ". Text" "  .Text" $'\t\n. Text' "Normal" "Ein Satz. Noch einer" ""; do
        # Erwartetes Ergebnis berechnen
        expected=1  # Standardmäßig false
        if [[ "$enabled" == "true" ]]; then
            # Text trimmen
            trimmed_text="${text#"${text%%[![:space:]]*}"}"
            if [[ "$trimmed_text" == .* ]]; then
                expected=0  # true
            fi
        fi
        
        run_test "$enabled" "$text" "$expected"
    done
done
