// abstraction-provenance: {"artifact_sha256": "0c08bb1f606560d09c4df1443087b26ec4cedb77f04fb4879ef30d3df946073f", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "c"}
// bundle-a2ui.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <dirent.h>
#include <openssl/sha.h>
#include <fcntl.h>

#define MAX_PATH 4096
#define MAX_FILES 10000

const char* root_dir = ".."; // This would need to be computed properly
const char* hash_file = "src/canvas-host/a2ui/.bundle.hash";
const char* output_file = "src/canvas-host/a2ui/a2ui.bundle.js";
const char* a2ui_renderer_dir = "vendor/a2ui/renderers/lit";
const char* a2ui_app_dir = "apps/shared/OpenClawKit/Tools/CanvasA2UI";

const char* input_paths[] = {
    "package.json",
    "pnpm-lock.yaml",
    "vendor/a2ui/renderers/lit",
    "apps/shared/OpenClawKit/Tools/CanvasA2UI",
    NULL
};

const char* ignored_bundle_hash_input_prefixes[] = {
    "vendor/a2ui/renderers/lit/dist",
    NULL
};

char* normalize_path(const char* path) {
    char* result = strdup(path);
    for (int i = 0; result[i]; i++) {
        if (result[i] == '\\') {
            result[i] = '/';
        }
    }
    return result;
}

void fail(const char* message) {
    fprintf(stderr, "%s\n", message);
    fprintf(stderr, "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle\n");
    fprintf(stderr, "If this persists, verify pnpm deps and try again.\n");
    exit(1);
}

int path_exists(const char* path) {
    struct stat st;
    return stat(path, &st) == 0;
}

int is_bundle_hash_input_path(const char* file_path) {
    char* relative_path = normalize_path(file_path); // Simplified - should compute relative path
    
    for (int i = 0; ignored_bundle_hash_input_prefixes[i]; i++) {
        if (strcmp(relative_path, ignored_bundle_hash_input_prefixes[i]) == 0 ||
            strncmp(relative_path, ignored_bundle_hash_input_prefixes[i], strlen(ignored_bundle_hash_input_prefixes[i])) == 0) {
            free(relative_path);
            return 0;
        }
    }
    free(relative_path);
    return 1;
}

void get_local_rolldown_cli_candidates(char candidates[][MAX_PATH], int* count) {
    *count = 0;
    snprintf(candidates[(*count)++], MAX_PATH, "%s/node_modules/rolldown/bin/cli.mjs", root_dir);
    snprintf(candidates[(*count)++], MAX_PATH, "%s/node_modules/.pnpm/node_modules/rolldown/bin/cli.mjs", root_dir);
    snprintf(candidates[(*count)++], MAX_PATH, "%s/node_modules/.pnpm/rolldown@1.0.0-rc.12/node_modules/rolldown/bin/cli.mjs", root_dir);
}

void walk_files(const char* entry_path, char files[][MAX_PATH], int* file_count) {
    if (!is_bundle_hash_input_path(entry_path)) {
        return;
    }
    
    struct stat st;
    if (stat(entry_path, &st) != 0) {
        return;
    }
    
    if (!S_ISDIR(st.st_mode)) {
        strcpy(files[*file_count], entry_path);
        (*file_count)++;
        return;
    }
    
    DIR* dir = opendir(entry_path);
    if (!dir) return;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        char full_path[MAX_PATH];
        snprintf(full_path, MAX_PATH, "%s/%s", entry_path, entry->d_name);
        walk_files(full_path, files, file_count);
    }
    closedir(dir);
}

int list_tracked_input_files(char files[][MAX_PATH]) {
    // Simplified implementation - would need to call git command
    return 0;
}

void compute_hash(char* hash_result) {
    char files[MAX_FILES][MAX_PATH];
    int file_count = 0;
    
    if (!list_tracked_input_files(files)) {
        for (int i = 0; input_paths[i]; i++) {
            walk_files(input_paths[i], files, &file_count);
        }
    }
    
    // Sort files - simplified
    for (int i = 0; i < file_count - 1; i++) {
        for (int j = i + 1; j < file_count; j++) {
            if (strcmp(files[i], files[j]) > 0) {
                char temp[MAX_PATH];
                strcpy(temp, files[i]);
                strcpy(files[i], files[j]);
                strcpy(files[j], temp);
            }
        }
    }
    
    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    
    for (int i = 0; i < file_count; i++) {
        char* relative_path = normalize_path(files[i]); // Should compute proper relative path
        SHA256_Update(&sha256, relative_path, strlen(relative_path));
        SHA256_Update(&sha256, "\0", 1);
        
        FILE* f = fopen(files[i], "rb");
        if (f) {
            char buffer[8192];
            size_t bytes;
            while ((bytes = fread(buffer, 1, sizeof(buffer), f)) > 0) {
                SHA256_Update(&sha256, buffer, bytes);
            }
            fclose(f);
        }
        SHA256_Update(&sha256, "\0", 1);
        free(relative_path);
    }
    
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256_Final(hash, &sha256);
    
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        sprintf(hash_result + (i * 2), "%02x", hash[i]);
    }
    hash_result[SHA256_DIGEST_LENGTH * 2] = '\0';
}

int run_step(const char* command, char* args[]) {
    pid_t pid = fork();
    if (pid == 0) {
        execvp(command, args);
        perror("execvp failed");
        exit(1);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        return WEXITSTATUS(status);
    } else {
        perror("fork failed");
        return -1;
    }
}

int run_pnpm(char* pnpm_args[]) {
    // Simplified - would need to implement pnpm runner resolution
    char* args[100];
    args[0] = "pnpm";
    for (int i = 0; pnpm_args[i]; i++) {
        args[i + 1] = pnpm_args[i];
    }
    args[10] = NULL;
    
    return run_step("pnpm", args);
}

int main() {
    int has_renderer_dir = path_exists(a2ui_renderer_dir);
    int has_app_dir = path_exists(a2ui_app_dir);
    int has_output_file = path_exists(output_file);
    
    if (!has_renderer_dir || !has_app_dir) {
        if (has_output_file) {
            printf("A2UI sources missing; keeping prebuilt bundle.\n");
            return 0;
        }
        if (getenv("OPENCLAW_SPARSE_PROFILE") || 
            (getenv("OPENCLAW_A2UI_SKIP_MISSING") && strcmp(getenv("OPENCLAW_A2UI_SKIP_MISSING"), "1") == 0)) {
            fprintf(stderr, "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set.\n");
            return 0;
        }
        fail("A2UI sources missing and no prebuilt bundle found");
    }
    
    char current_hash[SHA256_DIGEST_LENGTH * 2 + 1];
    compute_hash(current_hash);
    
    if (path_exists(hash_file)) {
        char previous_hash[SHA256_DIGEST_LENGTH * 2 + 1];
        FILE* f = fopen(hash_file, "r");
        if (f) {
            fgets(previous_hash, sizeof(previous_hash), f);
            previous_hash[strcspn(previous_hash, "\n")] = 0;
            fclose(f);
            
            if (strcmp(previous_hash, current_hash) == 0 && has_output_file) {
                printf("A2UI bundle up to date; skipping.\n");
                return 0;
            }
        }
    }
    
    char* tsc_args[] = {"-s", "exec", "tsc", "-p", "vendor/a2ui/renderers/lit/tsconfig.json", NULL};
    run_pnpm(tsc_args);
    
    char rolldown_candidates[3][MAX_PATH];
    int candidate_count;
    get_local_rolldown_cli_candidates(rolldown_candidates, &candidate_count);
    
    int found_local_rolldown = 0;
    for (int i = 0; i < candidate_count; i++) {
        if (path_exists(rolldown_candidates[i])) {
            char* rolldown_args[] = {rolldown_candidates[i], "-c", "apps/shared/OpenClawKit/Tools/CanvasA2UI/rolldown.config.mjs", NULL};
            run_step("node", rolldown_args);
            found_local_rolldown = 1;
            break;
        }
    }
    
    if (!found_local_rolldown) {
        char* rolldown_args[] = {"-s", "exec", "rolldown", "-c", "apps/shared/OpenClawKit/Tools/CanvasA2UI/rolldown.config.mjs", NULL};
        run_pnpm(rolldown_args);
    }
    
    FILE* f = fopen(hash_file, "w");
    if (f) {
        fprintf(f, "%s\n", current_hash);
        fclose(f);
    }
    
    return 0;
}
