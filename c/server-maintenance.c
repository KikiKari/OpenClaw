// abstraction-provenance: {"artifact_sha256": "dcca68cc1a467d519745b23bdb0bc5dec71cfa9645627cfd1182edd5c163e642", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "c"}
// server-maintenance.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
// auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
// auch in: workspace@local:scripts/server-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/statvfs.h>
#include <sys/utsname.h>

#define LOG_FILE "/var/log/server-maintenance.log"
#define RAM_TOTAL_MB 8192

void log_message(const char* message) {
    FILE* log = fopen(LOG_FILE, "a");
    if (log) {
        time_t now;
        time(&now);
        struct tm* local = localtime(&now);
        char timestamp[64];
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", local);
        fprintf(log, "[%s] %s\n", timestamp, message);
        fclose(log);
    }
    time_t now;
    time(&now);
    struct tm* local = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", local);
    printf("[%s] %s\n", timestamp, message);
}

int execute_command_and_log(const char* command) {
    FILE* fp;
    char buffer[1024];
    int result = 0;

    fp = popen(command, "r");
    if (fp == NULL) {
        log_message("❌ Failed to run command");
        return -1;
    }

    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        buffer[strcspn(buffer, "\n")] = 0;
        log_message(buffer);
    }

    result = pclose(fp);
    return result;
}

void check_updates() {
    log_message("Checking for updates...");
    system("apt update -qq >/dev/null 2>&1");
    
    FILE* fp = popen("apt list --upgradable 2>/dev/null | wc -l", "r");
    if (fp) {
        char output[16];
        if (fgets(output, sizeof(output), fp)) {
            int updates = atoi(output);
            if (updates > 1) {
                char msg[128];
                sprintf(msg, "⚠️ %d packages can be upgraded", updates);
                log_message(msg);
            }
        }
        pclose(fp);
    }
}

void check_ram_usage() {
    log_message("Checking RAM usage...");
    
    FILE* fp = popen("free -m | awk '/^Mem:/{print $3}'", "r");
    if (fp) {
        char output[16];
        if (fgets(output, sizeof(output), fp)) {
            int ram_used = atoi(output);
            int ram_percent = (ram_used * 100) / RAM_TOTAL_MB;
            
            char msg[128];
            sprintf(msg, "RAM: %dMB / %dMB (%d%%)", ram_used, RAM_TOTAL_MB, ram_percent);
            log_message(msg);
            
            if (ram_percent > 90) {
                log_message("🔴 WARNING: RAM usage > 90%!");
            } else if (ram_percent > 80) {
                log_message("🟡 WARNING: RAM usage > 80%");
            }
        }
        pclose(fp);
    }
}

void check_disk_space() {
    log_message("Checking disk space...");
    
    struct statvfs buf;
    if (statvfs("/", &buf) == 0) {
        unsigned long total = buf.f_blocks * buf.f_frsize;
        unsigned long used = (buf.f_blocks - buf.f_bfree) * buf.f_frsize;
        int percent = ((buf.f_blocks - buf.f_bfree) * 100) / buf.f_blocks;
        
        char msg[128];
        sprintf(msg, "Disk: %.1fG / %.1fG (%d%% used)", 
                used / (1024.0*1024*1024), 
                total / (1024.0*1024*1024), 
                percent);
        log_message(msg);
        
        if (percent > 90) {
            log_message("🔴 WARNING: Disk > 90%!");
        } else if (percent > 80) {
            log_message("🟡 WARNING: Disk > 80%");
        }
    }
}

void check_ntp_sync() {
    log_message("Checking NTP sync...");
    
    FILE* fp = popen("timedatectl status | grep 'NTP synchronized'", "r");
    if (fp) {
        char output[128];
        if (fgets(output, sizeof(output), fp)) {
            if (strstr(output, "yes")) {
                log_message("✅ NTP synchronized");
            } else {
                log_message("⚠️ NTP not synchronized");
            }
        } else {
            log_message("⚠️ NTP not synchronized");
        }
        pclose(fp);
    }
}

void check_openclaw_gateway() {
    log_message("Checking OpenClaw Gateway...");
    
    if (system("systemctl is-active --quiet openclaw-gateway") == 0) {
        log_message("✅ OpenClaw Gateway running");
    } else {
        log_message("🔴 OpenClaw Gateway NOT running!");
        system("systemctl restart openclaw-gateway");
    }
}

void check_load_average() {
    FILE* fp = popen("uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//'", "r");
    if (fp) {
        char load_str[16];
        if (fgets(load_str, sizeof(load_str), fp)) {
            load_str[strcspn(load_str, "\n")] = 0;
            char msg[64];
            sprintf(msg, "Load Average: %s", load_str);
            log_message(msg);
        }
        pclose(fp);
    }
}

int main() {
    log_message("=== Server Maintenance Check ===");
    
    check_updates();
    check_ram_usage();
    check_disk_space();
    check_ntp_sync();
    check_openclaw_gateway();
    check_load_average();
    
    log_message("=== Maintenance Complete ===");
    log_message("");
    
    return 0;
}
