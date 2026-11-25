// abstraction-provenance: {"artifact_sha256": "36089f4bc5e05d1c64f0a58e9170c93401ab9d391be4b6bf91ab912089a3a11b", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "c"}
// translation-worker-node5.ps1 — portiert nach c
// Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>
#include <openssl/sha.h>
#include <dirent.h>

#ifndef _WIN32
#include <sys/types.h>
#endif

#define WORKER_PATH ".openclaw/workers/translation_worker.py"
#define EXPECTED_HASH "9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b"

// Function to get user home directory
char* get_home_directory() {
    char* home = getenv("HOME");
    if (!home) {
        home = getenv("USERPROFILE"); // For Windows compatibility
    }
    return home;
}

// Function to join paths (simple implementation)
void join_path(char* result, const char* path1, const char* path2) {
    snprintf(result, PATH_MAX, "%s/%s", path1, path2);
}

// Function to check if file exists and is a regular file
int file_exists(const char* path) {
    struct stat statbuf;
    if (stat(path, &statbuf) != 0) {
        return 0;
    }
    return S_ISREG(statbuf.st_mode);
}

// Function to check if file is a symbolic link
int is_symlink(const char* path) {
#ifdef _WIN32
    // Windows implementation would require more complex checks
    return 0;
#else
    struct stat statbuf;
    if (lstat(path, &statbuf) == 0) {
        return S_ISLNK(statbuf.st_mode);
    }
    return 0;
#endif
}

// Function to calculate SHA256 hash of a file
int calculate_file_hash(const char* filepath, char* output_hash) {
    FILE* file = fopen(filepath, "rb");
    if (!file) {
        return -1;
    }

    unsigned char buffer[8192];
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256_CTX sha256;
    SHA256_Init(&sha256);

    size_t bytes;
    while ((bytes = fread(buffer, 1, sizeof(buffer), file)) != 0) {
        SHA256_Update(&sha256, buffer, bytes);
    }

    SHA256_Final(hash, &sha256);
    fclose(file);

    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        sprintf(output_hash + (i * 2), "%02x", hash[i]);
    }
    output_hash[SHA256_DIGEST_LENGTH * 2] = '\0';

    return 0;
}

// Function to find python executable
int find_python_executable(char* python_path) {
    // First try to find python in PATH
    char* path_env = getenv("PATH");
    if (!path_env) {
        return -1;
    }

    char* path_copy = strdup(path_env);
    char* dir = strtok(path_copy, ":");
    
    while (dir != NULL) {
        char full_path[PATH_MAX];
        snprintf(full_path, PATH_MAX, "%s/python", dir);
        
        if (access(full_path, X_OK) == 0) {
            strcpy(python_path, full_path);
            free(path_copy);
            return 0;
        }
        
        // Also try python.exe for Windows compatibility
        snprintf(full_path, PATH_MAX, "%s/python.exe", dir);
        if (access(full_path, X_OK) == 0) {
            strcpy(python_path, full_path);
            free(path_copy);
            return 0;
        }
        
        dir = strtok(NULL, ":");
    }
    
    free(path_copy);
    return -1;
}

// Function to convert string to lowercase
void to_lowercase(char* str) {
    for (int i = 0; str[i]; i++) {
        if (str[i] >= 'A' && str[i] <= 'Z') {
            str[i] += 'a' - 'A';
        }
    }
}

int main(int argc, char* argv[]) {
    // Set error handling to stop on error (similar to PowerShell's Stop)
    
    // Check arguments
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <prepare|run>\n", argv[0]);
        return 1;
    }
    
    char* action = argv[1];
    
    // Validate action parameter
    if (strcmp(action, "prepare") != 0 && strcmp(action, "run") != 0) {
        fprintf(stderr, "Invalid action. Must be 'prepare' or 'run'.\n");
        return 1;
    }
    
    // Windows does not use chmod. The Python worker and Python 3 must already be
    // installed locally; no credentials are copied or placed on a command line.
    
    // Build worker path
    char worker_full_path[PATH_MAX];
    char* home_dir = get_home_directory();
    
    if (!home_dir) {
        fprintf(stderr, "Could not determine home directory\n");
        return 1;
    }
    
    join_path(worker_full_path, home_dir, WORKER_PATH);
    
    // Check if worker file exists
    if (!file_exists(worker_full_path)) {
        fprintf(stderr, "Worker missing: %s\n", worker_full_path);
        return 1;
    }
    
    // Check if worker is a symbolic link
    if (is_symlink(worker_full_path)) {
        fprintf(stderr, "Worker link rejected\n");
        return 1;
    }
    
    // Calculate file hash
    char calculated_hash[SHA256_DIGEST_LENGTH * 2 + 1];
    if (calculate_file_hash(worker_full_path, calculated_hash) != 0) {
        fprintf(stderr, "Failed to calculate worker hash\n");
        return 1;
    }
    
    to_lowercase(calculated_hash);
    
    // Compare with expected hash
    if (strcmp(calculated_hash, EXPECTED_HASH) != 0) {
        fprintf(stderr, "Worker checksum mismatch\n");
        return 1;
    }
    
    // Find python executable
    char python_executable[PATH_MAX];
    if (find_python_executable(python_executable) != 0) {
        fprintf(stderr, "Python executable not found\n");
        return 1;
    }
    
    if (strcmp(action, "prepare") == 0) {
        printf("Worker verified: %s\n", worker_full_path);
        return 0;
    }
    
    // Execute the worker
    char* exec_args[] = {python_executable, worker_full_path, NULL};
    
    execv(python_executable, exec_args);
    
    // If we reach here, execv failed
    perror("Failed to execute python worker");
    return 1;
}
