#!/usr/bin/env bash
# tiktok-common.test.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Mocking Node.js style assertions and functions in Bash
# We'll implement the test logic directly with Bash equivalents

# Source the common functions (assuming they are available as shell functions)
source ./tiktok-common.sh

# Test normalizeUsername
echo "Testing normalizeUsername..."
test_normalize_username() {
    local input="$1"
    local expected="$2"
    local result
    result=$(normalizeUsername "$input")
    if [[ "$result" != "$expected" ]]; then
        echo "FAIL: normalizeUsername('$input') = '$result', expected '$expected'"
        return 1
    fi
    echo "PASS: normalizeUsername('$input')"
}

test_normalize_username '@example_creator' 'example_creator'
test_normalize_username ' example_creator ' 'example_creator'

# This should fail, so we check for failure
if normalizeUsername 'example_creator;id' >/dev/null 2>&1; then
    echo "FAIL: normalizeUsername should have failed on 'example_creator;id'"
    return 1
else
    echo "PASS: normalizeUsername correctly rejected invalid input"
fi

# Test liveHrefSelectors
echo "Testing liveHrefSelectors..."
test_live_href_selectors() {
    local username="example_creator"
    local expected1='a[href="/@example_creator/live"]'
    local expected2='a[href^="/@example_creator/live?"]'
    local results
    mapfile -t results < <(liveHrefSelectors "$username")
    if [[ "${results[0]}" != "$expected1" ]] || [[ "${results[1]}" != "$expected2" ]]; then
        echo "FAIL: liveHrefSelectors did not return expected selectors"
        echo "Got: ${results[*]}"
        return 1
    fi
    echo "PASS: liveHrefSelectors"
}

test_live_href_selectors

# Test loadState
echo "Testing loadState..."
test_load_state() {
    export TIKTOK_TEST_LOAD_PER_CPU='2'
    export TIKTOK_MAX_LOAD_PER_CPU='1.5'
    local result
    result=$(loadState)
    if [[ ! "$result" =~ "overloaded=true" ]]; then
        echo "FAIL: loadState should indicate overloaded=true"
        echo "Got: $result"
        return 1
    fi
    echo "PASS: loadState indicates overload correctly"
    unset TIKTOK_TEST_LOAD_PER_CPU TIKTOK_MAX_LOAD_PER_CPU
}

test_load_state

# Test isAllowedStreamUrl
echo "Testing isAllowedStreamUrl..."
test_is_allowed_stream_url() {
    local url="$1"
    local expected="$2"
    local result
    result=$(isAllowedStreamUrl "$url"; echo $?)
    # isAllowedStreamUrl returns 0 for true, 1 for false
    if [[ "$result" == "0" && "$expected" == "true" ]] || [[ "$result" == "1" && "$expected" == "false" ]]; then
        echo "PASS: isAllowedStreamUrl('$url')"
    else
        echo "FAIL: isAllowedStreamUrl('$url') returned unexpected result"
        return 1
    fi
}

test_is_allowed_stream_url 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x' true
test_is_allowed_stream_url 'https://attacker.example/path/tiktokcdn/video.flv' false
test_is_allowed_stream_url 'http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv' false

# Test isSuccessfulStreamResponse
echo "Testing isSuccessfulStreamResponse..."
test_is_successful_stream_response() {
    local code="$1"
    local url="$2"
    local expected="$3"
    local result
    result=$(isSuccessfulStreamResponse "$code" "$url"; echo $?)
    if [[ "$result" == "0" && "$expected" == "true" ]] || [[ "$result" == "1" && "$expected" == "false" ]]; then
        echo "PASS: isSuccessfulStreamResponse($code, ...)"
    else
        echo "FAIL: isSuccessfulStreamResponse($code, ...) returned unexpected result"
        return 1
    fi
}

allowedUrl='https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'
test_is_successful_stream_response 200 "$allowedUrl" true
test_is_successful_stream_response 206 "$allowedUrl" true
test_is_successful_stream_response 404 "$allowedUrl" false

# Test normalizeExtractorResult
echo "Testing normalizeExtractorResult..."
test_normalize_extractor_result() {
    local json_input="$1"
    local extractor="$2"
    local username="$3"
    local expected_status="$4"
    local result
    result=$(normalizeExtractorResult "$json_input" "$extractor" "$username")
    if [[ "$result" =~ "\"status\":\"$expected_status\"" ]]; then
        echo "PASS: normalizeExtractorResult status=$expected_status"
    else
        echo "FAIL: normalizeExtractorResult did not return expected status"
        echo "Expected: $expected_status"
        echo "Got: $result"
        return 1
    fi
}

# Test case where success is 'false' and status is 'offline'
test_normalize_extractor_result '{"success": "false", "status": "offline"}' streamlink example_creator technical_error
test_normalize_extractor_result '{"success": true, "status": "live"}' streamlink example_creator technical_error

# Test offline result
json_offline='{"success": false, "status": "offline", "url": "'"$allowedUrl"'"}'
result_offline=$(normalizeExtractorResult "$json_offline" streamlink example_creator)
if [[ "$result_offline" =~ "\"status\":\"offline\"" ]] && ! [[ "$result_offline" =~ "\"url\":" ]]; then
    echo "PASS: normalizeExtractorResult offline result correct"
else
    echo "FAIL: normalizeExtractorResult offline result incorrect"
    echo "Got: $result_offline"
    return 1
fi

# Test live result
json_live='{"success": true, "status": "live", "url": "'"$allowedUrl"'"}'
test_normalize_extractor_result "$json_live" streamlink example_creator live

# Test classifyFinalFailure
echo "Testing classifyFinalFailure..."
test_classify_final_failure() {
    local json_array="$1"
    local expected="$2"
    local result
    result=$(classifyFinalFailure "$json_array")
    if [[ "$result" == "$expected" ]]; then
        echo "PASS: classifyFinalFailure = $expected"
    else
        echo "FAIL: classifyFinalFailure returned unexpected result"
        echo "Expected: $expected"
        echo "Got: $result"
        return 1
    fi
}

test_classify_final_failure '[{"status": "offline"}, {"status": "dependency_missing"}]' offline

# Test exitCodeForResult
echo "Testing exitCodeForResult..."
test_exit_code_for_result() {
    local json_input="$1"
    local expected="$2"
    local result
    result=$(exitCodeForResult "$json_input")
    if [[ "$result" == "$expected" ]]; then
        echo "PASS: exitCodeForResult = $expected"
    else
        echo "FAIL: exitCodeForResult returned unexpected result"
        echo "Expected: $expected"
        echo "Got: $result"
        return 1
    fi
}

test_exit_code_for_result '{"success": false, "status": "restricted"}' 1
test_exit_code_for_result '{"success": false, "status": "technical_error"}' 2

# Test classifyDirectLiveState
echo "Testing classifyDirectLiveState..."
test_classify_direct_live_state() {
    local json_input="$1"
    local expected_status="$2"
    local result
    result=$(classifyDirectLiveState "$json_input")
    if [[ "$result" =~ "\"status\":\"$expected_status\"" ]]; then
        echo "PASS: classifyDirectLiveState status=$expected_status"
    else
        echo "FAIL: classifyDirectLiveState did not return expected status"
        echo "Expected: $expected_status"
        echo "Got: $result"
        return 1
    fi
}

# Restricted case
json_restricted='{
    "username": "example_creator",
    "currentPath": "/@example_creator/live",
    "title": "Example (@example_creator) is LIVE - TikTok LIVE",
    "bodyText": "Dieses LIVE enthält Themen, die unangenehm sein könnten.",
    "successfulStreamResponse": false
}'
test_classify_direct_live_state "$json_restricted" restricted

# Offline case
json_offline_direct='{
    "username": "example_creator",
    "currentPath": "/@example_creator/live",
    "title": "Example (@example_creator) is LIVE - TikTok LIVE",
    "bodyText": "LIVE has ended",
    "successfulStreamResponse": false
}'
test_classify_direct_live_state "$json_offline_direct" offline

# Live case
json_live_direct='{
    "username": "example_creator",
    "currentPath": "/@example_creator/live",
    "title": "Example (@example_creator) is LIVE - TikTok LIVE",
    "bodyText": "Suggested LIVE creators",
    "successfulStreamResponse": true
}'
test_classify_direct_live_state "$json_live_direct" live

# Note: The Playwright test cannot be replicated in Bash without significant effort,
#       since it requires a real browser environment. We skip this part.

echo "All tests passed."
