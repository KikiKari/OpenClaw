// abstraction-provenance: {"artifact_sha256": "ce294ff3cf2722da95e0dbc19e45e83c5817a948f5bb9d226e5443aea9e8e2be", "source_sha256": "5ea1a8c9a13631404f27bfdb1410099cd81f89038616abac4b49bd62666db56a", "target_language": "c"}
// secret-scan.mjs — portiert nach c
// Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <regex.h>
#include <libgen.h>

#define MAX_PATH 4096
#define MAX_FINDINGS 1000

const char *skipped[] = {
    "node_modules",
    ".next",
    ".git",
    ".pytest_cache",
    "__pycache__",
    "media-production/raw",
    "media-production/private",
    NULL
};

const char *patterns[] = {
    "sk-(proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}",
    "(nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}",
    "ELEVENLABS_API_KEY[[:space:]]*=[[:space:]]*[\"']?[A-Za-z0-9]{20,}",
    "WAVESPEED_API_KEY[[:space:]]*=[[:space:]]*[\"']?[A-Za-z0-9]{20,}",
    NULL
};

char *findings[MAX_FINDINGS];
int finding_count = 0;

int is_skipped(const char *relative_path) {
    for (int i = 0; skipped[i] != NULL; i++) {
        if (strcmp(relative_path, skipped[i]) == 0) {
            return 1;
        }
        
        size_t len = strlen(skipped[i]);
        if (strncmp(relative_path, skipped[i], len) == 0 && 
            (relative_path[len] == '/' || relative_path[len] == '\0')) {
            return 1;
        }
        
        char *path_copy = strdup(relative_path);
        char *token = strtok(path_copy, "/");
        while (token != NULL) {
            if (strcmp(token, skipped[i]) == 0) {
                free(path_copy);
                return 1;
            }
            token = strtok(NULL, "/");
        }
        free(path_copy);
    }
    return 0;
}

int should_skip_file(const char *filename, const char *relative_path) {
    if (strcmp(filename, ".env") == 0) return 1;
    if (strncmp(filename, ".env.", 5) == 0 && strcmp(filename, ".env.example") != 0) return 1;
    if (is_skipped(relative_path)) return 1;
    return 0;
}

void add_finding(const char *path) {
    if (finding_count >= MAX_FINDINGS) return;
    
    for (int i = 0; i < finding_count; i++) {
        if (strcmp(findings[i], path) == 0) return;
    }
    
    findings[finding_count] = strdup(path);
    finding_count++;
}

int file_contains_pattern(const char *filepath) {
    FILE *file = fopen(filepath, "r");
    if (!file) return 0;

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    if (file_size > 2000000) {
        fclose(file);
        return 0;
    }
    rewind(file);

    char *content = malloc(file_size + 1);
    if (!content) {
        fclose(file);
        return 0;
    }

    size_t read_size = fread(content, 1, file_size, file);
    content[read_size] = '\0';
    fclose(file);

    regex_t regex;
    int result = 0;
    for (int i = 0; patterns[i] != NULL; i++) {
        if (regcomp(&regex, patterns[i], REG_EXTENDED) == 0) {
            if (regexec(&regex, content, 0, NULL, 0) == 0) {
                result = 1;
                regfree(&regex);
                break;
            }
        }
        regfree(&regex);
    }

    free(content);
    return result;
}

void walk_directory(const char *base_path, const char *relative_path) {
    DIR *dir = opendir(base_path);
    if (!dir) return;

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;

        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", base_path, entry->d_name);

        char rel_path[MAX_PATH];
        if (strlen(relative_path) == 0) {
            strcpy(rel_path, entry->d_name);
        } else {
            snprintf(rel_path, sizeof(rel_path), "%s/%s", relative_path, entry->d_name);
        }

        if (should_skip_file(entry->d_name, rel_path)) continue;

        struct stat statbuf;
        if (stat(full_path, &statbuf) == -1) continue;

        if (S_ISDIR(statbuf.st_mode)) {
            walk_directory(full_path, rel_path);
        } else if (statbuf.st_size < 2000000) {
            if (file_contains_pattern(full_path)) {
                add_finding(rel_path);
            }
        }
    }

    closedir(dir);
}

int main() {
    char current_dir[MAX_PATH];
    if (getcwd(current_dir, sizeof(current_dir)) == NULL) {
        fprintf(stderr, "Konnte aktuelles Verzeichnis nicht ermitteln\n");
        return 1;
    }

    char root_path[MAX_PATH];
    snprintf(root_path, sizeof(root_path), "%s/..", current_dir);

    walk_directory(root_path, "");

    if (finding_count > 0) {
        fprintf(stderr, "Secret-Scan fehlgeschlagen: ");
        for (int i = 0; i < finding_count; i++) {
            if (i > 0) fprintf(stderr, ", ");
            fprintf(stderr, "%s", findings[i]);
            free(findings[i]);
        }
        fprintf(stderr, "\n");
        return 1;
    }

    printf("Secret-Scan bestanden.\n");
    return 0;
}
