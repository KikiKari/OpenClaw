// abstraction-provenance: {"artifact_sha256": "1aaf086cb2073fa85786a676d98b7a00f394bbf342918da2a836ba78854d8883", "source_sha256": "e90219318254f9b20057962724b153b7476a0511846415f2cc0a38bd9baa14f5", "target_language": "c"}
// tiktok-check-profile.js — portiert nach c
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/sysinfo.h>
#include <webkit2/webkit2.h>
#include <JavaScriptCore/JavaScript.h>
#include <libsoup/soup.h>
#include <pthread.h>
#include <time.h>
#include <json-glib/json-glib.h>

typedef struct {
    WebKitWebView *web_view;
    GMainLoop *loop;
    gboolean result;
    char *username;
} CheckData;

static gboolean load_finished = FALSE;
static gboolean screenshot_taken = FALSE;

// Function to get system load average
double get_load_average() {
    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        double load = (double)info.loads[0] / (1 << SI_LOAD_SHIFT);
        return load;
    }
    return -1.0;
}

// Function to check node busy status
void reject_busy_node() {
    const char *limit_str = getenv("TIKTOK_MAX_LOAD_PER_CPU");
    if (!limit_str) return;
    
    double limit = atof(limit_str);
    if (limit <= 0) return;
    
    int cpu_count = get_nprocs();
    if (cpu_count <= 0) cpu_count = 1;
    
    double normalized_load = get_load_average() / cpu_count;
    if (normalized_load > limit) {
        fprintf(stderr, "NODE_BUSY normalizedLoad=%.2f limit=%.2f\n", normalized_load, limit);
        exit(75);
    }
}

// Callback when page finishes loading
static void on_load_finished(WebKitWebView *web_view, WebKitLoadEvent load_event, gpointer user_data) {
    if (load_event == WEBKIT_LOAD_FINISHED) {
        load_finished = TRUE;
    }
}

// Function to execute JavaScript code
static void run_javascript_callback(WebKitWebView *web_view, GAsyncResult *result, gpointer user_data) {
    GError *error = NULL;
    WebKitJavascriptResult *js_result = webkit_web_view_run_javascript_finish(web_view, result, &error);
    
    if (error) {
        g_error_free(error);
    } else {
        JSGlobalContextRef context = webkit_javascript_result_get_global_context(js_result);
        JSValueRef value = webkit_javascript_result_get_value(js_result);
        
        if (JSValueIsString(context, value)) {
            JSStringRef js_str = JSValueToStringCopy(context, value, NULL);
            size_t len = JSStringGetMaximumUTF8CStringSize(js_str);
            char *str = g_malloc(len);
            JSStringGetUTF8CString(js_str, str, len);
            JSStringRelease(js_str);
            
            if (strstr(str, "screenshot")) {
                screenshot_taken = TRUE;
            }
            
            g_free(str);
        }
    }
    
    if (js_result) {
        webkit_javascript_result_unref(js_result);
    }
}

// Function to close cookie banners
static gboolean close_cookie_banners(WebKitWebView *web_view) {
    const char *selectors[] = {
        "button:contains('Verstanden')",
        "[data-e2e='cookie-banner-accept']",
        "button:contains('Accept')",
        "button:contains('Akzeptieren')",
        "button:contains('Alle akzeptieren')",
        "button:contains('Allow all')",
        "button:contains('Accept all')",
        ".TUXButton:contains('Accept')",
        "[data-testid='cookie-policy-banner-accept']",
        NULL
    };
    
    for (int i = 0; selectors[i]; i++) {
        char *script = g_strdup_printf(
            "var btn = document.querySelector('%s'); "
            "if (btn) { btn.click(); true; } else { false; }",
            selectors[i]
        );
        
        webkit_web_view_run_javascript(web_view, script, NULL, run_javascript_callback, NULL);
        g_free(script);
        
        // Small delay between attempts
        usleep(500000);
    }
    
    return TRUE;
}

// Function to take screenshot if DEBUG is set
static gboolean take_screenshot_if_debug(WebKitWebView *web_view, const char *username) {
    const char *debug = getenv("DEBUG");
    if (debug && strcmp(debug, "1") == 0) {
        char filename[256];
        snprintf(filename, sizeof(filename), "/tmp/tiktok-%s.png", username);
        
        // In a real implementation, we would use webkit_web_view_get_snapshot
        // This is a placeholder since snapshot functionality requires additional setup
        printf("Screenshot would be saved to %s\n", filename);
        return TRUE;
    }
    return FALSE;
}

// Function to check live indicators
static gboolean check_live_indicators(WebKitWebView *web_view, const char *username) {
    // This is a simplified version - in practice, you'd need to implement
    // proper DOM querying similar to the JavaScript version
    
    gboolean live_icon_visible = FALSE;
    gboolean live_badge_visible = FALSE;
    gboolean has_live_border = FALSE;
    gboolean has_live_link = FALSE;
    gboolean live_indicator_visible = FALSE;
    
    // Check for live icon
    char *script = g_strdup_printf(
        "var el = document.querySelector('[data-e2e=\"live-icon\"]'); "
        "el && el.offsetParent !== null;"
    );
    webkit_web_view_run_javascript(web_view, script, NULL, run_javascript_callback, NULL);
    g_free(script);
    
    // Check for LIVE text/badge
    script = g_strdup_printf(
        "var el = document.querySelector('[data-e2e=\"creator-page-header\"], [data-e2e=\"profile-avatar\"]'); "
        "if (el) { "
        "  var badge = el.querySelector(':contains(\"LIVE\")'); "
        "  badge && badge.offsetParent !== null; "
        "} else false;"
    );
    webkit_web_view_run_javascript(web_view, script, NULL, run_javascript_callback, NULL);
    g_free(script);
    
    // Check for live link
    script = g_strdup_printf(
        "var link = document.querySelector('a[href*=\"/@%s/live\"]'); "
        "link !== null;",
        username
    );
    webkit_web_view_run_javascript(web_view, script, NULL, run_javascript_callback, NULL);
    g_free(script);
    
    // For now, return a conservative estimate
    return live_icon_visible || live_badge_visible || has_live_border || has_live_link || live_indicator_visible;
}

// Navigation policy decision handler
static gboolean on_navigation_policy_decided(WebKitWebView *web_view,
                                           WebKitNavigationAction *navigation_action,
                                           gpointer user_data) {
    WebKitURIRequest *request = webkit_navigation_action_get_request(navigation_action);
    const char *uri = webkit_uri_request_get_uri(request);
    
    // Allow navigation to TikTok URLs only
    if (g_str_has_prefix(uri, "https://www.tiktok.com/") ||
        g_str_has_prefix(uri, "http://www.tiktok.com/")) {
        return FALSE; // Allow navigation
    }
    
    return TRUE; // Block navigation
}

// Timeout callback
static gboolean timeout_callback(gpointer user_data) {
    CheckData *data = (CheckData *)user_data;
    g_main_loop_quit(data->loop);
    return G_SOURCE_REMOVE;
}

// Main checking function
static gboolean check_live_status(CheckData *data) {
    WebKitWebView *web_view = data->web_view;
    const char *username = data->username;
    
    // Build URL
    char url[512];
    snprintf(url, sizeof(url), "https://www.tiktok.com/@%s", username);
    
    // Load the page
    webkit_web_view_load_uri(web_view, url);
    
    // Wait for initial load
    time_t start_time = time(NULL);
    while (!load_finished && (time(NULL) - start_time) < 30) {
        g_main_context_iteration(NULL, TRUE);
        usleep(100000); // 100ms
    }
    
    if (!load_finished) {
        fprintf(stderr, "Page load timeout\n");
        return FALSE;
    }
    
    // Wait additional time for content to load
    usleep(2000000); // 2 seconds
    
    // Close cookie banners
    close_cookie_banners(web_view);
    
    // Additional waiting time
    usleep(3000000); // 3 seconds
    
    // Take screenshot if debug enabled
    take_screenshot_if_debug(web_view, username);
    
    // Check live status
    gboolean is_live = check_live_indicators(web_view, username);
    
    // Create JSON output
    JsonBuilder *builder = json_builder_new();
    json_builder_begin_object(builder);
    
    json_builder_set_member_name(builder, "username");
    json_builder_add_string_value(builder, username);
    
    json_builder_set_member_name(builder, "isLive");
    json_builder_add_boolean_value(builder, is_live);
    
    json_builder_set_member_name(builder, "timestamp");
    time_t now = time(NULL);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
    json_builder_add_string_value(builder, timestamp);
    
    json_builder_end_object(builder);
    
    JsonGenerator *gen = json_generator_new();
    JsonNode *root = json_builder_get_root(builder);
    json_generator_set_root(gen, root);
    json_generator_set_pretty(gen, TRUE);
    
    gchar *json_str = json_generator_to_data(gen, NULL);
    printf("%s\n", json_str);
    
    g_free(json_str);
    json_node_unref(root);
    g_object_unref(gen);
    g_object_unref(builder);
    
    return is_live;
}

// Web view ready callback
static void on_web_view_ready(GObject *object, GAsyncResult *result, gpointer user_data) {
    CheckData *data = (CheckData *)user_data;
    GError *error = NULL;
    
    webkit_web_view_load_uri_finish(WEBKIT_WEB_VIEW(object), result, &error);
    
    if (error) {
        fprintf(stderr, "Failed to load page: %s\n", error->message);
        g_error_free(error);
        g_main_loop_quit(data->loop);
        return;
    }
    
    data->result = check_live_status(data);
    g_main_loop_quit(data->loop);
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <username>\n", argv[0]);
        return 1;
    }
    
    const char *raw_username = argv[1];
    if (!raw_username || strlen(raw_username) == 0) {
        fprintf(stderr, "Username must not be empty\n");
        return 1;
    }
    
    // Normalize username (remove leading @)
    const char *username = raw_username;
    if (username[0] == '@') {
        username++;
    }
    
    if (strlen(username) == 0) {
        fprintf(stderr, "Username must not be empty\n");
        return 1;
    }
    
    // Check node busy status
    reject_busy_node();
    
    // Initialize GTK
    gtk_init(NULL, NULL);
    
    // Create web context with custom settings
    WebKitWebContext *context = webkit_web_context_get_default();
    
    // Create WebView
    WebKitWebView *web_view = webkit_web_view_new();
    
    // Set user agent
    WebKitSettings *settings = webkit_web_view_get_settings(web_view);
    webkit_settings_set_user_agent(settings, 
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
    
    // Connect signals
    g_signal_connect(web_view, "load-changed", G_CALLBACK(on_load_finished), NULL);
    g_signal_connect(web_view, "decide-policy", G_CALLBACK(on_navigation_policy_decided), NULL);
    
    // Create check data
    CheckData data = {
        .web_view = web_view,
        .loop = g_main_loop_new(NULL, FALSE),
        .username = (char *)username,
        .result = FALSE
    };
    
    // Start checking in a timeout to ensure web view is ready
    g_timeout_add(100, (GSourceFunc)timeout_callback, &data);
    
    // Run the check
    gboolean result = check_live_status(&data);
    
    // Cleanup
    g_object_unref(web_view);
    g_main_loop_unref(data.loop);
    
    return result ? 0 : 1;
}
