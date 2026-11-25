#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "77070980c10883205edf875863eb3491fb095091af937056eee3afd2ba5b5988", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "shell"}
# test_model_usage.py — portiert nach shell
# Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Tests for model_usage helpers.

# Mock the Python modules and functions used
source "$(dirname "${BASH_SOURCE[0]}")/model_usage.sh" || {
    echo "Error: Could not load model_usage.sh" >&2
    exit 1
}

test_positive_int_accepts_valid_numbers() {
    local result
    
    result=$(positive_int "1")
    if [[ "$result" != "1" ]]; then
        echo "FAIL: positive_int '1' should return 1, got '$result'" >&2
        return 1
    fi
    
    result=$(positive_int "7")
    if [[ "$result" != "7" ]]; then
        echo "FAIL: positive_int '7' should return 7, got '$result'" >&2
        return 1
    fi
    
    echo "PASS: test_positive_int_accepts_valid_numbers"
}

test_positive_int_rejects_zero_and_negative() {
    if positive_int "0" >/dev/null 2>&1; then
        echo "FAIL: positive_int should reject '0'" >&2
        return 1
    fi
    
    if positive_int "-3" >/dev/null 2>&1; then
        echo "FAIL: positive_int should reject '-3'" >&2
        return 1
    fi
    
    echo "PASS: test_positive_int_rejects_zero_and_negative"
}

test_filter_by_days_keeps_recent_entries() {
    local today cutoff_date1 cutoff_date2
    local -a entries filtered
    
    today=$(date +%Y-%m-%d)
    cutoff_date1=$(date -d "$today - 1 day" +%Y-%m-%d)
    cutoff_date2=$(date -d "$today - 5 days" +%Y-%m-%d)
    
    # Create test data as JSON strings
    local entry1='{"date":"'$cutoff_date2'","modelBreakdowns":[]}'
    local entry2='{"date":"'$cutoff_date1'","modelBreakdowns":[]}'
    local entry3='{"date":"'$today'","modelBreakdowns":[]}'
    
    entries=("$entry1" "$entry2" "$entry3")
    
    # Filter entries (only keep last 2 days)
    mapfile -t filtered < <(filter_by_days entries 2)
    
    if [[ ${#filtered[@]} -ne 2 ]]; then
        echo "FAIL: Expected 2 entries, got ${#filtered[@]}" >&2
        return 1
    fi
    
    # Check first entry is yesterday's date
    if [[ ! "${filtered[0]}" =~ "\"date\":\"$cutoff_date1\"" ]]; then
        echo "FAIL: First entry should be from $cutoff_date1" >&2
        echo "Got: ${filtered[0]}" >&2
        return 1
    fi
    
    # Check second entry is today's date
    if [[ ! "${filtered[1]}" =~ "\"date\":\"$today\"" ]]; then
        echo "FAIL: Second entry should be from $today" >&2
        echo "Got: ${filtered[1]}" >&2
        return 1
    fi
    
    echo "PASS: test_filter_by_days_keeps_recent_entries"
}

# Run all tests
run_tests() {
    test_positive_int_accepts_valid_numbers
    test_positive_int_rejects_zero_and_negative
    test_filter_by_days_keeps_recent_entries
    echo "All tests passed!"
}

# Execute tests when script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
