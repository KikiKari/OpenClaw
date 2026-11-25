// abstraction-provenance: {"artifact_sha256": "654c5ef9561421c22cb7f7a54aa76476631202b0c4ef3dd988d977a40d675bac", "source_sha256": "eb08e6ac444b7c9611c2c56d0b5b99c5f3d6c627dce5fb23dd375d732ee39a65", "target_language": "c"}
// tiktok-check-profile.js — portiert nach c
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <curl/curl.h>
#include <json-c/json.h>

#define MAX_BUFFER_SIZE 1024 * 1024
#define USER_AGENT "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

typedef struct {
    char *memory;
    size_t size;
} MemoryStruct;

static size_t WriteMemoryCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    MemoryStruct *mem = (MemoryStruct *)userp;

    char *ptr = realloc(mem->memory, mem->size + realsize + 1);
    if (!ptr) {
        fprintf(stderr, "Not enough memory (realloc returned NULL)\n");
        return 0;
    }

    mem->memory = ptr;
    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = 0;

    return realsize;
}

void delay(int min_ms, int max_ms) {
    srand(time(NULL));
    int range = max_ms - min_ms + 1;
    int delay_ms = (rand() % range) + min_ms;
    usleep(delay_ms * 1000);
}

char* normalize_username(const char* input) {
    if (!input || strlen(input) == 0) {
        return NULL;
    }
    
    char* normalized = malloc(strlen(input) + 2);
    strcpy(normalized, input);
    
    if (normalized[0] != '@') {
        memmove(normalized + 1, normalized, strlen(normalized) + 1);
        normalized[0] = '@';
    }
    
    return normalized;
}

int file_exists(const char* filename) {
    struct stat buffer;
    return (stat(filename, &buffer) == 0);
}

int is_successful_stream_response(long status_code, const char* url) {
    if (status_code == 200 && strstr(url, ".flv")) {
        return 1;
    }
    return 0;
}

struct json_object* classify_direct_live_state(const char* username, const char* current_path, 
                                                 const char* title, const char* body_text, 
                                                 int successful_stream_response) {
    struct json_object *result = json_object_new_object();
    
    if (strstr(current_path, "/login") || strstr(title, "Login") || strstr(body_text, "login")) {
        json_object_object_add(result, "status", json_object_new_string("restricted"));
        json_object_object_add(result, "reason", json_object_new_string("login_required"));
    } else if (strstr(current_path, "/foryou") || strstr(title, "For You") || 
               strstr(body_text, "For You") || strstr(body_text, "FÃ¼r dich")) {
        json_object_object_add(result, "status", json_object_new_string("offline"));
        json_object_object_add(result, "reason", json_object_new_string("redirected_to_foryou"));
    } else if (strstr(body_text, "age restriction") || strstr(body_text, "AltersbeschrÃ¤nkung") || 
               strstr(body_text, "restricted") || strstr(body_text, "BeschrÃ¤nkung")) {
        json_object_object_add(result, "status", json_object_new_string("restricted"));
        json_object_object_add(result, "reason", json_object_new_string("age_restriction"));
    } else if (successful_stream_response) {
        json_object_object_add(result, "status", json_object_new_string("live"));
        json_object_object_add(result, "reason", json_object_new_string("stream_accessible"));
    } else if (strstr(body_text, "offline") || strstr(body_text, "Offline") || 
               strstr(body_text, "beendet") || strstr(body_text, "ended")) {
        json_object_object_add(result, "status", json_object_new_string("offline"));
        json_object_object_add(result, "reason", json_object_new_string("stream_offline"));
    } else {
        json_object_object_add(result, "status", json_object_new_string("technical_error"));
        json_object_object_add(result, "reason", json_object_new_string("unknown_state"));
    }
    
    return result;
}

struct json_object* check_live_status(const char* username) {
    CURL *curl;
    CURLcode res;
    MemoryStruct chunk_profile;
    MemoryStruct chunk_live;
    long http_response_code = 0;
    int successful_stream_response = 0;
    
    chunk_profile.memory = malloc(1);
    chunk_profile.size = 0;
    chunk_live.memory = malloc(1);
    chunk_live.size = 0;
    
    curl = curl_easy_init();
    if (!curl) {
        struct json_object *error_result = json_object_new_object();
        json_object_object_add(error_result, "error", json_object_new_boolean(1));
        json_object_object_add(error_result, "status", json_object_new_string("technical_error"));
        json_object_object_add(error_result, "message", json_object_new_string("Failed to initialize curl"));
        return error_result;
    }
    
    // Check profile page
    char profile_url[256];
    snprintf(profile_url, sizeof(profile_url), "https://www.tiktok.com/%s", username);
    
    curl_easy_setopt(curl, CURLOPT_URL, profile_url);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, USER_AGENT);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk_profile);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    
    res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        struct json_object *error_result = json_object_new_object();
        json_object_object_add(error_result, "error", json_object_new_boolean(1));
        json_object_object_add(error_result, "status", json_object_new_string("technical_error"));
        json_object_object_add(error_result, "message", json_object_new_string(curl_easy_strerror(res)));
        curl_easy_cleanup(curl);
        free(chunk_profile.memory);
        free(chunk_live.memory);
        return error_result;
    }
    
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_response_code);
    
    // Add human-like delays
    delay(2000, 4000);
    
    // Check live page
    char live_url[256];
    snprintf(live_url, sizeof(live_url), "https://www.tiktok.com/%s/live", username);
    
    curl_easy_setopt(curl, CURLOPT_URL, live_url);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk_live);
    
    res = curl_easy_perform(curl);
    if (res == CURLE_OK) {
        long live_response_code = 0;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &live_response_code);
        char *effective_url = NULL;
        curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &effective_url);
        
        successful_stream_response = is_successful_stream_response(live_response_code, effective_url ? effective_url : "");
    }
    
    // Add more human-like delays
    delay(8000, 10000);
    
    // Process results
    struct json_object *direct_result = classify_direct_live_state(
        username,
        live_url,
        "", // title not available in C implementation
        chunk_live.memory ? chunk_live.memory : "",
        successful_stream_response
    );
    
    const char *status_str = json_object_get_string(json_object_object_get(direct_result, "status"));
    const char *reason_str = json_object_get_string(json_object_object_get(direct_result, "reason"));
    
    struct json_object *final_result = json_object_new_object();
    json_object_object_add(final_result, "username", json_object_new_string(username));
    
    if (strcmp(status_str, "restricted") == 0) {
        json_object_object_add(final_result, "status", json_object_new_string("restricted"));
        json_object_object_add(final_result, "isLive", json_object_new_boolean(1));
        json_object_object_add(final_result, "isAgeRestricted", json_object_new_boolean(1));
        json_object_object_add(final_result, "ageRestrictionReason", json_object_new_string(reason_str));
    } else if (strcmp(status_str, "live") == 0) {
        json_object_object_add(final_result, "status", json_object_new_string("live"));
        json_object_object_add(final_result, "isLive", json_object_new_boolean(1));
        json_object_object_add(final_result, "isAgeRestricted", json_object_new_boolean(0));
    } else {
        json_object_object_add(final_result, "status", json_object_new_string(status_str));
        json_object_object_add(final_result, "isLive", json_object_new_boolean(0));
        json_object_object_add(final_result, "isAgeRestricted", json_object_new_boolean(0));
    }
    
    json_object_object_add(final_result, "detectionMethod", json_object_new_string("account-live-restricted"));
    json_object_object_add(final_result, "timestamp", json_object_new_string("")); // Empty for simplicity
    json_object_object_add(final_result, "version", json_object_new_string("2.1"));
    
    curl_easy_cleanup(curl);
    free(chunk_profile.memory);
    free(chunk_live.memory);
    json_object_put(direct_result);
    
    return final_result;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <username>\n", argv[0]);
        return 64;
    }
    
    char *normalized_username = normalize_username(argv[1]);
    if (!normalized_username) {
        fprintf(stderr, "Invalid username\n");
        return 64;
    }
    
    // Check if dependencies exist (simplified check)
    if (!file_exists("/usr/bin/chromium") && !file_exists("/usr/bin/google-chrome")) {
        printf("{\n  \"error\": true,\n  \"status\": \"dependency_missing\",\n  \"method\": \"playwright_enhanced\",\n  \"message\": \"Chromium/Chrome not found\"\n}\n");
        free(normalized_username);
        return 2;
    }
    
    struct json_object *result = check_live_status(normalized_username);
    const char *status = json_object_get_string(json_object_object_get(result, "status"));
    
    printf("%s\n", json_object_to_json_string_ext(result, JSON_C_TO_STRING_PRETTY));
    
    int exit_code = 2;
    if (strcmp(status, "live") == 0) {
        exit_code = 0;
    } else if (strcmp(status, "offline") == 0 || strcmp(status, "restricted") == 0) {
        exit_code = 1;
    }
    
    json_object_put(result);
    free(normalized_username);
    
    return exit_code;
}
