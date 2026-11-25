// abstraction-provenance: {"artifact_sha256": "08b66b4513a18ddfcb18651659897ec8171ba24af2efdb43f60937b83203168f", "source_sha256": "f8c56b5aecfa8cd091cc5fe50697c5613148d19f0d4e0eb311bf6d129c600018", "target_language": "c"}
// test_sync_real.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
// auch in: OpenClaw@gateway2:scripts/test_sync_real.py
// auch in: workspace@local:scripts/test_sync_real.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <libgen.h>

// Mock implementation of sync_to_git function
// In a real scenario, this would interface with the actual sync functionality
int sync_to_git(const char* skill, int dry_run) {
    // This is a placeholder implementation
    // You would need to implement the actual synchronization logic here
    printf("Syncing skill '%s' to git (dry_run=%s)\n", skill, dry_run ? "true" : "false");
    
    if (!dry_run) {
        // Create directory structure for testing
        char path[512];
        snprintf(path, sizeof(path), "/tmp/git/skills/%s", skill);
        
        // Create directories
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "mkdir -p %s", path);
        system(cmd);
        
        // Create some test files
        snprintf(cmd, sizeof(cmd), "touch %s/README.md %s/main.py %s/config.json", path, path, path);
        system(cmd);
    }
    
    return 1; // Return success
}

void print_directory_tree(const char* path, int level) {
    DIR* dir = opendir(path);
    if (dir == NULL) {
        return;
    }
    
    struct dirent* entry;
    
    // Print current directory name
    char* base_name = strrchr(path, '/');
    if (base_name != NULL) {
        for (int i = 0; i < level * 2; i++) printf(" ");
        printf("%s/\n", base_name + 1);
    }
    
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        if (entry->d_type == DT_REG) { // Regular file
            for (int i = 0; i < (level + 1) * 2; i++) printf(" ");
            printf("%s\n", entry->d_name);
        } else if (entry->d_type == DT_DIR) { // Directory
            char new_path[512];
            snprintf(new_path, sizeof(new_path), "%s/%s", path, entry->d_name);
            print_directory_tree(new_path, level + 1);
        }
    }
    
    closedir(dir);
}

int main() {
    printf("=== TEST: db-maintainer sync (REAL) ===\n");
    
    const char* skill = "db-maintainer";
    int result = sync_to_git(skill, 0); // dry_run = false
    
    printf("Result: %s\n", result ? "SUCCESS" : "FAILED");
    
    // Check result
    const char* target = "/tmp/git/skills/db-maintainer";
    struct stat st = {0};
    
    if (stat(target, &st) == 0) {
        printf("\n✅ Git-Repo erstellt: %s\n", target);
        print_directory_tree(target, 0);
    }
    
    return 0;
}
