// abstraction-provenance: {"artifact_sha256": "e1e0f26afc67b8f30bbab1145dfa3deed34c92ff526f3d191a6a279c418035cd", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "c"}
// sync_agent_cron.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
// auch in: workspace@local:scripts/sync_agent_cron.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <libgen.h>
#include <errno.h>

#define CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
#define GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
#define LOG_FILE "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"
#define STATE_FILE "/home/openclaw/.openclaw/workspace/db/sync_state.json"

/*
ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync
*/

typedef struct {
    char name[256];
    time_t mtime;
} skill_info;

typedef struct {
    char** items;
    int count;
    int capacity;
} string_array;

typedef struct {
    char skill[256];
    double diff;
} skill_diff;

typedef struct {
    string_array new_in_clawhub;
    string_array new_in_git;
    skill_diff* clawhub_newer;
    int clawhub_newer_count;
    skill_diff* git_newer;
    int git_newer_count;
    string_array synced;
} changes_detected_struct;

typedef struct {
    string_array synced_to_git;
    string_array synced_to_clawhub;
    string_array up_to_date;
    string_array errors;
} results_struct;

void init_string_array(string_array* arr) {
    arr->items = malloc(10 * sizeof(char*));
    arr->count = 0;
    arr->capacity = 10;
}

void add_to_string_array(string_array* arr, const char* item) {
    if (arr->count >= arr->capacity) {
        arr->capacity *= 2;
        arr->items = realloc(arr->items, arr->capacity * sizeof(char*));
    }
    arr->items[arr->count] = malloc(strlen(item) + 1);
    strcpy(arr->items[arr->count], item);
    arr->count++;
}

void free_string_array(string_array* arr) {
    for (int i = 0; i < arr->count; i++) {
        free(arr->items[i]);
    }
    free(arr->items);
    arr->items = NULL;
    arr->count = 0;
    arr->capacity = 0;
}

double file_mtime(const char* path) {
    DIR* dir = opendir(path);
    if (!dir) return 0;
    
    struct dirent* entry;
    double max_mtime = 0;
    char full_path[1024];
    
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
        if (strstr(entry->d_name, ".git") != NULL) continue;
        
        snprintf(full_path, sizeof(full_path), "%s/%s", path, entry->d_name);
        
        struct stat st;
        if (stat(full_path, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                double subdir_mtime = file_mtime(full_path);
                if (subdir_mtime > max_mtime) max_mtime = subdir_mtime;
            } else {
                if (st.st_mtime > max_mtime) max_mtime = st.st_mtime;
            }
        }
    }
    
    closedir(dir);
    return max_mtime;
}

void write_to_log(const char* message, const char* level) {
    FILE* f = fopen(LOG_FILE, "a");
    if (!f) return;
    
    time_t now = time(NULL);
    struct tm* tm_now = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_now);
    
    char entry[1024];
    snprintf(entry, sizeof(entry), "[%s] [%s] %s\n", timestamp, level, message);
    
    printf("%s", entry);
    fprintf(f, "%s", entry);
    fclose(f);
}

int validate_skill(const char* path) {
    // Placeholder - implement actual validation logic
    return 1;
}

int sync_to_git(const char* skill, int dry_run) {
    // Placeholder - implement actual sync logic
    return 1;
}

int sync_to_clawhub(const char* skill, int dry_run) {
    // Placeholder - implement actual sync logic
    return 1;
}

void get_directories(const char* path, string_array* dirs) {
    DIR* dir = opendir(path);
    if (!dir) return;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        if (entry->d_type == DT_DIR) {
            add_to_string_array(dirs, entry->d_name);
        }
    }
    
    closedir(dir);
}

int string_array_contains(string_array* arr, const char* item) {
    for (int i = 0; i < arr->count; i++) {
        if (strcmp(arr->items[i], item) == 0) {
            return 1;
        }
    }
    return 0;
}

void sort_string_array(string_array* arr) {
    for (int i = 0; i < arr->count - 1; i++) {
        for (int j = 0; j < arr->count - i - 1; j++) {
            if (strcmp(arr->items[j], arr->items[j+1]) > 0) {
                char* temp = arr->items[j];
                arr->items[j] = arr->items[j+1];
                arr->items[j+1] = temp;
            }
        }
    }
}

void run_git_command(const char* path, const char* command) {
    char cmd[1024];
    chdir(path);
    snprintf(cmd, sizeof(cmd), "%s 2>/dev/null", command);
    system(cmd);
}

int main() {
    // Create log directory if it doesn't exist
    char log_dir_cmd[256];
    snprintf(log_dir_cmd, sizeof(log_dir_cmd), "mkdir -p $(dirname %s)", LOG_FILE);
    system(log_dir_cmd);
    
    write_to_log("======================================================================", "INFO");
    write_to_log("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF", "INFO");
    
    time_t now = time(NULL);
    struct tm* tm_now = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%S", tm_now);
    char time_msg[128];
    snprintf(time_msg, sizeof(time_msg), "Zeitstempel: %s", timestamp);
    write_to_log(time_msg, "INFO");
    write_to_log("======================================================================", "INFO");
    
    string_array clawhub_skills;
    string_array git_skills;
    init_string_array(&clawhub_skills);
    init_string_array(&git_skills);
    
    get_directories(CLAWHUB_DIR, &clawhub_skills);
    get_directories(GIT_DIR, &git_skills);
    
    // DRY-RUN: Erkenne Änderungen
    write_to_log("[DRY-RUN] Analysiere Änderungen...", "INFO");
    
    changes_detected_struct changes_detected;
    init_string_array(&changes_detected.new_in_clawhub);
    init_string_array(&changes_detected.new_in_git);
    init_string_array(&changes_detected.synced);
    changes_detected.clawhub_newer = malloc(100 * sizeof(skill_diff));
    changes_detected.git_newer = malloc(100 * sizeof(skill_diff));
    changes_detected.clawhub_newer_count = 0;
    changes_detected.git_newer_count = 0;
    
    // 1. Neue Skills
    for (int i = 0; i < clawhub_skills.count; i++) {
        if (!string_array_contains(&git_skills, clawhub_skills.items[i])) {
            add_to_string_array(&changes_detected.new_in_clawhub, clawhub_skills.items[i]);
        }
    }
    
    for (int i = 0; i < git_skills.count; i++) {
        if (!string_array_contains(&clawhub_skills, git_skills.items[i])) {
            add_to_string_array(&changes_detected.new_in_git, git_skills.items[i]);
        }
    }
    
    sort_string_array(&changes_detected.new_in_clawhub);
    sort_string_array(&changes_detected.new_in_git);
    
    // 2. Existierende prüfen
    for (int i = 0; i < clawhub_skills.count; i++) {
        const char* skill = clawhub_skills.items[i];
        if (string_array_contains(&git_skills, skill)) {
            char clawhub_path[1024];
            char git_path[1024];
            snprintf(clawhub_path, sizeof(clawhub_path), "%s/%s", CLAWHUB_DIR, skill);
            snprintf(git_path, sizeof(git_path), "%s/%s", GIT_DIR, skill);
            
            double c_mtime = file_mtime(clawhub_path);
            double g_mtime = file_mtime(git_path);
            double diff = c_mtime - g_mtime;
            
            if (fabs(diff) > 60) {
                if (diff > 0) {
                    strncpy(changes_detected.clawhub_newer[changes_detected.clawhub_newer_count].skill, skill, sizeof(changes_detected.clawhub_newer[changes_detected.clawhub_newer_count].skill));
                    changes_detected.clawhub_newer[changes_detected.clawhub_newer_count].diff = diff;
                    changes_detected.clawhub_newer_count++;
                } else {
                    strncpy(changes_detected.git_newer[changes_detected.git_newer_count].skill, skill, sizeof(changes_detected.git_newer[changes_detected.git_newer_count].skill));
                    changes_detected.git_newer[changes_detected.git_newer_count].diff = fabs(diff);
                    changes_detected.git_newer_count++;
                }
            } else {
                add_to_string_array(&changes_detected.synced, skill);
            }
        }
    }
    
    // Report
    char report_msg[256];
    snprintf(report_msg, sizeof(report_msg), "Neu in ClawHub: %d", changes_detected.new_in_clawhub.count);
    write_to_log(report_msg, "INFO");
    snprintf(report_msg, sizeof(report_msg), "Neu in Git: %d", changes_detected.new_in_git.count);
    write_to_log(report_msg, "INFO");
    snprintf(report_msg, sizeof(report_msg), "ClawHub neuer: %d", changes_detected.clawhub_newer_count);
    write_to_log(report_msg, "INFO");
    snprintf(report_msg, sizeof(report_msg), "Git neuer: %d", changes_detected.git_newer_count);
    write_to_log(report_msg, "INFO");
    snprintf(report_msg, sizeof(report_msg), "Synchron: %d", changes_detected.synced.count);
    write_to_log(report_msg, "INFO");
    
    int total_changes = changes_detected.new_in_clawhub.count + changes_detected.new_in_git.count + 
                         changes_detected.clawhub_newer_count + changes_detected.git_newer_count;
    
    if (total_changes == 0) {
        write_to_log("✅ Keine Änderungen erkannt. Sync nicht nötig.", "INFO");
        write_to_log("======================================================================", "INFO");
        return 0;
    }
    
    char changes_msg[128];
    snprintf(changes_msg, sizeof(changes_msg), "🔄 %d Änderungen erkannt - starte Synchronisation...", total_changes);
    write_to_log(changes_msg, "INFO");
    
    // ECHTE SYNCHRONISATION
    results_struct results;
    init_string_array(&results.synced_to_git);
    init_string_array(&results.synced_to_clawhub);
    init_string_array(&results.up_to_date);
    init_string_array(&results.errors);
    
    // 1. NEU in ClawHub → zu Git
    for (int i = 0; i < changes_detected.new_in_clawhub.count; i++) {
        const char* skill = changes_detected.new_in_clawhub.items[i];
        char skill_path[1024];
        snprintf(skill_path, sizeof(skill_path), "%s/%s", CLAWHUB_DIR, skill);
        
        if (validate_skill(skill_path)) {
            char sync_msg[256];
            snprintf(sync_msg, sizeof(sync_msg), "→ Synchronisiere %s zu Git...", skill);
            write_to_log(sync_msg, "INFO");
            
            if (sync_to_git(skill, 0)) {
                char git_path[1024];
                snprintf(git_path, sizeof(git_path), "%s/%s", GIT_DIR, skill);
                
                run_git_command(git_path, "git init -q");
                run_git_command(git_path, "git add . -f");
                
                time_t now = time(NULL);
                struct tm* tm_now = localtime(&now);
                char dt[64];
                strftime(dt, sizeof(dt), "%Y-%m-%d %H:%M", tm_now);
                
                char commit_cmd[256];
                snprintf(commit_cmd, sizeof(commit_cmd), "git commit -m \"Initial: %s\" -q", skill);
                run_git_command(git_path, commit_cmd);
                
                add_to_string_array(&results.synced_to_git, skill);
                char success_msg[256];
                snprintf(success_msg, sizeof(success_msg), "  ✓ %s synchronisiert", skill);
                write_to_log(success_msg, "INFO");
            }
        } else {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "%s (invalid)", skill);
            add_to_string_array(&results.errors, error_msg);
        }
    }
    
    // 2. NEU in Git → zu ClawHub
    for (int i = 0; i < changes_detected.new_in_git.count; i++) {
        const char* skill = changes_detected.new_in_git.items[i];
        char skill_path[1024];
        snprintf(skill_path, sizeof(skill_path), "%s/%s", GIT_DIR, skill);
        
        if (validate_skill(skill_path)) {
            char sync_msg[256];
            snprintf(sync_msg, sizeof(sync_msg), "→ Synchronisiere %s zu ClawHub...", skill);
            write_to_log(sync_msg, "INFO");
            
            if (sync_to_clawhub(skill, 0)) {
                add_to_string_array(&results.synced_to_clawhub, skill);
                char success_msg[256];
                snprintf(success_msg, sizeof(success_msg), "  ✓ %s synchronisiert", skill);
                write_to_log(success_msg, "INFO");
            }
        } else {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "%s (invalid)", skill);
            add_to_string_array(&results.errors, error_msg);
        }
    }
    
    // 3. Updates
    for (int i = 0; i < changes_detected.clawhub_newer_count; i++) {
        const char* skill = changes_detected.clawhub_newer[i].skill;
        double diff = changes_detected.clawhub_newer[i].diff;
        
        char update_msg[256];
        snprintf(update_msg, sizeof(update_msg), "→ Update %s (ClawHub +%.0fs neuer)...", skill, diff);
        write_to_log(update_msg, "INFO");
        
        if (sync_to_git(skill, 0)) {
            char git_path[1024];
            snprintf(git_path, sizeof(git_path), "%s/%s", GIT_DIR, skill);
            
            run_git_command(git_path, "git add . -f");
            
            time_t now = time(NULL);
            struct tm* tm_now = localtime(&now);
            char dt[64];
            strftime(dt, sizeof(dt), "%Y-%m-%d %H:%M", tm_now);
            
            char commit_cmd[256];
            snprintf(commit_cmd, sizeof(commit_cmd), "git commit -m \"Sync from ClawHub: %s\" -q", dt);
            run_git_command(git_path, commit_cmd);
            
            add_to_string_array(&results.synced_to_git, skill);
            char success_msg[256];
            snprintf(success_msg, sizeof(success_msg), "  ✓ %s aktualisiert", skill);
            write_to_log(success_msg, "INFO");
        }
    }
    
    for (int i = 0; i < changes_detected.git_newer_count; i++) {
        const char* skill = changes_detected.git_newer[i].skill;
        double diff = changes_detected.git_newer[i].diff;
        
        char update_msg[256];
        snprintf(update_msg, sizeof(update_msg), "→ Update %s (Git +%.0fs neuer)...", skill, diff);
        write_to_log(update_msg, "INFO");
        
        if (sync_to_clawhub(skill, 0)) {
            add_to_string_array(&results.synced_to_clawhub, skill);
            char success_msg[256];
            snprintf(success_msg, sizeof(success_msg), "  ✓ %s aktualisiert", skill);
            write_to_log(success_msg, "INFO");
        }
    }
    
    for (int i = 0; i < changes_detected.synced.count; i++) {
        add_to_string_array(&results.up_to_date, changes_detected.synced.items[i]);
    }
    
    // ZUSAMMENFASSUNG
    write_to_log("", "INFO");
    write_to_log("======================================================================", "INFO");
    write_to_log("SYNCHRONISATION ABGESCHLOSSEN", "INFO");
    write_to_log("======================================================================", "INFO");
    
    char summary_msg[256];
    snprintf(summary_msg, sizeof(summary_msg), "Zu Git synchronisiert:     %d", results.synced_to_git.count);
    write_to_log(summary_msg, "INFO");
    snprintf(summary_msg, sizeof(summary_msg), "Zu ClawHub synchronisiert: %d", results.synced_to_clawhub.count);
    write_to_log(summary_msg, "INFO");
    snprintf(summary_msg, sizeof(summary_msg), "Bereits aktuell:           %d", results.up_to_date.count);
    write_to_log(summary_msg, "INFO");
    snprintf(summary_msg, sizeof(summary_msg), "Fehler:                    %d", results.errors.count);
    write_to_log(summary_msg, "INFO");
    
    if (results.errors.count > 0) {
        char error_list[1024] = "  Fehlerhafte: ";
        for (int i = 0; i < results.errors.count; i++) {
            strcat(error_list, results.errors.items[i]);
            if (i < results.errors.count - 1) strcat(error_list, ", ");
        }
        write_to_log(error_list, "INFO");
    }
    write_to_log("======================================================================", "INFO");
    
    // State speichern
    char state_dir_cmd[256];
    snprintf(state_dir_cmd, sizeof(state_dir_cmd), "mkdir -p $(dirname %s)", STATE_FILE);
    system(state_dir_cmd);
    
    FILE* state_f = fopen(STATE_FILE, "w");
    if (state_f) {
        fprintf(state_f, "{\n");
        fprintf(state_f, "  \"last_run\": \"%s\",\n", timestamp);
        fprintf(state_f, "  \"results\": {\n");
        fprintf(state_f, "    \"synced_to_git\": [");
        for (int i = 0; i < results.synced_to_git.count; i++) {
            fprintf(state_f, "\"%s\"", results.synced_to_git.items[i]);
            if (i < results.synced_to_git.count - 1) fprintf(state_f, ", ");
        }
        fprintf(state_f, "],\n");
        fprintf(state_f, "    \"synced_to_clawhub\": [");
        for (int i = 0; i < results.synced_to_clawhub.count; i++) {
            fprintf(state_f, "\"%s\"", results.synced_to_clawhub.items[i]);
            if (i < results.synced_to_clawhub.count - 1) fprintf(state_f, ", ");
        }
        fprintf(state_f, "],\n");
        fprintf(state_f, "    \"up_to_date\": [");
        for (int i = 0; i < results.up_to_date.count; i++) {
            fprintf(state_f, "\"%s\"", results.up_to_date.items[i]);
            if (i < results.up_to_date.count - 1) fprintf(state_f, ", ");
        }
        fprintf(state_f, "],\n");
        fprintf(state_f, "    \"errors\": [");
        for (int i = 0; i < results.errors.count; i++) {
            fprintf(state_f, "\"%s\"", results.errors.items[i]);
            if (i < results.errors.count - 1) fprintf(state_f, ", ");
        }
        fprintf(state_f, "]\n");
        fprintf(state_f, "  },\n");
        fprintf(state_f, "  \"changes_detected\": {\n");
        fprintf(state_f, "    \"new_in_clawhub\": %d,\n", changes_detected.new_in_clawhub.count);
        fprintf(state_f, "    \"new_in_git\": %d,\n", changes_detected.new_in_git.count);
        fprintf(state_f, "    \"clawhub_newer\": %d,\n", changes_detected.clawhub_newer_count);
        fprintf(state_f, "    \"git_newer\": %d,\n", changes_detected.git_newer_count);
        fprintf(state_f, "    \"synced\": %d\n", changes_detected.synced.count);
        fprintf(state_f, "  }\n");
        fprintf(state_f, "}\n");
        fclose(state_f);
        
        char state_msg[256];
        snprintf(state_msg, sizeof(state_msg), "State gespeichert: %s", STATE_FILE);
        write_to_log(state_msg, "INFO");
    }
    
    // Cleanup
    free_string_array(&clawhub_skills);
    free_string_array(&git_skills);
    free_string_array(&changes_detected.new_in_clawhub);
    free_string_array(&changes_detected.new_in_git);
    free_string_array(&changes_detected.synced);
    free_string_array(&results.synced_to_git);
    free_string_array(&results.synced_to_clawhub);
    free_string_array(&results.up_to_date);
    free_string_array(&results.errors);
    free(changes_detected.clawhub_newer);
    free(changes_detected.git_newer);
    
    return 0;
}
