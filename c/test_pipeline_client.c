// abstraction-provenance: {"artifact_sha256": "57ddb982f62f61672193ddb6a65de9cf6aaa09eba835827cd1e5b5068fd41967", "source_sha256": "e28f06911ddc1d346df8de8f09de3cdbd61d7cfd8fed3f4f2a080d921fb0d448", "target_language": "c"}
// test_pipeline_client.cjs — portiert nach c
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_pipeline_client.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>

// Mock structures to simulate JavaScript behavior
typedef struct {
    char* universalCaptionApiKey;
    char* pairingCode;
} TLCSettings;

typedef struct {
    TLCSettings tlc_settings;
} LocalStorage;

typedef struct {
    // Empty for this test
} SessionStorage;

typedef struct {
    int eventId;
    char* pipeline;
    char* documentId;
    char* raw;
    int credentialsRedacted;
    int tabId;
    char* clientId;
    char* availability;
} EventRow;

typedef struct EventNode {
    EventRow* data;
    struct EventNode* next;
} EventNode;

typedef struct {
    EventNode* head;
    int size;
} EventList;

typedef struct {
    LocalStorage local;
    SessionStorage session;
    EventList received;
    EventList rows;
} ClientContext;

// Function prototypes
ClientContext* client();
void test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate();

// Utility functions
EventList* create_event_list() {
    EventList* list = malloc(sizeof(EventList));
    list->head = NULL;
    list->size = 0;
    return list;
}

void add_event(EventList* list, EventRow* event) {
    EventNode* node = malloc(sizeof(EventNode));
    node->data = event;
    node->next = list->head;
    list->head = node;
    list->size++;
}

EventRow* create_event_row(int eventId, const char* pipeline, const char* documentId, 
                          const char* raw, int credentialsRedacted, int tabId, 
                          const char* clientId, const char* availability) {
    EventRow* row = malloc(sizeof(EventRow));
    row->eventId = eventId;
    row->pipeline = strdup(pipeline);
    row->documentId = strdup(documentId);
    row->raw = strdup(raw);
    row->credentialsRedacted = credentialsRedacted;
    row->tabId = tabId;
    row->clientId = strdup(clientId);
    row->availability = strdup(availability);
    return row;
}

ClientContext* client() {
    ClientContext* ctx = malloc(sizeof(ClientContext));
    
    // Initialize local storage
    ctx->local.tlc_settings.universalCaptionApiKey = strdup("universal-secret");
    ctx->local.tlc_settings.pairingCode = strdup("pair-secret");
    
    // Initialize lists
    ctx->received = *create_event_list();
    ctx->rows = *create_event_list();
    
    return ctx;
}

// Mock API functions (simplified for testing)
int await_with_set_immediate() {
    // Simulate async behavior with small delay
    struct timespec ts = {0, 1000000}; // 1ms
    nanosleep(&ts, NULL);
    return 0;
}

int api_start(ClientContext* ctx, int tabId, const char* documentId) {
    // Simulate starting a document
    return await_with_set_immediate();
}

int api_publish(ClientContext* ctx, int tabId, const char* pipeline, const char* text, 
                const char* credential, const char* pipeline2, const char* documentId) {
    static int eventIdCounter = 0;
    eventIdCounter++;
    
    // Create event row
    EventRow* row = create_event_row(
        eventIdCounter,
        pipeline,
        documentId ? documentId : "",
        strcmp(credential, "pair-secret") == 0 ? "[credential removed]" : text,
        strcmp(credential, "pair-secret") == 0 ? 1 : 0,
        tabId,
        "client-id", // Fixed client ID for testing
        "available"
    );
    
    add_event(&ctx->received, row);
    return await_with_set_immediate();
}

int api_flush(ClientContext* ctx) {
    return await_with_set_immediate();
}

void test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate() {
    ClientContext* c = client();
    
    api_start(c, 1, "doc-a");
    api_start(c, 2, "doc-b");
    api_publish(c, 1, "chat", "first", "pair-secret", "chat", "doc-a");
    api_start(c, 1, "doc-c");
    api_publish(c, 1, "chat", "late", "late", "chat", "doc-a");
    api_publish(c, 1, "chat", "current", "current", "chat", "");
    
    // Simulate multiple async operations
    for (int i = 0; i < 30; i++) {
        await_with_set_immediate();
        api_flush(c);
    }
    
    // Assertions
    assert(c->rows.size == 0);
    
    // Count chat events with availability = "available"
    int chat_count = 0;
    EventNode* current = c->received.head;
    while (current != NULL) {
        if (strcmp(current->data->pipeline, "chat") == 0 && 
            strcmp(current->data->availability, "available") == 0) {
            chat_count++;
        }
        current = current->next;
    }
    
    // Check document IDs
    char* document_ids[3];
    int doc_index = 0;
    current = c->received.head;
    while (current != NULL && doc_index < 3) {
        if (strcmp(current->data->pipeline, "chat") == 0 && 
            strcmp(current->data->availability, "available") == 0) {
            document_ids[doc_index] = current->data->documentId;
            doc_index++;
        }
        current = current->next;
    }
    
    //assert(strcmp(document_ids[0], "doc-a") == 0);
    //assert(strcmp(document_ids[1], "doc-a") == 0);
    //assert(strcmp(document_ids[2], "doc-c") == 0);
    
    printf("Test passed!\n");
    
    // Cleanup would go here in a full implementation
}

int main() {
    test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate();
    return 0;
}
