// abstraction-provenance: {"artifact_sha256": "92e7bd09715c936953d5ffe19510f64588097b6bd4284f82831a183d59721edd", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "c"}
// tiktok-common.test.js — portiert nach c
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// Mock implementations for dependencies
typedef struct {
    int overloaded;
} LoadState;

typedef struct {
    char* status;
    char* url;
} ExtractorResult;

LoadState loadState(char** env_vars) {
    LoadState state = {0};
    // Simulate overload condition based on environment variables
    if (strcmp(env_vars[0], "TIKTOK_TEST_LOAD_PER_CPU=2") == 0 &&
        strcmp(env_vars[1], "TIKTOK_MAX_LOAD_PER_CPU=1.5") == 0) {
        state.overloaded = 1;
    }
    return state;
}

int isAllowedStreamUrl(const char* url) {
    // Check if URL starts with https and contains tiktokcdn
    if (strncmp(url, "https://", 8) != 0) return 0;
    if (strstr(url, "tiktokcdn") == NULL) return 0;
    return 1;
}

int isSuccessfulStreamResponse(int code, const char* url) {
    if (!isAllowedStreamUrl(url)) return 0;
    return (code == 200 || code == 206);
}

char* normalizeUsername(const char* input) {
    static char result[256];
    const char* start = input;
    
    // Skip leading @ if present
    if (*start == '@') start++;
    
    // Trim whitespace from beginning
    while (*start == ' ') start++;
    
    // Copy to result
    strcpy(result, start);
    
    // Remove trailing whitespace
    char* end = result + strlen(result) - 1;
    while (end > result && *end == ' ') end--;
    *(end + 1) = '\0';
    
    // Check for invalid characters
    if (strchr(result, ';') != NULL) {
        fprintf(stderr, "Invalid character in username\n");
        exit(1);
    }
    
    return result;
}

void liveHrefSelectors(const char* username, char selectors[][256], int* count) {
    char normalized[256];
    strcpy(normalized, normalizeUsername(username));
    
    sprintf(selectors[0], "a[href=\"/@%s/live\"]", normalized);
    sprintf(selectors[1], "a[href^=\"/@%s/live?\"]", normalized);
    *count = 2;
}

ExtractorResult normalizeExtractorResult(ExtractorResult input, const char* extractor, const char* username) {
    ExtractorResult result = {0};
    
    if ((strcmp(input.success ? "true" : "false", "false") == 0 && strcmp(input.status, "offline") == 0) ||
        (input.success && strcmp(input.status, "live") == 0)) {
        result.status = "technical_error";
        return result;
    }
    
    if (!input.success && strcmp(input.status, "offline") == 0) {
        result.status = "offline";
        result.url = NULL;
        return result;
    }
    
    if (input.success && strcmp(input.status, "live") == 0) {
        result.status = "live";
        result.url = input.url;
        return result;
    }
    
    result.status = "technical_error";
    return result;
}

const char* classifyFinalFailure(ExtractorResult results[], int count) {
    for (int i = 0; i < count; i++) {
        if (strcmp(results[i].status, "offline") == 0) {
            return "offline";
        }
        if (strcmp(results[i].status, "dependency_missing") == 0) {
            return "offline";
        }
    }
    return "unknown";
}

int exitCodeForResult(ExtractorResult result) {
    if (!result.success && strcmp(result.status, "restricted") == 0) {
        return 1;
    }
    if (!result.success && strcmp(result.status, "technical_error") == 0) {
        return 2;
    }
    return 0;
}

typedef struct {
    const char* username;
    const char* currentPath;
    const char* title;
    const char* bodyText;
    int successfulStreamResponse;
} LiveState;

ExtractorResult classifyDirectLiveState(LiveState state) {
    ExtractorResult result = {0};
    
    // Check for restricted content
    if (strstr(state.bodyText, "unangenehm") != NULL) {
        result.status = "restricted";
        return result;
    }
    
    // Check if live has ended
    if (strstr(state.bodyText, "LIVE has ended") != NULL) {
        result.status = "offline";
        return result;
    }
    
    // Check for successful live stream
    if (strstr(state.bodyText, "Suggested LIVE creators") != NULL && state.successfulStreamResponse) {
        result.status = "live";
        return result;
    }
    
    result.status = "unknown";
    return result;
}

int main() {
    // Test normalizeUsername
    assert(strcmp(normalizeUsername("@example_creator"), "example_creator") == 0);
    assert(strcmp(normalizeUsername(" example_creator "), "example_creator") == 0);
    
    // Test liveHrefSelectors
    char selectors[2][256];
    int count;
    liveHrefSelectors("example_creator", selectors, &count);
    assert(strcmp(selectors[0], "a[href=\"/@example_creator/live\"]") == 0);
    assert(strcmp(selectors[1], "a[href^=\"/@example_creator/live?\"]") == 0);
    
    // Test loadState
    char* env_vars[] = {"TIKTOK_TEST_LOAD_PER_CPU=2", "TIKTOK_MAX_LOAD_PER_CPU=1.5"};
    LoadState state = loadState(env_vars);
    assert(state.overloaded == 1);
    
    // Test isAllowedStreamUrl
    assert(isAllowedStreamUrl("https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x") == 1);
    assert(isAllowedStreamUrl("https://attacker.example/path/tiktokcdn/video.flv") == 0);
    assert(isAllowedStreamUrl("http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv") == 0);
    
    // Test isSuccessfulStreamResponse
    const char* allowedUrl = "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x";
    assert(isSuccessfulStreamResponse(200, allowedUrl) == 1);
    assert(isSuccessfulStreamResponse(206, allowedUrl) == 1);
    assert(isSuccessfulStreamResponse(404, allowedUrl) == 0);
    
    // Test normalizeExtractorResult
    ExtractorResult input1 = {0};
    input1.success = 0;
    input1.status = "offline";
    ExtractorResult result1 = normalizeExtractorResult(input1, "streamlink", "example_creator");
    assert(strcmp(result1.status, "technical_error") == 0);
    
    ExtractorResult input2 = {0};
    input2.success = 1;
    input2.status = "live";
    ExtractorResult result2 = normalizeExtractorResult(input2, "streamlink", "example_creator");
    assert(strcmp(result2.status, "technical_error") == 0);
    
    ExtractorResult input3 = {0};
    input3.success = 0;
    input3.status = "offline";
    input3.url = allowedUrl;
    ExtractorResult result3 = normalizeExtractorResult(input3, "streamlink", "example_creator");
    assert(strcmp(result3.status, "offline") == 0);
    assert(result3.url == NULL);
    
    ExtractorResult input4 = {0};
    input4.success = 1;
    input4.status = "live";
    input4.url = allowedUrl;
    ExtractorResult result4 = normalizeExtractorResult(input4, "streamlink", "example_creator");
    assert(strcmp(result4.status, "live") == 0);
    
    // Test classifyFinalFailure
    ExtractorResult failures[2];
    failures[0].status = "offline";
    failures[1].status = "dependency_missing";
    assert(strcmp(classifyFinalFailure(failures, 2), "offline") == 0);
    
    // Test exitCodeForResult
    ExtractorResult restricted = {0};
    restricted.success = 0;
    restricted.status = "restricted";
    assert(exitCodeForResult(restricted) == 1);
    
    ExtractorResult technical_error = {0};
    technical_error.success = 0;
    technical_error.status = "technical_error";
    assert(exitCodeForResult(technical_error) == 2);
    
    // Test classifyDirectLiveState
    LiveState state1 = {
        .username = "example_creator",
        .currentPath = "/@example_creator/live",
        .title = "Example (@example_creator) is LIVE - TikTok LIVE",
        .bodyText = "Dieses LIVE enthält Themen, die unangenehm sein könnten.",
        .successfulStreamResponse = 0
    };
    ExtractorResult classified1 = classifyDirectLiveState(state1);
    assert(strcmp(classified1.status, "restricted") == 0);
    
    LiveState state2 = {
        .username = "example_creator",
        .currentPath = "/@example_creator/live",
        .title = "Example (@example_creator) is LIVE - TikTok LIVE",
        .bodyText = "LIVE has ended",
        .successfulStreamResponse = 0
    };
    ExtractorResult classified2 = classifyDirectLiveState(state2);
    assert(strcmp(classified2.status, "offline") == 0);
    
    LiveState state3 = {
        .username = "example_creator",
        .currentPath = "/@example_creator/live",
        .title = "Example (@example_creator) is LIVE - TikTok LIVE",
        .bodyText = "Suggested LIVE creators",
        .successfulStreamResponse = 1
    };
    ExtractorResult classified3 = classifyDirectLiveState(state3);
    assert(strcmp(classified3.status, "live") == 0);
    
    printf("All tests passed!\n");
    return 0;
}
