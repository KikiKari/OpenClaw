// abstraction-provenance: {"artifact_sha256": "5933a7ba99d27e57b2aff75228683a11dd37de8ff0268223ed95763f1a2e84bd", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "c"}
// openclaw-audit.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
// auch in: workspace@local:scripts/openclaw-audit.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/utsname.h>

#define MAX_CMD_LEN 1024
#define MAX_PATH_LEN 1024

void get_date_stamp(char *buffer, size_t size) {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(buffer, size, "%Y-%m-%d", tm_info);
}

void get_iso_timestamp(char *buffer, size_t size) {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(buffer, size, "%Y-%m-%dT%H:%M:%S%z", tm_info);
}

void get_hostname(char *buffer, size_t size) {
    gethostname(buffer, size);
    buffer[size - 1] = '\0';
}

void get_username(char *buffer, size_t size) {
    char *user = getenv("USER");
    if (user) {
        strncpy(buffer, user, size - 1);
    } else {
        buffer[0] = '\0';
    }
    buffer[size - 1] = '\0';
}

void run_command(const char *cmd, FILE *out_file) {
    FILE *fp;
    char line[MAX_CMD_LEN];
    int status;

    fprintf(out_file, "\n----------------------------------------------------------------\n");
    fprintf(out_file, "### %s\n", cmd);
    
    char timestamp[64];
    get_iso_timestamp(timestamp, sizeof(timestamp));
    fprintf(out_file, "### $(date --iso-8601=seconds)\n");
    fprintf(out_file, "----------------------------------------------------------------\n");
    
    fp = popen(cmd, "r");
    if (fp == NULL) {
        fprintf(out_file, "Failed to run command\n");
        return;
    }

    while (fgets(line, sizeof(line), fp) != NULL) {
        fprintf(out_file, "%s", line);
    }

    status = pclose(fp);
    fprintf(out_file, "[exit: %d]\n", WEXITSTATUS(status));
}

int main(int argc, char *argv[]) {
    char script_dir[MAX_PATH_LEN];
    char date_stamp[32];
    char out_path[MAX_PATH_LEN];
    char hostname[256];
    char username[256];
    char timestamp[64];
    FILE *out_file;
    
    // Get script directory (use current working directory)
    if (getcwd(script_dir, sizeof(script_dir)) == NULL) {
        perror("getcwd() error");
        return 1;
    }
    
    // Get date stamp
    get_date_stamp(date_stamp, sizeof(date_stamp));
    
    // Create output file path
    snprintf(out_path, sizeof(out_path), "%s/openclaw-audit-%s.log", script_dir, date_stamp);
    
    // Open output file
    out_file = fopen(out_path, "w");
    if (!out_file) {
        perror("Failed to open output file");
        return 1;
    }
    
    // Write header
    fprintf(out_file, "================================================================\n");
    fprintf(out_file, "OpenClaw audit run\n");
    get_iso_timestamp(timestamp, sizeof(timestamp));
    fprintf(out_file, "Started:  %s\n", timestamp);
    get_hostname(hostname, sizeof(hostname));
    fprintf(out_file, "Host:     %s\n", hostname);
    get_username(username, sizeof(username));
    fprintf(out_file, "User:     %s\n", username);
    
    // Get version
    FILE *version_fp = popen("openclaw --version 2>/dev/null", "r");
    if (version_fp) {
        char version_line[MAX_CMD_LEN];
        if (fgets(version_line, sizeof(version_line), version_fp) != NULL) {
            // Remove newline
            version_line[strcspn(version_line, "\n")] = 0;
            fprintf(out_file, "Version:  %s\n", version_line);
        } else {
            fprintf(out_file, "Version:  unknown\n");
        }
        pclose(version_fp);
    } else {
        fprintf(out_file, "Version:  unknown\n");
    }
    
    fprintf(out_file, "Output:   %s\n", out_path);
    fprintf(out_file, "================================================================\n");
    
    // Run all commands
    run_command("openclaw --no-color tasks audit --severity error", out_file);
    run_command("openclaw --no-color secrets audit", out_file);
    run_command("openclaw --no-color security audit", out_file);
    run_command("openclaw --no-color plugins doctor", out_file);
    run_command("openclaw --no-color plugins deps", out_file);
    run_command("openclaw --no-color plugins registry", out_file);
    run_command("openclaw --no-color skills check", out_file);
    run_command("openclaw --no-color hooks check", out_file);
    run_command("openclaw --no-color gateway status --deep", out_file);
    run_command("openclaw --no-color channels status --probe", out_file);
    run_command("openclaw --no-color memory status --deep", out_file);
    run_command("openclaw --no-color sessions --all-agents", out_file);
    run_command("openclaw --no-color tasks list", out_file);
    run_command("openclaw --no-color cron list", out_file);
    
    // Write footer
    fprintf(out_file, "\n================================================================\n");
    get_iso_timestamp(timestamp, sizeof(timestamp));
    fprintf(out_file, "Audit complete: %s\n", timestamp);
    fprintf(out_file, "================================================================\n");
    
    fclose(out_file);
    
    printf("Audit complete. Output: %s\n", out_path);
    
    return 0;
}
