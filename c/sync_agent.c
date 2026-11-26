// abstraction-provenance: {"artifact_sha256": "7e84bb52ec4c5f5f495747b2bcbc250b021b79b86d45331ea6c1b0e0e4a9e7cf", "source_sha256": "b470dd345a01d0a6c2fec8e2dd8ccd0a3b59e67f44ce1aa0e6f4d9c34420b355", "target_language": "c"}
// sync_agent.py — portiert nach c
// Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <json-c/json.h>

/*
 * Permanenter ClawHub ↔ Git Sync Agent
 * Multi-Node fähig, stündliche Ausführung
 */

#define CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
#define GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
#define STATE_FILE "/home/openclaw/.openclaw/workspace/db/sync_state.json"
#define MAX_PATH 1024
#define MAX_NAME 256

// Reserved skill names array (example)
const char* RESERVED_SKILL_NAMES[] = {"template", "base"};
int RESERVED_COUNT = 2;

// Function declarations
struct json_object* load_state();
void save_state(struct json_object* state);
void log_message(const char* message, const char* level);
int is_reserved_skill(const char* name);
int validate_skill(const char* path);
char* get_file_hash(const char* filepath);
void iter_sync_files(const char* dirpath, void (*callback)(const char*, const char*));
int sync_to_git(const char* skill_name, int dry_run);
int sync_to_clawhub(const char* skill_name, int dry_run);
void init_git_repo(const char* skill_path, const char* skill_name);
char* preview_changes(const char* source_dir, const char* target_dir);
double newest_mtime(const char* skill_dir);
void sync_skill_bidirectional(const char* skill_name);

// Logging function
void log_message(const char* message, const char* level) {
    time_t now;
    time(&now);
    char* time_str = ctime(&now);
    time_str[strlen(time_str)-1] = '\0'; // Remove newline
    if (level && strcmp(level, "ERROR") == 0) {
        fprintf(stderr, "[%s] ERROR: %s\n", time_str, message);
    } else {
        printf("[%s] %s\n", time_str, message);
    }
    fflush(stdout);
}

// Load state from JSON file
struct json_object* load_state() {
    FILE* file = fopen(STATE_FILE, "r");
    if (!file) {
        // Return default empty state
        struct json_object* obj = json_object_new_object();
        json_object_object_add(obj, "sync_history", json_object_new_array());
        json_object_object_add(obj, "pending", json_object_new_array());
        return obj;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = malloc(length + 1);
    fread(buffer, 1, length, file);
    buffer[length] = '\0';
    fclose(file);

    struct json_object* obj = json_tokener_parse(buffer);
    free(buffer);

    if (!obj) {
        obj = json_object_new_object();
        json_object_object_add(obj, "sync_history", json_object_new_array());
        json_object_object_add(obj, "pending", json_object_new_array());
    }

    return obj;
}

// Save state to JSON file
void save_state(struct json_object* state) {
    // Ensure directory exists
    char dir_path[MAX_PATH];
    strncpy(dir_path, STATE_FILE, sizeof(dir_path));
    char* last_slash = strrchr(dir_path, '/');
    if (last_slash) {
        *last_slash = '\0';
        mkdir(dir_path, 0755); // Create directory if needed
    }

    FILE* file = fopen(STATE_FILE, "w");
    if (file) {
        const char* output = json_object_to_json_string_ext(state, JSON_C_TO_STRING_PRETTY);
        fputs(output, file);
        fclose(file);
    }
}

// Check if a skill name is reserved
int is_reserved_skill(const char* name) {
    for (int i = 0; i < RESERVED_COUNT; i++) {
        if (strcmp(name, RESERVED_SKILL_NAMES[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

// Validate skill by checking SKILL.md existence
int validate_skill(const char* path) {
    char skill_md_path[MAX_PATH];
    snprintf(skill_md_path, sizeof(skill_md_path), "%s/SKILL.md", path);
    return access(skill_md_path, F_OK) == 0;
}

// Get file hash (placeholder implementation)
char* get_file_hash(const char* filepath) {
    static char hash[33]; // MD5 is 32 chars + null terminator
    snprintf(hash, sizeof(hash), "hash_placeholder_for_%s", filepath);
    return hash;
}

// Iterate over sync files (placeholder callback-based approach)
void iter_sync_files(const char* dirpath, void (*callback)(const char*, const char*)) {
    DIR* dir = opendir(dirpath);
    if (!dir) return;

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue; // Skip hidden files/dirs

        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", dirpath, entry->d_name);

        struct stat statbuf;
        if (stat(full_path, &statbuf) == 0 && S_ISREG(statbuf.st_mode)) {
            callback(full_path, entry->d_name);
        }
    }
    closedir(dir);
}

// Placeholder sync functions
int sync_to_git(const char* skill_name, int dry_run) {
    if (dry_run) {
        log_message("Dry run sync to git", NULL);
        return 1;
    }
    log_message("Syncing to git", NULL);
    return 1;
}

int sync_to_clawhub(const char* skill_name, int dry_run) {
    if (dry_run) {
        log_message("Dry run sync to clawhub", NULL);
        return 1;
    }
    log_message("Syncing to clawhub", NULL);
    return 1;
}

// Initialize Git repository
void init_git_repo(const char* skill_path, const char* skill_name) {
    chdir(skill_path);
    system("git init > /dev/null 2>&1");
    system("git add . > /dev/null 2>&1");

    char commit_cmd[512];
    snprintf(commit_cmd, sizeof(commit_cmd), "git commit -m \"Initial commit: %s skill\" > /dev/null 2>&1", skill_name);
    system(commit_cmd);

    log_message("Git initialized", NULL);
}

// Preview changes between directories
char* preview_changes(const char* source_dir, const char* target_dir) {
    static char changes[4096] = "";
    changes[0] = '\0';

    DIR* dir = opendir(source_dir);
    if (!dir) return changes;

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;

        char src_file[MAX_PATH], tgt_file[MAX_PATH];
        snprintf(src_file, sizeof(src_file), "%s/%s", source_dir, entry->d_name);
        snprintf(tgt_file, sizeof(tgt_file), "%s/%s", target_dir, entry->d_name);

        struct stat tgt_stat;
        if (access(tgt_file, F_OK) != 0) {
            strncat(changes, "ADD ", sizeof(changes) - strlen(changes) - 1);
            strncat(changes, entry->d_name, sizeof(changes) - strlen(changes) - 1);
            strncat(changes, ";", sizeof(changes) - strlen(changes) - 1);
        } else {
            char* src_hash = get_file_hash(src_file);
            char* tgt_hash = get_file_hash(tgt_file);
            if (strcmp(src_hash, tgt_hash) != 0) {
                strncat(changes, "UPDATE ", sizeof(changes) - strlen(changes) - 1);
                strncat(changes, entry->d_name, sizeof(changes) - strlen(changes) - 1);
                strncat(changes, ";", sizeof(changes) - strlen(changes) - 1);
            }
        }
    }
    closedir(dir);

    return changes;
}

// Get newest modification time
double newest_mtime(const char* skill_dir) {
    double max_time = 0.0;
    DIR* dir = opendir(skill_dir);
    if (!dir) return max_time;

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;

        char file_path[MAX_PATH];
        snprintf(file_path, sizeof(file_path), "%s/%s", skill_dir, entry->d_name);

        struct stat statbuf;
        if (stat(file_path, &statbuf) == 0) {
            if (statbuf.st_mtime > max_time) {
                max_time = statbuf.st_mtime;
            }
        }
    }
    closedir(dir);
    return max_time;
}

// Bidirectional sync of a single skill
void sync_skill_bidirectional(const char* skill_name) {
    char clawhub_path[MAX_PATH], git_path[MAX_PATH];
    snprintf(clawhub_path, sizeof(clawhub_path), "%s/%s", CLAWHUB_DIR, skill_name);
    snprintf(git_path, sizeof(git_path), "%s/%s", GIT_DIR, skill_name);

    int clawhub_exists = access(clawhub_path, F_OK) == 0;
    int git_exists = access(git_path, F_OK) == 0;

    // Case 1: Only in ClawHub -> to Git
    if (clawhub_exists && !git_exists) {
        log_message("NEW in ClawHub: syncing to Git", NULL);
        if (sync_to_git(skill_name, 0)) {
            init_git_repo(git_path, skill_name);
        }
    }
    // Case 2: Only in Git -> to ClawHub
    else if (git_exists && !clawhub_exists) {
        log_message("NEW in Git: syncing to ClawHub", NULL);
        sync_to_clawhub(skill_name, 0);
    }
    // Case 3: Both exist
    else if (clawhub_exists && git_exists) {
        if (!validate_skill(clawhub_path)) {
            log_message("Validation failed for ClawHub skill", "ERROR");
            return;
        }
        if (!validate_skill(git_path)) {
            log_message("Validation failed for Git skill", "ERROR");
            return;
        }

        char* clawhub_changes = preview_changes(clawhub_path, git_path);
        char* git_changes = preview_changes(git_path, clawhub_path);

        if (strlen(clawhub_changes) == 0 && strlen(git_changes) == 0) {
            log_message("Content is identical", NULL);
            return;
        }

        if (strlen(clawhub_changes) > 0 && strlen(git_changes) == 0) {
            log_message("UPDATE: ClawHub content is newer or different -> syncing to Git", NULL);
            if (sync_to_git(skill_name, 0)) {
                chdir(git_path);
                system("git add . > /dev/null 2>&1");
                
                time_t now = time(NULL);
                struct tm* tm_info = localtime(&now);
                char timestamp[64];
                strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M", tm_info);
                
                char commit_cmd[512];
                snprintf(commit_cmd, sizeof(commit_cmd), 
                         "git commit -m \"Sync from ClawHub content diff: %s\" > /dev/null 2>&1", 
                         timestamp);
                system(commit_cmd);
            } else {
                log_message("Failed to sync to Git after content diff", "ERROR");
            }
        } else if (strlen(git_changes) > 0 && strlen(clawhub_changes) == 0) {
            log_message("UPDATE: Git content is newer or different -> syncing to ClawHub", NULL);
            if (!sync_to_clawhub(skill_name, 0)) {
                log_message("Failed to sync to ClawHub after content diff", "ERROR");
            }
        } else {
            log_message("Content difference detected", NULL);
            if (newest_mtime(clawhub_path) >= newest_mtime(git_path)) {
                log_message("UPDATE: ClawHub content is newer or different -> syncing to Git", NULL);
                if (sync_to_git(skill_name, 0)) {
                    chdir(git_path);
                    system("git add . > /dev/null 2>&1");
                    
                    time_t now = time(NULL);
                    struct tm* tm_info = localtime(&now);
                    char timestamp[64];
                    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M", tm_info);
                    
                    char commit_cmd[512];
                    snprintf(commit_cmd, sizeof(commit_cmd), 
                             "git commit -m \"Sync from ClawHub content diff: %s\" > /dev/null 2>&1", 
                             timestamp);
                    system(commit_cmd);
                } else {
                    log_message("Failed to sync to Git after content diff", "ERROR");
                }
            } else {
                log_message("UPDATE: Git content is newer or different -> syncing to ClawHub", NULL);
                if (!sync_to_clawhub(skill_name, 0)) {
                    log_message("Failed to sync to ClawHub after content diff", "ERROR");
                }
            }
        }
    }
}

// Main function
int main() {
    log_message("=== ClawHub ↔ Git Sync Agent gestartet ===", NULL);

    // Load previous state
    struct json_object* state = load_state();

    // Find all skills
    DIR* clawhub_dir = opendir(CLAWHUB_DIR);
    DIR* git_dir = opendir(GIT_DIR);
    
    if (!clawhub_dir || !git_dir) {
        log_message("Cannot open skill directories", "ERROR");
        return 1;
    }

    // Collect unique skill names
    char skills[1000][MAX_NAME];
    int skill_count = 0;

    struct dirent* entry;
    while ((entry = readdir(clawhub_dir)) != NULL) {
        if (entry->d_name[0] == '.' || is_reserved_skill(entry->d_name)) continue;

        char skill_md_path[MAX_PATH];
        snprintf(skill_md_path, sizeof(skill_md_path), "%s/%s/SKILL.md", CLAWHUB_DIR, entry->d_name);
        if (access(skill_md_path, F_OK) == 0) {
            strcpy(skills[skill_count++], entry->d_name);
        }
    }

    while ((entry = readdir(git_dir)) != NULL) {
        if (entry->d_name[0] == '.' || is_reserved_skill(entry->d_name)) continue;

        char skill_md_path[MAX_PATH];
        snprintf(skill_md_path, sizeof(skill_md_path), "%s/%s/SKILL.md", GIT_DIR, entry->d_name);
        if (access(skill_md_path, F_OK) == 0) {
            int found = 0;
            for (int i = 0; i < skill_count; i++) {
                if (strcmp(skills[i], entry->d_name) == 0) {
                    found = 1;
                    break;
                }
            }
            if (!found) {
                strcpy(skills[skill_count++], entry->d_name);
            }
        }
    }

    closedir(clawhub_dir);
    closedir(git_dir);

    log_message("--- Dry-Run Phase Start ---", NULL);
    for (int i = 0; i < skill_count; i++) {
        sync_to_git(skills[i], 1);
        sync_to_clawhub(skills[i], 1);
    }
    log_message("--- Dry-Run Phase End ---", NULL);

    // Actual Sync Phase
    for (int i = 0; i < skill_count; i++) {
        sync_skill_bidirectional(skills[i]);
    }

    // Summary would go here...

    log_message("=== Sync Agent beendet ===", NULL);

    // Cleanup
    json_object_put(state);

    return 0;
}
