// abstraction-provenance: {"artifact_sha256": "14575d908b40a04880b582249a481d6ad9caefbbdb8c2df67ec4b6fe43c785d1", "source_sha256": "23879e22856f8bcfb0ddda7c9b1d7b0d7f3af474cea8620c1f7c10511ef03ed5", "target_language": "c"}
// tiktok-common.js — portiert nach c
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <regex.h>
#include <math.h>

#define DEFAULT_MAX_LOAD_PER_CPU 1.5
#define MAX_USERNAME_LENGTH 24

const char* FAILURE_STATUSES[] = {
    "offline",
    "restricted",
    "overloaded",
    "dependency_missing",
    "technical_error"
};
const int FAILURE_STATUSES_COUNT = 5;

typedef struct {
    int overloaded;
    double loadPerCpu;
    double maximum;
} LoadState;

typedef struct {
    char* status;
    char* reason;
} LiveState;

typedef struct {
    int success;
    char* status;
    char* method;
    char* username;
    char* url;
    char* message;
} ExtractorResult;

int is_valid_username(const char* username) {
    if (!username || strlen(username) == 0 || strlen(username) > MAX_USERNAME_LENGTH) {
        return 0;
    }
    
    for (int i = 0; username[i] != '\0'; i++) {
        char c = username[i];
        if (!(isalnum(c) || c == '.' || c == '_')) {
            return 0;
        }
    }
    
    return 1;
}

char* normalize_username(const char* raw) {
    if (!raw) return NULL;
    
    // Trim whitespace and remove leading @
    int start = 0;
    int len = strlen(raw);
    
    while (start < len && isspace(raw[start])) start++;
    while (len > start && isspace(raw[len - 1])) len--;
    
    if (start >= len) return NULL;
    
    const char* trimmed = raw + start;
    int trimmed_len = len - start;
    
    // Remove leading @ symbols
    while (*trimmed == '@') {
        trimmed++;
        trimmed_len--;
    }
    
    if (trimmed_len == 0 || trimmed_len > MAX_USERNAME_LENGTH) return NULL;
    
    char* result = malloc(trimmed_len + 1);
    strncpy(result, trimmed, trimmed_len);
    result[trimmed_len] = '\0';
    
    if (!is_valid_username(result)) {
        free(result);
        return NULL;
    }
    
    return result;
}

LoadState load_state() {
    LoadState state;
    state.overloaded = 0;
    state.loadPerCpu = 0.0;
    state.maximum = DEFAULT_MAX_LOAD_PER_CPU;
    
    // In C we can't easily get system load, so we'll use environment variables
    char* max_load_env = getenv("TIKTOK_MAX_LOAD_PER_CPU");
    if (max_load_env) {
        state.maximum = atof(max_load_env);
    }
    
    char* test_load_env = getenv("TIKTOK_TEST_LOAD_PER_CPU");
    if (test_load_env) {
        state.loadPerCpu = atof(test_load_env);
    } else {
        // Default to 0 if we can't determine actual load
        state.loadPerCpu = 0.0;
    }
    
    if (!isfinite(state.loadPerCpu) || !isfinite(state.maximum) || state.maximum <= 0) {
        fprintf(stderr, "Invalid TikTok load configuration\n");
        exit(1);
    }
    
    state.overloaded = state.loadPerCpu > state.maximum;
    return state;
}

void enforce_load_limit(const char* method) {
    LoadState state = load_state();
    if (!state.overloaded) return;
    
    fprintf(stderr, "{\"status\":\"overloaded\",\"method\":\"%s\",\"loadPerCpu\":%.3f,\"maximum\":%.3f,\"message\":\"Host is overloaded; retry on another node or later\"}\n", 
            method, state.loadPerCpu, state.maximum);
    exit(75);
}

int is_https_tiktok_cdn_url(const char* value) {
    if (!value) return 0;
    
    // Simple check for https:// and tiktokcdn in hostname
    if (strncmp(value, "https://", 8) != 0) return 0;
    
    // Check if it contains .flv
    if (!strstr(value, ".flv")) return 0;
    
    // Check if it's from tiktokcdn domain
    if (strstr(value, "tiktokcdn.com") || strstr(value, "tiktokcdn-")) {
        return 1;
    }
    
    return 0;
}

int is_successful_stream_response(int status, const char* value) {
    return (status >= 200 && status < 300) && is_https_tiktok_cdn_url(value);
}

char* quality_key_from_url(const char* value) {
    if (!value) return NULL;
    
    // Order matters: longer keys first
    if (strstr(value, "_uhd_60.")) return strdup("uhd_60");
    if (strstr(value, "_hd_60.")) return strdup("hd_60");
    if (strstr(value, "_origin.")) return strdup("origin");
    if (strstr(value, "_hd.")) return strdup("hd");
    if (strstr(value, "_sd.")) return strdup("sd");
    if (strstr(value, "_ld.")) return strdup("ld");
    if (strstr(value, "_ao.")) return strdup("ao");
    
    return NULL;
}

int is_failure_status(const char* status) {
    if (!status) return 0;
    
    for (int i = 0; i < FAILURE_STATUSES_COUNT; i++) {
        if (strcmp(status, FAILURE_STATUSES[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

char* classify_final_failure(ExtractorResult* results, int count) {
    for (int i = 0; i < count; i++) {
        if (results[i].status && strcmp(results[i].status, "overloaded") == 0) {
            return strdup("overloaded");
        }
    }
    
    for (int i = 0; i < count; i++) {
        if (results[i].status && strcmp(results[i].status, "restricted") == 0) {
            return strdup("restricted");
        }
    }
    
    for (int i = 0; i < count; i++) {
        if (results[i].status && strcmp(results[i].status, "technical_error") == 0) {
            return strdup("technical_error");
        }
    }
    
    for (int i = 0; i < count; i++) {
        if (results[i].status && strcmp(results[i].status, "offline") == 0) {
            return strdup("offline");
        }
    }
    
    for (int i = 0; i < count; i++) {
        if (results[i].status && strcmp(results[i].status, "dependency_missing") == 0) {
            return strdup("dependency_missing");
        }
    }
    
    return strdup("technical_error");
}

int exit_code_for_result(ExtractorResult* result) {
    if (result && result->success && result->status && strcmp(result->status, "live") == 0) {
        return 0;
    }
    if (result && result->status && strcmp(result->status, "overloaded") == 0) {
        return 75;
    }
    if (result && result->status && 
        (strcmp(result->status, "offline") == 0 || strcmp(result->status, "restricted") == 0)) {
        return 1;
    }
    return 2;
}

LiveState classify_direct_live_state(const char* username, const char* current_path, 
                                     const char* title, const char* body_text, 
                                     int successful_stream_response) {
    LiveState state = {NULL, NULL};
    
    if (!username || !current_path) {
        state.status = strdup("offline");
        state.reason = strdup("missing required parameters");
        return state;
    }
    
    char* expected_path = malloc(strlen(username) + 10);
    sprintf(expected_path, "/@%s/live", username);
    
    if (strcmp(current_path, expected_path) != 0) {
        state.status = strdup("offline");
        state.reason = strdup("target live page redirected");
        free(expected_path);
        return state;
    }
    free(expected_path);
    
    if (successful_stream_response) {
        state.status = strdup("live");
        state.reason = strdup("successful TikTok CDN stream response");
        return state;
    }
    
    // Normalize body text (simplified)
    char* normalized_body = NULL;
    if (body_text) {
        normalized_body = malloc(strlen(body_text) + 1);
        strcpy(normalized_body, body_text);
        for (int i = 0; normalized_body[i]; i++) {
            normalized_body[i] = tolower(normalized_body[i]);
        }
    }
    
    // Normalize title
    char* normalized_title = NULL;
    if (title) {
        normalized_title = malloc(strlen(title) + 1);
        strcpy(normalized_title, title);
        for (int i = 0; normalized_title[i]; i++) {
            normalized_title[i] = tolower(normalized_title[i]);
        }
    }
    
    // Check for ended markers
    const char* ended_markers[] = {
        "live has ended",
        "das live ist beendet",
        "live wurde beendet",
        "dieses live ist beendet",
        "stream has ended"
    };
    
    if (normalized_body) {
        for (int i = 0; i < 5; i++) {
            if (strstr(normalized_body, ended_markers[i])) {
                state.status = strdup("offline");
                state.reason = strdup("target live page reports ended stream");
                free(normalized_body);
                free(normalized_title);
                return state;
            }
        }
    }
    
    // Check for restriction markers
    const char* restriction_markers[] = {
        "dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten",
        "melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen",
        "bei tiktok anmelden",
        "melde dich an für das volle live-erlebnis",
        "melde dich an für das vollständige erlebnis",
        "this live may contain content that could be uncomfortable",
        "log in to tiktok",
        "log in for the full live experience",
        "mature content",
        "age-restricted",
        "viewer discretion"
    };
    
    int account_live_title = 0;
    if (normalized_title) {
        char* user_marker = malloc(strlen(username) + 20);
        sprintf(user_marker, "(@%s) is live", username);
        for (int i = 0; user_marker[i]; i++) {
            user_marker[i] = tolower(user_marker[i]);
        }
        
        if (strstr(normalized_title, user_marker)) {
            account_live_title = 1;
        }
        free(user_marker);
    }
    
    if (account_live_title && normalized_body) {
        for (int i = 0; i < 11; i++) {
            if (strstr(normalized_body, restriction_markers[i])) {
                state.status = strdup("restricted");
                state.reason = strdup("target live page requires authentication");
                free(normalized_body);
                free(normalized_title);
                return state;
            }
        }
    }
    
    if (account_live_title) {
        state.status = strdup("restricted");
        state.reason = strdup("target is live but no accessible media response was available");
        free(normalized_body);
        free(normalized_title);
        return state;
    }
    
    state.status = strdup("offline");
    state.reason = strdup("no account-specific live signal");
    
    free(normalized_body);
    free(normalized_title);
    return state;
}

int forced_offline(const char* method, const char* username) {
    char* test_offline = getenv("TIKTOK_TEST_OFFLINE");
    if (!test_offline || strcmp(test_offline, "1") != 0) {
        return 0;
    }
    
    fprintf(stderr, "{\"success\":false,\"status\":\"offline\",\"method\":\"%s\",\"username\":\"%s\",\"message\":\"forced offline test mode\"}\n",
            method, username);
    return 1;
}
