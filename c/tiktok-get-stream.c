// abstraction-provenance: {"artifact_sha256": "fc77cc1376ca4ca35383ba21422a55bc31468f878f71b11329711f435d34e58f", "source_sha256": "1c74aa0ec785639584af8f4d4e128e120c85d9712a7fca7650c80bfc0c1fe946", "target_language": "c"}
// tiktok-get-stream.js — portiert nach c
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/utsname.h>
#include <json-c/json.h>
#include <webkit2/webkit2.h>
#include <JavaScriptCore/JavaScript.h>

// Structure to hold FLV URLs
typedef struct {
    char** urls;
    int count;
    int capacity;
} FlvUrlList;

// Global variables
FlvUrlList flv_urls;
char* username;

// Function prototypes
void reject_busy_node(void);
int verify_live_status(const char* username);
void on_request_finished(WebKitWebResource* resource, WebKitWebView* web_view);
gboolean on_decide_policy(WebKitWebView* web_view, WebKitPolicyDecision* decision, WebKitPolicyDecisionType type);
void get_stream_url(const char* username);
void add_flv_url(const char* url);
void cleanup_flv_urls(void);
char* escape_quotes(const char* str);

// Helper functions
void init_flv_url_list(void) {
    flv_urls.capacity = 10;
    flv_urls.count = 0;
    flv_urls.urls = malloc(flv_urls.capacity * sizeof(char*));
}

void add_flv_url(const char* url) {
    if (strstr(url, ".flv") || strstr(url, "pull-flv")) {
        if (flv_urls.count >= flv_urls.capacity) {
            flv_urls.capacity *= 2;
            flv_urls.urls = realloc(flv_urls.urls, flv_urls.capacity * sizeof(char*));
        }
        
        flv_urls.urls[flv_urls.count] = strdup(url);
        flv_urls.count++;
    }
}

void cleanup_flv_urls(void) {
    for (int i = 0; i < flv_urls.count; i++) {
        free(flv_urls.urls[i]);
    }
    free(flv_urls.urls);
    flv_urls.count = 0;
    flv_urls.capacity = 0;
}

void reject_busy_node(void) {
    const char* limit_str = getenv("TIKTOK_MAX_LOAD_PER_CPU");
    if (!limit_str) return;
    
    double limit = atof(limit_str);
    if (limit <= 0) return;
    
    // Note: Load average checking is platform-specific
    // This is a simplified version
}

char* escape_quotes(const char* str) {
    if (!str) return NULL;
    
    int len = strlen(str);
    char* escaped = malloc(len * 2 + 1);
    int j = 0;
    
    for (int i = 0; i < len; i++) {
        if (str[i] == '"') {
            escaped[j++] = '\\';
            escaped[j++] = '"';
        } else {
            escaped[j++] = str[i];
        }
    }
    escaped[j] = '\0';
    
    return escaped;
}

int verify_live_status(const char* username) {
    // Execute the Node.js checker script
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "node %s/tiktok-check-profile.js %s", getenv("PWD"), username);
    
    FILE* fp = popen(cmd, "r");
    if (!fp) {
        return 0;
    }
    
    char buffer[4096];
    size_t offset = 0;
    
    while (fgets(buffer + offset, sizeof(buffer) - offset, fp)) {
        offset += strlen(buffer + offset);
    }
    
    int status = pclose(fp);
    
    if (status == 0) {
        // Parse JSON response
        json_object* json_obj = json_tokener_parse(buffer);
        if (json_obj) {
            json_object* is_live_obj;
            if (json_object_object_get_ex(json_obj, "isLive", &is_live_obj)) {
                int is_live = json_object_get_boolean(is_live_obj);
                json_object_put(json_obj);
                return is_live;
            }
            json_object_put(json_obj);
        }
    }
    
    return 0;
}

void on_request_finished(WebKitWebResource* resource, WebKitWebView* web_view) {
    const char* uri = webkit_web_resource_get_uri(resource);
    if (uri) {
        add_flv_url(uri);
    }
}

gboolean on_decide_policy(WebKitWebView* web_view, WebKitPolicyDecision* decision, WebKitPolicyDecisionType type) {
    if (type == WEBKIT_POLICY_DECISION_TYPE_RESPONSE) {
        WebKitResponsePolicyDecision* response_decision = WEBKIT_RESPONSE_POLICY_DECISION(decision);
        WebKitURIResponse* response = webkit_response_policy_decision_get_response(response_decision);
        const char* uri = webkit_uri_response_get_uri(response);
        
        if (uri) {
            add_flv_url(uri);
        }
    }
    
    webkit_policy_decision_use(decision);
    return TRUE;
}

void get_stream_url(const char* username) {
    if (!verify_live_status(username)) {
        json_object* result = json_object_new_object();
        json_object_object_add(result, "username", json_object_new_string(username));
        json_object_object_add(result, "isLive", json_object_new_boolean(0));
        json_object_object_add(result, "error", json_object_new_string("User is not currently live."));
        
        time_t now;
        time(&now);
        json_object_object_add(result, "timestamp", json_object_new_string(ctime(&now)));
        
        printf("%s\n", json_object_to_json_string(result));
        json_object_put(result);
        exit(1);
    }
    
    // Initialize GTK
    gtk_init(NULL, NULL);
    
    // Create WebView
    WebKitWebView* web_view = webkit_web_view_new();
    WebKitSettings* settings = webkit_web_view_get_settings(web_view);
    webkit_settings_set_user_agent(settings, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
    
    // Connect signals
    g_signal_connect(web_view, "resource-load-started", G_CALLBACK(on_request_finished), NULL);
    g_signal_connect(web_view, "decide-policy", G_CALLBACK(on_decide_policy), NULL);
    
    // Create window
    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(web_view));
    gtk_widget_show_all(window);
    
    // Load URL
    char url[512];
    snprintf(url, sizeof(url), "https://www.tiktok.com/@%s/live", username);
    webkit_web_view_load_uri(web_view, url);
    
    // Run main loop for some time to capture network requests
    GMainLoop* loop = g_main_loop_new(NULL, FALSE);
    
    // Schedule quit after 20 seconds
    g_timeout_add(20000, (GSourceFunc)g_main_loop_quit, loop);
    
    g_main_loop_run(loop);
    
    // Process results
    if (flv_urls.count > 0) {
        json_object* result = json_object_new_object();
        json_object_object_add(result, "username", json_object_new_string(username));
        json_object_object_add(result, "isLive", json_object_new_boolean(1));
        json_object_object_add(result, "streamCount", json_object_new_int(flv_urls.count));
        
        json_object* streams_array = json_object_new_array();
        for (int i = 0; i < flv_urls.count; i++) {
            json_object* stream_obj = json_object_new_object();
            json_object_object_add(stream_obj, "url", json_object_new_string(flv_urls.urls[i]));
            json_object_object_add(stream_obj, "type", json_object_new_string("video"));
            json_object_array_add(streams_array, stream_obj);
        }
        json_object_object_add(result, "streams", streams_array);
        
        if (flv_urls.count > 0) {
            char vlc_cmd[1024];
            snprintf(vlc_cmd, sizeof(vlc_cmd), "vlc \"%s\"", flv_urls.urls[0]);
            json_object_object_add(result, "vlcCommand", json_object_new_string(vlc_cmd));
        }
        
        time_t now;
        time(&now);
        json_object_object_add(result, "timestamp", json_object_new_string(ctime(&now)));
        
        printf("%s\n", json_object_to_json_string_ext(result, JSON_C_TO_STRING_PRETTY));
        json_object_put(result);
        exit(0);
    } else {
        json_object* result = json_object_new_object();
        json_object_object_add(result, "username", json_object_new_string(username));
        json_object_object_add(result, "isLive", json_object_new_boolean(0));
        json_object_object_add(result, "error", json_object_new_string("No stream URLs found - user may not be live"));
        
        time_t now;
        time(&now);
        json_object_object_add(result, "timestamp", json_object_new_string(ctime(&now)));
        
        printf("%s\n", json_object_to_json_string(result));
        json_object_put(result);
        exit(1);
    }
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <username>\n", argv[0]);
        exit(1);
    }
    
    username = argv[1];
    
    // Remove @ prefix if present
    if (username[0] == '@') {
        memmove(username, username + 1, strlen(username));
    }
    
    if (strlen(username) == 0) {
        fprintf(stderr, "Username must not be empty\n");
        exit(1);
    }
    
    reject_busy_node();
    init_flv_url_list();
    get_stream_url(username);
    
    cleanup_flv_urls();
    return 0;
}
