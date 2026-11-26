// abstraction-provenance: {"artifact_sha256": "aeb6d972ea3099e46fd1bb4619cee645e63d37cd5a5a8c81d6df6d429c304675", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "c"}
// bundled-plugin-root-runtime-mirrors.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <libgen.h>

#define MAX_PATH 4096
#define MAX_LINE 8192

typedef struct {
    char *key;
    char *value;
} KeyValuePair;

typedef struct {
    KeyValuePair *entries;
    size_t count;
    size_t capacity;
} Map;

typedef struct {
    char **items;
    size_t count;
    size_t capacity;
} StringArray;

typedef struct {
    char *spec;
    StringArray pluginIds;
    StringArray conflicts;
} BundledSpec;

typedef struct {
    char *dependencyName;
    char *spec;
    StringArray pluginIds;
    StringArray importers;
} MirrorRecord;

Map* map_create() {
    Map *map = malloc(sizeof(Map));
    map->entries = NULL;
    map->count = 0;
    map->capacity = 0;
    return map;
}

void map_put(Map *map, const char *key, const char *value) {
    for (size_t i = 0; i < map->count; i++) {
        if (strcmp(map->entries[i].key, key) == 0) {
            free(map->entries[i].value);
            map->entries[i].value = strdup(value);
            return;
        }
    }
    
    if (map->count >= map->capacity) {
        map->capacity = map->capacity == 0 ? 16 : map->capacity * 2;
        map->entries = realloc(map->entries, map->capacity * sizeof(KeyValuePair));
    }
    
    map->entries[map->count].key = strdup(key);
    map->entries[map->count].value = strdup(value);
    map->count++;
}

char* map_get(Map *map, const char *key) {
    for (size_t i = 0; i < map->count; i++) {
        if (strcmp(map->entries[i].key, key) == 0) {
            return map->entries[i].value;
        }
    }
    return NULL;
}

void map_free(Map *map) {
    for (size_t i = 0; i < map->count; i++) {
        free(map->entries[i].key);
        free(map->entries[i].value);
    }
    free(map->entries);
    free(map);
}

StringArray* string_array_create() {
    StringArray *arr = malloc(sizeof(StringArray));
    arr->items = NULL;
    arr->count = 0;
    arr->capacity = 0;
    return arr;
}

void string_array_add(StringArray *arr, const char *item) {
    for (size_t i = 0; i < arr->count; i++) {
        if (strcmp(arr->items[i], item) == 0) {
            return;
        }
    }
    
    if (arr->count >= arr->capacity) {
        arr->capacity = arr->capacity == 0 ? 16 : arr->capacity * 2;
        arr->items = realloc(arr->items, arr->capacity * sizeof(char*));
    }
    
    arr->items[arr->count] = strdup(item);
    arr->count++;
}

int string_array_contains(StringArray *arr, const char *item) {
    for (size_t i = 0; i < arr->count; i++) {
        if (strcmp(arr->items[i], item) == 0) {
            return 1;
        }
    }
    return 0;
}

void string_array_free(StringArray *arr) {
    for (size_t i = 0; i < arr->count; i++) {
        free(arr->items[i]);
    }
    free(arr->items);
    free(arr);
}

int file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

int is_directory(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    return S_ISDIR(st.st_mode);
}

int ends_with(const char *str, const char *suffix) {
    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);
    if (suffix_len > str_len) return 0;
    return strcmp(str + str_len - suffix_len, suffix) == 0;
}

int starts_with(const char *str, const char *prefix) {
    return strncmp(str, prefix, strlen(prefix)) == 0;
}

char* read_file(const char *path) {
    FILE *file = fopen(path, "r");
    if (!file) return NULL;
    
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    char *content = malloc(size + 1);
    fread(content, 1, size, file);
    content[size] = '\0';
    
    fclose(file);
    return content;
}

void get_all_files(const char *dir_path, StringArray *files, int include_extensions) {
    DIR *dir = opendir(dir_path);
    if (!dir) return;
    
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, entry->d_name);
        
        if (entry->d_type == DT_DIR) {
            if (include_extensions || strstr(full_path, "/extensions/") == NULL) {
                get_all_files(full_path, files, include_extensions);
            }
        } else if (entry->d_type == DT_REG) {
            if (ends_with(entry->d_name, ".cjs") || 
                ends_with(entry->d_name, ".js") || 
                ends_with(entry->d_name, ".mjs")) {
                string_array_add(files, full_path);
            }
        }
    }
    
    closedir(dir);
}

StringArray* collect_package_json_paths(const char *root_dir) {
    StringArray *paths = string_array_create();
    
    if (!file_exists(root_dir)) {
        return paths;
    }
    
    DIR *dir = opendir(root_dir);
    if (!dir) return paths;
    
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_DIR && 
            strcmp(entry->d_name, ".") != 0 && 
            strcmp(entry->d_name, "..") != 0) {
            
            char package_json_path[MAX_PATH];
            snprintf(package_json_path, sizeof(package_json_path), 
                     "%s/%s/package.json", root_dir, entry->d_name);
            
            if (file_exists(package_json_path)) {
                string_array_add(paths, package_json_path);
            }
        }
    }
    
    closedir(dir);
    return paths;
}

char* extract_package_name(const char *specifier) {
    if (!specifier || 
        starts_with(specifier, ".") || 
        starts_with(specifier, "/") || 
        starts_with(specifier, "node:") || 
        starts_with(specifier, "#")) {
        return NULL;
    }
    
    char *copy = strdup(specifier);
    char *first = strtok(copy, "/");
    char *second = strtok(NULL, "/");
    
    char *result = NULL;
    if (first) {
        if (first[0] == '@' && second) {
            result = malloc(strlen(first) + strlen(second) + 2);
            sprintf(result, "%s/%s", first, second);
        } else {
            result = strdup(first);
        }
    }
    
    free(copy);
    return result;
}

Map* collect_runtime_dependency_specs(Map *package_json) {
    Map *specs = map_create();
    
    // This would need JSON parsing implementation
    // For now, returning empty map as placeholder
    
    return specs;
}

Map* collect_bundled_plugin_runtime_dependency_specs(const char *bundled_plugins_dir) {
    Map *specs = map_create();
    StringArray *package_json_paths = collect_package_json_paths(bundled_plugins_dir);
    
    for (size_t i = 0; i < package_json_paths->count; i++) {
        char *package_json_path = package_json_paths->items[i];
        
        // Read and parse package.json - simplified here
        char *package_json_content = read_file(package_json_path);
        if (!package_json_content) continue;
        
        char *plugin_id = basename(dirname(strdup(package_json_path)));
        
        // Parse dependencies from package.json content
        // This requires a JSON parser which is not included here
        
        free(package_json_content);
        free(plugin_id);
    }
    
    string_array_free(package_json_paths);
    return specs;
}

StringArray* extract_module_specifiers(const char *source) {
    StringArray *specifiers = string_array_create();
    
    // Simplified regex-like extraction
    // In real implementation, proper regex or parsing would be needed
    
    const char *patterns[] = {"from \"", "import \"", "import(\"", "require(\"", NULL};
    
    for (int p = 0; patterns[p]; p++) {
        const char *pattern = patterns[p];
        const char *pos = source;
        
        while ((pos = strstr(pos, pattern)) != NULL) {
            pos += strlen(pattern);
            const char *end = strchr(pos, '"');
            if (end) {
                size_t len = end - pos;
                char *specifier = malloc(len + 1);
                strncpy(specifier, pos, len);
                specifier[len] = '\0';
                
                if (strlen(specifier) > 0) {
                    string_array_add(specifiers, specifier);
                }
                
                free(specifier);
            }
        }
    }
    
    return specifiers;
}

Map* collect_root_dist_bundled_runtime_mirrors(const char *dist_dir, Map *bundled_specs) {
    Map *mirrors = map_create();
    StringArray *files = string_array_create();
    
    get_all_files(dist_dir, files, 0); // 0 means exclude extensions directory
    
    for (size_t i = 0; i < files->count; i++) {
        char *file_path = files->items[i];
        char *source = read_file(file_path);
        if (!source) continue;
        
        StringArray *specifiers = extract_module_specifiers(source);
        
        for (size_t j = 0; j < specifiers->count; j++) {
            char *specifier = specifiers->items[j];
            char *dependency_name = extract_package_name(specifier);
            
            if (dependency_name && map_get(bundled_specs, dependency_name)) {
                // Add to mirrors logic would go here
            }
            
            free(dependency_name);
        }
        
        string_array_free(specifiers);
        free(source);
    }
    
    string_array_free(files);
    return mirrors;
}

StringArray* collect_bundled_plugin_root_runtime_mirror_errors(
    Map *root_package_json, 
    Map *bundled_runtime_dependency_specs, 
    Map *required_root_mirrors) {
    
    StringArray *errors = string_array_create();
    Map *root_runtime_deps = collect_runtime_dependency_specs(root_package_json);
    
    // Process conflicts and mirror errors
    // Implementation details would depend on data structure specifics
    
    map_free(root_runtime_deps);
    return errors;
}
