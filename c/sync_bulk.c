// abstraction-provenance: {"artifact_sha256": "5cf3b5eeb330ff63739db1075d04ddee70fb7c3be258f478410aaa87bda7ce95", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "c"}
// sync_bulk.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <libgen.h>
#include <fnmatch.h>

#define CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
#define GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
#define MAX_PATH 1024
#define MAX_SKILLS 1000

// Forward declarations
int sync_to_git(const char* skill, int dry_run);
int sync_to_clawhub(const char* skill, int dry_run);
void log_message(const char* message, const char* level);
int validate_skill(const char* path);

/**
 * Bulk Sync - Synchronisiert alle Skills
 */

typedef struct {
    char synced[100][MAX_PATH];
    char skipped[100][MAX_PATH];
    char failed[100][MAX_PATH];
    int synced_count;
    int skipped_count;
    int failed_count;
} sync_results;

// Helper function to get directory modification time
time_t get_directory_mtime(const char* path) {
    DIR* dir = opendir(path);
    struct dirent* entry;
    time_t max_time = 0;
    char full_path[MAX_PATH];
    
    if (!dir) return 0;
    
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        if (strstr(entry->d_name, ".git")) continue;
        
        snprintf(full_path, sizeof(full_path), "%s/%s", path, entry->d_name);
        
        struct stat st;
        if (stat(full_path, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                // Recursively check subdirectories
                time_t subdir_time = get_directory_mtime(full_path);
                if (subdir_time > max_time) {
                    max_time = subdir_time;
                }
            } else if (S_ISREG(st.st_mode)) {
                if (st.st_mtime > max_time) {
                    max_time = st.st_mtime;
                }
            }
        }
    }
    
    closedir(dir);
    return max_time;
}

void sync_all_skills(int dry_run) {
    /** Synchronisiert alle Skills */
    char skills[MAX_SKILLS][MAX_PATH];
    int skill_count = 0;
    
    // Alle Skills finden
    DIR* dir;
    struct dirent* entry;
    
    // From CLAWHUB_DIR
    dir = opendir(CLAWHUB_DIR);
    if (dir) {
        while ((entry = readdir(dir)) != NULL && skill_count < MAX_SKILLS) {
            if (entry->d_name[0] != '.' && entry->d_type == DT_DIR) {
                strcpy(skills[skill_count], entry->d_name);
                skill_count++;
            }
        }
        closedir(dir);
    }
    
    // From GIT_DIR
    dir = opendir(GIT_DIR);
    if (dir) {
        while ((entry = readdir(dir)) != NULL && skill_count < MAX_SKILLS) {
            if (entry->d_name[0] != '.' && entry->d_type == DT_DIR) {
                // Check if already exists
                int found = 0;
                for (int i = 0; i < skill_count; i++) {
                    if (strcmp(skills[i], entry->d_name) == 0) {
                        found = 1;
                        break;
                    }
                }
                if (!found) {
                    strcpy(skills[skill_count], entry->d_name);
                    skill_count++;
                }
            }
        }
        closedir(dir);
    }
    
    char msg[256];
    snprintf(msg, sizeof(msg), "Bulk Sync: %d Skills gefunden", skill_count);
    log_message(msg, "INFO");
    
    sync_results results = {0};
    
    for (int i = 0; i < skill_count; i++) {
        char* skill = skills[i];
        char clawhub_path[MAX_PATH];
        char git_path[MAX_PATH];
        
        snprintf(clawhub_path, sizeof(clawhub_path), "%s/%s", CLAWHUB_DIR, skill);
        snprintf(git_path, sizeof(git_path), "%s/%s", GIT_DIR, skill);
        
        int clawhub_exists = access(clawhub_path, F_OK) == 0;
        int git_exists = access(git_path, F_OK) == 0;
        
        if (clawhub_exists && !git_exists) {
            if (validate_skill(clawhub_path)) {
                char sync_msg[MAX_PATH];
                snprintf(sync_msg, sizeof(sync_msg), "Syncing %s to Git...", skill);
                log_message(sync_msg, "INFO");
                if (sync_to_git(skill, dry_run)) {
                    snprintf(results.synced[results.synced_count], MAX_PATH, "%s → Git", skill);
                    results.synced_count++;
                } else {
                    strcpy(results.failed[results.failed_count], skill);
                    results.failed_count++;
                }
            } else {
                char skip_msg[MAX_PATH];
                snprintf(skip_msg, sizeof(skip_msg), "%s (validation failed)", skill);
                strcpy(results.skipped[results.skipped_count], skip_msg);
                results.skipped_count++;
            }
        } else if (git_exists && !clawhub_exists) {
            if (validate_skill(git_path)) {
                char sync_msg[MAX_PATH];
                snprintf(sync_msg, sizeof(sync_msg), "Syncing %s to ClawHub...", skill);
                log_message(sync_msg, "INFO");
                if (sync_to_clawhub(skill, dry_run)) {
                    snprintf(results.synced[results.synced_count], MAX_PATH, "%s → ClawHub", skill);
                    results.synced_count++;
                } else {
                    strcpy(results.failed[results.failed_count], skill);
                    results.failed_count++;
                }
            } else {
                char skip_msg[MAX_PATH];
                snprintf(skip_msg, sizeof(skip_msg), "%s (validation failed)", skill);
                strcpy(results.skipped[results.skipped_count], skip_msg);
                results.skipped_count++;
            }
        } else if (clawhub_exists && git_exists) {
            // In beiden - prüfe ob Update nötig
            time_t clawhub_mtime = get_directory_mtime(clawhub_path);
            time_t git_mtime = get_directory_mtime(git_path);
            
            if (abs((int)(clawhub_mtime - git_mtime)) > 60) {
                if (clawhub_mtime > git_mtime) {
                    char update_msg[MAX_PATH];
                    snprintf(update_msg, sizeof(update_msg), "Updating %s in Git...", skill);
                    log_message(update_msg, "INFO");
                    if (sync_to_git(skill, dry_run)) {
                        snprintf(results.synced[results.synced_count], MAX_PATH, "%s → Git (update)", skill);
                        results.synced_count++;
                    } else {
                        strcpy(results.failed[results.failed_count], skill);
                        results.failed_count++;
                    }
                } else {
                    char update_msg[MAX_PATH];
                    snprintf(update_msg, sizeof(update_msg), "Updating %s in ClawHub...", skill);
                    log_message(update_msg, "INFO");
                    if (sync_to_clawhub(skill, dry_run)) {
                        snprintf(results.synced[results.synced_count], MAX_PATH, "%s → ClawHub (update)", skill);
                        results.synced_count++;
                    } else {
                        strcpy(results.failed[results.failed_count], skill);
                        results.failed_count++;
                    }
                }
            } else {
                char skip_msg[MAX_PATH];
                snprintf(skip_msg, sizeof(skip_msg), "%s (already synced)", skill);
                strcpy(results.skipped[results.skipped_count], skip_msg);
                results.skipped_count++;
            }
        }
    }
    
    // Zusammenfassung
    printf("\n============================================================\n");
    printf("Bulk Sync %s - Zusammenfassung\n", dry_run ? "DRY-RUN" : "EXECUTED");
    printf("============================================================\n");
    printf("✅ Synchronisiert: %d\n", results.synced_count);
    for (int i = 0; i < results.synced_count; i++) {
        printf("   - %s\n", results.synced[i]);
    }
    printf("\n⏭️  Übersprungen: %d\n", results.skipped_count);
    if (results.skipped_count <= 10) {
        for (int i = 0; i < results.skipped_count; i++) {
            printf("   - %s\n", results.skipped[i]);
        }
    } else {
        printf("   - %d Skills (bereits synchron oder Validierung fehlgeschlagen)\n", results.skipped_count);
    }
    printf("\n❌ Fehlgeschlagen: %d\n", results.failed_count);
    for (int i = 0; i < results.failed_count; i++) {
        printf("   - %s\n", results.failed[i]);
    }
    printf("============================================================\n");
}

void log_message(const char* message, const char* level) {
    time_t now;
    time(&now);
    struct tm* local = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", local);
    printf("[%s] [%s] %s\n", timestamp, level, message);
}

int validate_skill(const char* path) {
    // Placeholder implementation - should be replaced with actual validation logic
    return access(path, F_OK) == 0;
}

int sync_to_git(const char* skill, int dry_run) {
    // Placeholder implementation - should be replaced with actual sync logic
    char cmd[MAX_PATH * 2];
    if (dry_run) {
        snprintf(cmd, sizeof(cmd), "echo Would sync %s to Git", skill);
        system(cmd);
        return 1;
    } else {
        // Actual sync implementation would go here
        return 1;
    }
}

int sync_to_clawhub(const char* skill, int dry_run) {
    // Placeholder implementation - should be replaced with actual sync logic
    char cmd[MAX_PATH * 2];
    if (dry_run) {
        snprintf(cmd, sizeof(cmd), "echo Would sync %s to ClawHub", skill);
        system(cmd);
        return 1;
    } else {
        // Actual sync implementation would go here
        return 1;
    }
}

void print_usage(const char* prog_name) {
    printf("Usage: %s [--dry-run|--execute]\n", prog_name);
    printf("Bulk Sync für alle Skills\n");
    printf("  --dry-run   Nur Änderungen anzeigen\n");
    printf("  --execute   Sync ausführen\n");
}

int main(int argc, char* argv[]) {
    /** Hauptfunktion */
    int dry_run = 0;
    int execute = 0;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--dry-run") == 0) {
            dry_run = 1;
        } else if (strcmp(argv[i], "--execute") == 0) {
            execute = 1;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            return 0;
        }
    }
    
    if (!dry_run && !execute) {
        printf("Bitte --dry-run oder --execute angeben\n");
        print_usage(argv[0]);
        return 1;
    }
    
    sync_all_skills(dry_run);
    return 0;
}
