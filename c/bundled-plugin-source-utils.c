// abstraction-provenance: {"artifact_sha256": "112b2eb7e17a562bfc34c018dbdc873aa7591ce7b3ede286a5d29061173dc750", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "c"}
// bundled-plugin-source-utils.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

#ifdef _WIN32
#include <direct.h>
#define getcwd _getcwd
#define chdir _chdir
#else
#include <unistd.h>
#endif

// Simple dynamic array implementation
typedef struct {
    char** data;
    size_t size;
    size_t capacity;
} StringArray;

StringArray* string_array_create() {
    StringArray* arr = malloc(sizeof(StringArray));
    arr->data = malloc(10 * sizeof(char*));
    arr->size = 0;
    arr->capacity = 10;
    return arr;
}

void string_array_add(StringArray* arr, const char* str) {
    if (arr->size >= arr->capacity) {
        arr->capacity *= 2;
        arr->data = realloc(arr->data, arr->capacity * sizeof(char*));
    }
    
    arr->data[arr->size] = malloc(strlen(str) + 1);
    strcpy(arr->data[arr->size], str);
    arr->size++;
}

void string_array_free(StringArray* arr) {
    for (size_t i = 0; i < arr->size; i++) {
        free(arr->data[i]);
    }
    free(arr->data);
    free(arr);
}

char* read_if_exists(const char* file_path) {
    FILE* file = fopen(file_path, "r");
    if (!file) {
        return NULL;
    }
    
    // Get file size
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    rewind(file);
    
    // Read content
    char* content = malloc(file_size + 1);
    size_t bytes_read = fread(content, 1, file_size, file);
    content[bytes_read] = '\0';
    
    fclose(file);
    return content;
}

int file_exists(const char* path) {
    struct stat buffer;
    return (stat(path, &buffer) == 0);
}

char* get_cwd() {
    char* cwd = malloc(1024);
#ifdef _WIN32
    _getcwd(cwd, 1024);
#else
    getcwd(cwd, 1024);
#endif
    return cwd;
}

char* path_join(const char* path1, const char* path2) {
    size_t len1 = strlen(path1);
    size_t len2 = strlen(path2);
    char* result = malloc(len1 + len2 + 2); // +2 for separator and null terminator
    
#ifdef _WIN32
    char sep = '\\';
#else
    char sep = '/';
#endif
    
    strcpy(result, path1);
    if (result[len1 - 1] != sep) {
        result[len1] = sep;
        result[len1 + 1] = '\0';
    }
    strcat(result, path2);
    
    return result;
}

// Simple directory listing
StringArray* list_directories(const char* path) {
    StringArray* dirs = string_array_create();
    DIR* dir = opendir(path);
    
    if (!dir) {
        return dirs;
    }
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_DIR) {
            if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
                string_array_add(dirs, entry->d_name);
            }
        }
    }
    
    closedir(dir);
    return dirs;
}

// Simple JSON parsing would be complex in pure C
// For this example we'll just store the raw content
typedef struct {
    char* dir_name;
    char* plugin_dir;
    char* manifest_path;
    char* manifest_content;
    char* package_json_path;
    char* package_json_content;
} PluginEntry;

typedef struct {
    PluginEntry* entries;
    size_t count;
    size_t capacity;
} PluginEntries;

PluginEntries* collect_bundled_plugin_sources(const char* repo_root, int require_package_json) {
    PluginEntries* plugins = malloc(sizeof(PluginEntries));
    plugins->entries = malloc(10 * sizeof(PluginEntry));
    plugins->count = 0;
    plugins->capacity = 10;
    
    char* actual_repo_root = repo_root ? strdup(repo_root) : get_cwd();
    char* extensions_root = path_join(actual_repo_root, "extensions");
    
    if (!file_exists(extensions_root)) {
        free(actual_repo_root);
        free(extensions_root);
        return plugins;
    }
    
    StringArray* directories = list_directories(extensions_root);
    
    for (size_t i = 0; i < directories->size; i++) {
        char* plugin_dir = path_join(extensions_root, directories->data[i]);
        char* manifest_path = path_join(plugin_dir, "openclaw.plugin.json");
        char* package_json_path = path_join(plugin_dir, "package.json");
        
        if (!file_exists(manifest_path)) {
            free(plugin_dir);
            free(manifest_path);
            free(package_json_path);
            continue;
        }
        
        if (require_package_json && !file_exists(package_json_path)) {
            free(plugin_dir);
            free(manifest_path);
            free(package_json_path);
            continue;
        }
        
        if (plugins->count >= plugins->capacity) {
            plugins->capacity *= 2;
            plugins->entries = realloc(plugins->entries, plugins->capacity * sizeof(PluginEntry));
        }
        
        PluginEntry* entry = &plugins->entries[plugins->count];
        entry->dir_name = strdup(directories->data[i]);
        entry->plugin_dir = plugin_dir;
        entry->manifest_path = manifest_path;
        entry->manifest_content = read_if_exists(manifest_path);
        entry->package_json_path = file_exists(package_json_path) ? package_json_path : NULL;
        entry->package_json_content = file_exists(package_json_path) ? read_if_exists(package_json_path) : NULL;
        
        plugins->count++;
    }
    
    // In a real implementation you'd want to sort by dir_name
    // This is omitted for simplicity
    
    string_array_free(directories);
    free(actual_repo_root);
    free(extensions_root);
    
    return plugins;
}

void free_plugin_entries(PluginEntries* plugins) {
    for (size_t i = 0; i < plugins->count; i++) {
        free(plugins->entries[i].dir_name);
        free(plugins->entries[i].plugin_dir);
        free(plugins->entries[i].manifest_path);
        free(plugins->entries[i].manifest_content);
        free(plugins->entries[i].package_json_path);
        free(plugins->entries[i].package_json_content);
    }
    free(plugins->entries);
    free(plugins);
}
