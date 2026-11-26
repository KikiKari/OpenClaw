// abstraction-provenance: {"artifact_sha256": "9098c75afb45d6678c03a46ec1bc34aeb8e0dd7c43e368112a201aaf10cdcaeb", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "c"}
// serve_compare_transfer.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
// auch in: workspace@local:scripts/serve_compare_transfer.sh
// auch in: workspace@local:vscode/compare/transfer/serve_compare_transfer.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <libgen.h>
#include <errno.h>

#define COMPARE_DIR "/home/openclaw/.openclaw/workspace/vscode/compare"
#define TRANSFER_DIR "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
#define HOST_IP "152.53.145.65"
#define PORT "80"

// Maximum number of files to handle
#define MAX_FILES 1024
#define MAX_PATH_LENGTH 4096

// Function to check if a path is a regular file
int is_regular_file(const char *path) {
    struct stat path_stat;
    if (stat(path, &path_stat) != 0) {
        return 0;
    }
    return S_ISREG(path_stat.st_mode);
}

// Function to get basename of a path
char* get_basename(char *path) {
    char *base = strrchr(path, '/');
    return base ? base + 1 : path;
}

// Comparison function for qsort
int compare_strings(const void *a, const void *b) {
    return strcmp(*(const char **)a, *(const char **)b);
}

int main(int argc, char *argv[]) {
    char self_path[MAX_PATH_LENGTH];
    ssize_t len = readlink("/proc/self/exe", self_path, sizeof(self_path) - 1);
    if (len != -1) {
        self_path[len] = '\0';
    } else {
        fprintf(stderr, "Fehler beim Ermitteln des eigenen Pfads: %s\n", strerror(errno));
        return 1;
    }

    // Array to store file paths
    char *files[MAX_FILES];
    int file_count = 0;

    // Open directory
    DIR *dir = opendir(COMPARE_DIR);
    if (!dir) {
        perror("Fehler beim Öffnen des Verzeichnisses");
        return 1;
    }

    struct dirent *entry;
    char full_path[MAX_PATH_LENGTH];

    // Read directory entries
    while ((entry = readdir(dir)) != NULL && file_count < MAX_FILES) {
        // Skip . and ..
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        // Build full path
        snprintf(full_path, sizeof(full_path), "%s/%s", COMPARE_DIR, entry->d_name);

        // Skip self and non-files
        if (strcmp(full_path, self_path) == 0 || !is_regular_file(full_path)) {
            continue;
        }

        // Store the file path
        files[file_count] = malloc(strlen(full_path) + 1);
        if (files[file_count]) {
            strcpy(files[file_count], full_path);
            file_count++;
        }
    }

    closedir(dir);

    // Sort files alphabetically
    qsort(files, file_count, sizeof(char *), compare_strings);

    if (file_count == 0) {
        printf("Keine Dateien in %s gefunden.\n", COMPARE_DIR);
        return 1;
    }

    printf("\nBereitgestellte Dateien aus %s:\n", COMPARE_DIR);
    for (int i = 0; i < file_count; i++) {
        printf("- %s\n", get_basename(files[i]));
    }

    printf("\nCopy/Paste auf anderem Gateway (Download nach %s):\n", TRANSFER_DIR);
    for (int i = 0; i < file_count; i++) {
        char *file = get_basename(files[i]);
        printf("curl -fL --retry 3 --connect-timeout 10 -o %s/%s http://%s:%s/%s\n", 
               TRANSFER_DIR, file, HOST_IP, PORT, file);
    }

    printf("\nServer auf Port %s aktiv. Beenden mit STRG+C.\n\n", PORT);

    // Change to compare directory
    if (chdir(COMPARE_DIR) != 0) {
        perror("Fehler beim Wechseln in das Verzeichnis");
        return 1;
    }

    // Execute Python HTTP server
    execl("/usr/bin/python3", "python3", "-m", "http.server", PORT, "--bind", "0.0.0.0", NULL);
    
    // If exec fails
    perror("Fehler beim Starten des HTTP-Servers");
    return 1;
}
