// abstraction-provenance: {"artifact_sha256": "d71877de9e7820cf0bd9419fedbbc84f0cf1233f6569cb80a929a42da9dbaf34", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "c"}
// tm.go — portiert nach c
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>

#define MAX_LINE_LENGTH 8192
#define MAX_ENTRIES 10000

typedef struct {
    char* cache_key;
    char* segment_id;
    char* source_path;
    char* text_hash;
    char* text;
    char* translated;
    char* provider;
    char* model;
    char* src_lang;
    char* tgt_lang;
    char* updated_at;
} TMEntry;

typedef struct {
    char* path;
    TMEntry* entries;
    int count;
    int capacity;
} TranslationMemory;

static void free_tm_entry(TMEntry* entry) {
    if (!entry) return;
    
    free(entry->cache_key);
    free(entry->segment_id);
    free(entry->source_path);
    free(entry->text_hash);
    free(entry->text);
    free(entry->translated);
    free(entry->provider);
    free(entry->model);
    free(entry->src_lang);
    free(entry->tgt_lang);
    free(entry->updated_at);
    
    memset(entry, 0, sizeof(TMEntry));
}

static char* trim_whitespace(char* str) {
    char* end;
    while(*str == ' ' || *str == '\t' || *str == '\r' || *str == '\n') str++;
    if(*str == 0) return str;
    end = str + strlen(str) - 1;
    while(end > str && (*end == ' ' || *end == '\t' || *end == '\r' || *end == '\n')) end--;
    *(end+1) = 0;
    return str;
}

static int is_empty_or_whitespace(const char* str) {
    if (!str) return 1;
    while (*str) {
        if (*str != ' ' && *str != '\t' && *str != '\r' && *str != '\n') {
            return 0;
        }
        str++;
    }
    return 1;
}

static char* json_get_string_value(const char* json, const char* key) {
    char* result = NULL;
    char* key_pos = strstr(json, key);
    if (!key_pos) return NULL;
    
    char* colon = strchr(key_pos, ':');
    if (!colon) return NULL;
    
    char* start_quote = strchr(colon, '"');
    if (!start_quote) return NULL;
    
    char* end_quote = strchr(start_quote + 1, '"');
    if (!end_quote) return NULL;
    
    int len = end_quote - start_quote - 1;
    if (len > 0) {
        result = malloc(len + 1);
        if (result) {
            strncpy(result, start_quote + 1, len);
            result[len] = '\0';
        }
    }
    
    return result;
}

static int parse_json_line(const char* line, TMEntry* entry) {
    memset(entry, 0, sizeof(TMEntry));
    
    entry->cache_key = json_get_string_value(line, "\"cache_key\"");
    entry->segment_id = json_get_string_value(line, "\"segment_id\"");
    entry->source_path = json_get_string_value(line, "\"source_path\"");
    entry->text_hash = json_get_string_value(line, "\"text_hash\"");
    entry->text = json_get_string_value(line, "\"text\"");
    entry->translated = json_get_string_value(line, "\"translated\"");
    entry->provider = json_get_string_value(line, "\"provider\"");
    entry->model = json_get_string_value(line, "\"model\"");
    entry->src_lang = json_get_string_value(line, "\"src_lang\"");
    entry->tgt_lang = json_get_string_value(line, "\"tgt_lang\"");
    entry->updated_at = json_get_string_value(line, "\"updated_at\"");
    
    return 1;
}

TranslationMemory* load_translation_memory(const char* path) {
    TranslationMemory* tm = malloc(sizeof(TranslationMemory));
    if (!tm) return NULL;
    
    tm->path = strdup(path);
    tm->count = 0;
    tm->capacity = MAX_ENTRIES;
    tm->entries = calloc(tm->capacity, sizeof(TMEntry));
    
    if (!tm->entries) {
        free(tm->path);
        free(tm);
        return NULL;
    }
    
    FILE* file = fopen(path, "r");
    if (!file) {
        if (errno == ENOENT) {
            return tm;
        }
        free(tm->path);
        free(tm->entries);
        free(tm);
        return NULL;
    }
    
    char line[MAX_LINE_LENGTH];
    while (fgets(line, sizeof(line), file)) {
        char* trimmed = trim_whitespace(line);
        if (strlen(trimmed) > 0) {
            TMEntry entry;
            if (parse_json_line(trimmed, &entry)) {
                if (entry.cache_key && !is_empty_or_whitespace(entry.translated)) {
                    if (tm->count >= tm->capacity) {
                        tm->capacity *= 2;
                        TMEntry* new_entries = realloc(tm->entries, tm->capacity * sizeof(TMEntry));
                        if (!new_entries) {
                            free_tm_entry(&entry);
                            fclose(file);
                            return tm;
                        }
                        tm->entries = new_entries;
                    }
                    
                    tm->entries[tm->count] = entry;
                    tm->count++;
                } else {
                    free_tm_entry(&entry);
                }
            }
        }
    }
    
    fclose(file);
    return tm;
}

int get_translation_memory_entry(TranslationMemory* tm, const char* cache_key, TMEntry* out_entry) {
    if (!tm || !cache_key || !out_entry) return 0;
    
    for (int i = 0; i < tm->count; i++) {
        if (tm->entries[i].cache_key && strcmp(tm->entries[i].cache_key, cache_key) == 0) {
            if (!is_empty_or_whitespace(tm->entries[i].translated)) {
                *out_entry = tm->entries[i];
                return 1;
            }
            break;
        }
    }
    return 0;
}

void put_translation_memory_entry(TranslationMemory* tm, TMEntry entry) {
    if (!tm || !entry.cache_key) return;
    
    for (int i = 0; i < tm->count; i++) {
        if (tm->entries[i].cache_key && strcmp(tm->entries[i].cache_key, entry.cache_key) == 0) {
            free_tm_entry(&tm->entries[i]);
            tm->entries[i] = entry;
            return;
        }
    }
    
    if (tm->count >= tm->capacity) {
        tm->capacity *= 2;
        TMEntry* new_entries = realloc(tm->entries, tm->capacity * sizeof(TMEntry));
        if (!new_entries) return;
        tm->entries = new_entries;
    }
    
    tm->entries[tm->count] = entry;
    tm->count++;
}

static int compare_cache_keys(const void* a, const void* b) {
    const TMEntry* entry_a = (const TMEntry*)a;
    const TMEntry* entry_b = (const TMEntry*)b;
    
    if (!entry_a->cache_key && !entry_b->cache_key) return 0;
    if (!entry_a->cache_key) return -1;
    if (!entry_b->cache_key) return 1;
    
    return strcmp(entry_a->cache_key, entry_b->cache_key);
}

int save_translation_memory(TranslationMemory* tm) {
    if (!tm || !tm->path) return 0;
    
    char* dir_path = strdup(tm->path);
    char* last_slash = strrchr(dir_path, '/');
    if (last_slash) {
        *last_slash = '\0';
        mkdir(dir_path, 0755);
    }
    free(dir_path);
    
    char* tmp_path = malloc(strlen(tm->path) + 5);
    if (!tmp_path) return 0;
    sprintf(tmp_path, "%s.tmp", tm->path);
    
    int fd = open(tmp_path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd == -1) {
        free(tmp_path);
        return 0;
    }
    
    FILE* file = fdopen(fd, "w");
    if (!file) {
        close(fd);
        unlink(tmp_path);
        free(tmp_path);
        return 0;
    }
    
    qsort(tm->entries, tm->count, sizeof(TMEntry), compare_cache_keys);
    
    for (int i = 0; i < tm->count; i++) {
        TMEntry* entry = &tm->entries[i];
        if (!entry->cache_key) continue;
        
        fprintf(file, "{\"cache_key\":\"%s\",\"segment_id\":\"%s\",\"source_path\":\"%s\",\"text_hash\":\"%s\",\"text\":\"%s\",\"translated\":\"%s\",\"provider\":\"%s\",\"model\":\"%s\",\"src_lang\":\"%s\",\"tgt_lang\":\"%s\",\"updated_at\":\"%s\"}\n",
                entry->cache_key ? entry->cache_key : "",
                entry->segment_id ? entry->segment_id : "",
                entry->source_path ? entry->source_path : "",
                entry->text_hash ? entry->text_hash : "",
                entry->text ? entry->text : "",
                entry->translated ? entry->translated : "",
                entry->provider ? entry->provider : "",
                entry->model ? entry->model : "",
                entry->src_lang ? entry->src_lang : "",
                entry->tgt_lang ? entry->tgt_lang : "",
                entry->updated_at ? entry->updated_at : "");
    }
    
    fclose(file);
    
    if (rename(tmp_path, tm->path) != 0) {
        unlink(tmp_path);
        free(tmp_path);
        return 0;
    }
    
    free(tmp_path);
    return 1;
}

void free_translation_memory(TranslationMemory* tm) {
    if (!tm) return;
    
    for (int i = 0; i < tm->count; i++) {
        free_tm_entry(&tm->entries[i]);
    }
    
    free(tm->path);
    free(tm->entries);
    free(tm);
}
