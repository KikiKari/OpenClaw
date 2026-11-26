// abstraction-provenance: {"artifact_sha256": "edf26a8510e9fe1dc93761f6288092f94e093838a91bb0ffd8ee1075065695a0", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "c"}
// bundled-plugin-build-entries.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <libgen.h>

// Mocking Node.js-like functionality in C
#define BUNDLED_PLUGIN_ROOT_DIR "plugins"
#define MAX_PATH 4096
#define MAX_ENTRIES 1024

typedef struct {
    char* name;
    int isDirectory;
    int isFile;
} Dirent;

typedef struct {
    char* id;
    int hasManifest;
    int hasPackageJson;
    char** sourceEntries;
    int sourceEntriesCount;
} BundledPluginEntry;

// Function prototypes
int fileExists(const char* path);
char* readFile(const char* path);
char* getExtension(const char* filename);
int isTopLevelPublicSurfaceExtension(const char* ext);
int isExcludedFile(const char* filename);
char** collectTopLevelPublicSurfaceEntries(const char* pluginDir, int* count);
BundledPluginEntry* collectBundledPluginBuildEntries(int* count);
char** listBundledPluginBuildEntries(int* count);
char** listBundledPluginPackArtifacts(int* count);
char** listBundledPluginRuntimeDependencies(int* count);

// Helper function to check if file exists
int fileExists(const char* path) {
    struct stat buffer;
    return (stat(path, &buffer) == 0);
}

// Helper function to read file content (simplified)
char* readFile(const char* path) {
    FILE* file = fopen(path, "r");
    if (!file) return NULL;
    
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    char* content = malloc(length + 1);
    fread(content, 1, length, file);
    content[length] = '\0';
    
    fclose(file);
    return content;
}

// Get file extension
char* getExtension(const char* filename) {
    char* dot = strrchr(filename, '.');
    if (!dot || dot == filename) return "";
    return dot;
}

// Check if extension is in allowed set
int isTopLevelPublicSurfaceExtension(const char* ext) {
    const char* extensions[] = {".ts", ".js", ".mts", ".cts", ".mjs", ".cjs", NULL};
    for (int i = 0; extensions[i]; i++) {
        if (strcmp(ext, extensions[i]) == 0) return 1;
    }
    return 0;
}

// Check if file should be excluded
int isExcludedFile(const char* filename) {
    char lower_filename[MAX_PATH];
    strcpy(lower_filename, filename);
    
    // Convert to lowercase for comparison
    for (int i = 0; lower_filename[i]; i++) {
        lower_filename[i] = tolower(lower_filename[i]);
    }
    
    // Check exclusion patterns
    if (strstr(lower_filename, ".d.ts")) return 1;
    if (strstr(lower_filename, "config-api.") && 
        (strstr(lower_filename, ".ts") || strstr(lower_filename, ".js"))) return 1;
    if (strstr(lower_filename, ".test.")) return 1;
    if (strstr(lower_filename, ".spec.")) return 1;
    if (strstr(lower_filename, ".fixture.")) return 1;
    if (strstr(lower_filename, ".snap")) return 1;
    
    return 0;
}

// Collect top level public surface entries
char** collectTopLevelPublicSurfaceEntries(const char* pluginDir, int* count) {
    *count = 0;
    char** entries = malloc(MAX_ENTRIES * sizeof(char*));
    
    DIR* dir = opendir(pluginDir);
    if (!dir) return entries;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type != DT_REG) continue; // Only files
        
        const char* ext = getExtension(entry->d_name);
        if (!isTopLevelPublicSurfaceExtension(ext)) continue;
        
        if (isExcludedFile(entry->d_name)) continue;
        
        // Add entry
        char* entry_path = malloc(MAX_PATH);
        snprintf(entry_path, MAX_PATH, "./%s", entry->d_name);
        entries[*count] = entry_path;
        (*count)++;
    }
    
    closedir(dir);
    return entries;
}

// Main function to collect bundled plugin build entries
BundledPluginEntry* collectBundledPluginBuildEntries(int* count) {
    *count = 0;
    BundledPluginEntry* entries = malloc(MAX_ENTRIES * sizeof(BundledPluginEntry));
    
    char extensionsRoot[MAX_PATH];
    snprintf(extensionsRoot, MAX_PATH, "%s/%s", getenv("PWD"), BUNDLED_PLUGIN_ROOT_DIR);
    
    DIR* dir = opendir(extensionsRoot);
    if (!dir) return entries;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type != DT_DIR || strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
        
        // Build paths
        char pluginDir[MAX_PATH];
        snprintf(pluginDir, MAX_PATH, "%s/%s", extensionsRoot, entry->d_name);
        
        char manifestPath[MAX_PATH];
        snprintf(manifestPath, MAX_PATH, "%s/openclaw.plugin.json", pluginDir);
        
        int hasManifest = fileExists(manifestPath);
        
        // For simplicity, we're not parsing package.json in this C version
        int hasPackageJson = 0;
        
        int topLevelCount = 0;
        char** topLevelEntries = collectTopLevelPublicSurfaceEntries(pluginDir, &topLevelCount);
        
        // Create entry
        entries[*count].id = strdup(entry->d_name);
        entries[*count].hasManifest = hasManifest;
        entries[*count].hasPackageJson = hasPackageJson;
        entries[*count].sourceEntries = topLevelEntries;
        entries[*count].sourceEntriesCount = topLevelCount;
        (*count)++;
    }
    
    closedir(dir);
    return entries;
}

// List bundled plugin build entries
char** listBundledPluginBuildEntries(int* count) {
    *count = 0;
    char** result = malloc(MAX_ENTRIES * sizeof(char*));
    
    int pluginCount = 0;
    BundledPluginEntry* entries = collectBundledPluginBuildEntries(&pluginCount);
    
    for (int i = 0; i < pluginCount; i++) {
        for (int j = 0; j < entries[i].sourceEntriesCount; j++) {
            // Simplified transformation of entry key
            char* entry = entries[i].sourceEntries[j];
            // Remove ./ prefix
            if (entry[0] == '.' && entry[1] == '/') {
                entry += 2;
            }
            
            // Create result entry (simplified)
            char* result_entry = malloc(MAX_PATH);
            snprintf(result_entry, MAX_PATH, "%s/%s/%s", BUNDLED_PLUGIN_ROOT_DIR, entries[i].id, entry);
            result[*count] = result_entry;
            (*count)++;
        }
    }
    
    return result;
}

// List bundled plugin pack artifacts
char** listBundledPluginPackArtifacts(int* count) {
    *count = 0;
    char** artifacts = malloc(MAX_ENTRIES * sizeof(char*));
    
    int pluginCount = 0;
    BundledPluginEntry* entries = collectBundledPluginBuildEntries(&pluginCount);
    
    for (int i = 0; i < pluginCount; i++) {
        // Skip non-packaged plugins (simplified check)
        if (strcmp(entries[i].id, "qa-channel") == 0 || strcmp(entries[i].id, "qa-lab") == 0) continue;
        
        if (entries[i].hasManifest) {
            char* artifact = malloc(MAX_PATH);
            snprintf(artifact, MAX_PATH, "dist/%s/openclaw.plugin.json", entries[i].id);
            artifacts[*count] = artifact;
            (*count)++;
        }
        
        if (entries[i].hasPackageJson) {
            char* artifact = malloc(MAX_PATH);
            snprintf(artifact, MAX_PATH, "dist/%s/package.json", entries[i].id);
            artifacts[*count] = artifact;
            (*count)++;
        }
        
        for (int j = 0; j < entries[i].sourceEntriesCount; j++) {
            char* entry = entries[i].sourceEntries[j];
            // Remove ./ prefix and extension
            if (entry[0] == '.' && entry[1] == '/') {
                entry += 2;
            }
            
            char* dot = strrchr(entry, '.');
            if (dot) *dot = '\0';
            
            char* artifact = malloc(MAX_PATH);
            snprintf(artifact, MAX_PATH, "dist/%s/%s.js", entries[i].id, entry);
            artifacts[*count] = artifact;
            (*count)++;
        }
    }
    
    return artifacts;
}

// List bundled plugin runtime dependencies (simplified)
char** listBundledPluginRuntimeDependencies(int* count) {
    *count = 0;
    char** dependencies = malloc(MAX_ENTRIES * sizeof(char*));
    
    // In a real implementation, this would parse package.json files
    // For now, returning empty array as we don't have package.json parsing in C
    return dependencies;
}
