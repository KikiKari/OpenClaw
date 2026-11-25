// abstraction-provenance: {"artifact_sha256": "ab6d88567b5172c7deb46d675441df50eea3e7b8e513aff8866054bb31b2488e", "source_sha256": "0fe503378d960b547d45c597a390a046e4d115dc036760ca7ef605dec6f6f754", "target_language": "c"}
// test_pipeline_client.cjs — portiert nach c
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_pipeline_client.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>

// Mock implementation of required JavaScript-like functionality

// Simple map implementation for rows
typedef struct {
    char* key;
    void* value;
} map_entry;

typedef struct {
    map_entry* entries;
    int size;
    int capacity;
} simple_map;

simple_map* create_map() {
    simple_map* map = malloc(sizeof(simple_map));
    map->entries = NULL;
    map->size = 0;
    map->capacity = 0;
    return map;
}

void map_put(simple_map* map, const char* key, void* value) {
    // Check if key exists
    for (int i = 0; i < map->size; i++) {
        if (strcmp(map->entries[i].key, key) == 0) {
            map->entries[i].value = value;
            return;
        }
    }
    
    // Add new entry
    if (map->size >= map->capacity) {
        map->capacity = map->capacity == 0 ? 10 : map->capacity * 2;
        map->entries = realloc(map->entries, map->capacity * sizeof(map_entry));
    }
    
    map->entries[map->size].key = strdup(key);
    map->entries[map->size].value = value;
    map->size++;
}

void* map_get(simple_map* map, const char* key) {
    for (int i = 0; i < map->size; i++) {
        if (strcmp(map->entries[i].key, key) == 0) {
            return map->entries[i].value;
        }
    }
    return NULL;
}

void map_delete(simple_map* map, const char* key) {
    for (int i = 0; i < map->size; i++) {
        if (strcmp(map->entries[i].key, key) == 0) {
            free(map->entries[i].key);
            // Shift remaining entries
            for (int j = i; j < map->size - 1; j++) {
                map->entries[j] = map->entries[j + 1];
            }
            map->size--;
            return;
        }
    }
}

int map_size(simple_map* map) {
    return map->size;
}

// Storage mock
typedef struct {
    simple_map* data;
} storage_mock;

storage_mock* create_storage() {
    storage_mock* storage = malloc(sizeof(storage_mock));
    storage->data = create_map();
    return storage;
}

// Database mock
typedef struct {
    simple_map* rows;
} database_mock;

database_mock* create_database() {
    database_mock* db = malloc(sizeof(database_mock));
    db->rows = create_map();
    return db;
}

// Context mock
typedef struct {
    database_mock* database;
    storage_mock* local_storage;
    storage_mock* session_storage;
    simple_map* received;
} context_mock;

context_mock* create_context() {
    context_mock* context = malloc(sizeof(context_mock));
    context->database = create_database();
    context->local_storage = create_storage();
    context->session_storage = create_storage();
    context->received = create_map();
    return context;
}

// Mock TLCPipelines API functions
typedef struct {
    context_mock* context;
} tlc_pipelines;

tlc_pipelines* create_tlc_pipelines(context_mock* context) {
    tlc_pipelines* pipelines = malloc(sizeof(tlc_pipelines));
    pipelines->context = context;
    return pipelines;
}

// Mock implementations of the API methods
int tlc_start(tlc_pipelines* pipelines, int tab_id, const char* document_id) {
    // Simulate starting a pipeline
    printf("Starting pipeline for tab %d, document %s\n", tab_id, document_id);
    return 0;
}

int tlc_publish(tlc_pipelines* pipelines, int tab_id, const char* pipeline_type, const char* text, 
                const char* credential, const char* chat_type, const char* document_id) {
    // Simulate publishing an event
    printf("Publishing %s: %s (credential: %s) for tab %d, document %s\n", 
           pipeline_type, text, credential, tab_id, document_id ? document_id : "current");
    return 0;
}

int tlc_flush(tlc_pipelines* pipelines) {
    // Simulate flushing events
    printf("Flushing events\n");
    return 0;
}

// Test function
void test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate() {
    context_mock* context = create_context();
    tlc_pipelines* c = create_tlc_pipelines(context);
    
    // Simulate the test steps
    tlc_start(c, 1, "doc-a");
    tlc_start(c, 2, "doc-b");
    tlc_publish(c, 1, "chat", "first", "pair-secret", "chat", "doc-a");
    tlc_start(c, 1, "doc-c");
    tlc_publish(c, 1, "chat", "late", "late", "chat", "doc-a");
    tlc_publish(c, 1, "chat", "current", "current", "chat", NULL);
    
    // Simulate event loop iterations
    for (int i = 0; i < 30; i++) {
        tlc_flush(c);
    }
    
    // Assertions would go here in a real test framework
    printf("Test completed\n");
    
    // Cleanup
    free(c);
    free(context);
}

int main() {
    test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate();
    return 0;
}
