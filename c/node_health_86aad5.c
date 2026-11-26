// abstraction-provenance: {"artifact_sha256": "37bed3cf979c2a67abd5f06025825bb3e9ade2dc15861a4d79a8db34ac278d64", "source_sha256": "86aad5ae0d9b77ebdb9a2aaecbf0c4875ad3a241571b573934c882ecd55df14e", "target_language": "c"}
// node_health.py — portiert nach c
// Quelle: python, workspace@local:git/skills/node-health-monitor/scripts/node_health.py
// auch in: workspace@local:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/wait.h>
#include <dirent.h>
#include <libgen.h>

#define MAX_NODES 10
#define MAX_LINE_LENGTH 1024
#define WORKSPACE "/home/openclaw/.openclaw/workspace"
#define HEALTH_DB WORKSPACE "/db/health.db"
#define LOG_FILE WORKSPACE "/logs/node-health.log"

typedef struct {
    char id[32];
    char name[64];
    char host[64];
    char user[32];
    char ssh_key[256];
    int critical;
    int optional;
    int ssh_enabled;
    int disk_warning;
} NodeConfig;

NodeConfig NODES[MAX_NODES] = {
    {"node1", "Gateway", "localhost", "openclaw", "", 1, 0, 1, 85},
    {"node2", "Node2", "100.82.198.122", "root", "/root/.ssh/id_ed25519_openclaw_admin", 0, 0, 1, 85},
    {"node3", "Node3", "100.73.154.125", "root", "", 0, 0, 1, 85},
    {"node4", "Redmi", "100.94.134.39", "root", "", 0, 1, 0, 85},
    {"node5", "Lenovo", "100.103.140.35", "root", "", 0, 1, 0, 85}
};

int NODE_COUNT = 5;

void log_message(const char* message, const char* level) {
    time_t now;
    struct tm *tm_info;
    char timestamp[64];
    
    time(&now);
    tm_info = localtime(&now);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    
    char entry[1024];
    snprintf(entry, sizeof(entry), "[%s] [%s] %s\n", timestamp, level, message);
    printf("%s", entry);
    
    FILE* log_file = fopen(LOG_FILE, "a");
    if (log_file) {
        fprintf(log_file, "%s", entry);
        fclose(log_file);
    }
}

void ensure_log_dir() {
    char dir_path[256];
    strcpy(dir_path, LOG_FILE);
    dirname(dir_path);
    
    struct stat st = {0};
    if (stat(dir_path, &st) == -1) {
        mkdir(dir_path, 0700);
    }
}

int check_ping(const char* host, int timeout) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "ping -c 1 -W %d %s > /dev/null 2>&1", timeout, host);
    return system(cmd) == 0;
}

int check_ssh(NodeConfig* node_config) {
    if (!node_config->ssh_enabled) {
        return 0;
    }
    
    char cmd[512];
    if (strlen(node_config->ssh_key) > 0) {
        snprintf(cmd, sizeof(cmd), 
                 "ssh -o ConnectTimeout=10 -o BatchMode=yes -i %s -o IdentitiesOnly=yes %s@%s 'echo OK' > /dev/null 2>&1",
                 node_config->ssh_key, node_config->user, node_config->host);
    } else {
        snprintf(cmd, sizeof(cmd), 
                 "ssh -o ConnectTimeout=10 -o BatchMode=yes %s@%s 'echo OK' > /dev/null 2>&1",
                 node_config->user, node_config->host);
    }
    
    return system(cmd) == 0;
}

typedef struct {
    char timestamp[64];
    int available;
    double cpu;
    double ram;
    int disk;
    double load;
    char gateway_status[32];
} NodeMetrics;

NodeMetrics get_node_metrics(NodeConfig* node_config) {
    NodeMetrics metrics = {0};
    metrics.available = 0;
    
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    strftime(metrics.timestamp, sizeof(metrics.timestamp), "%Y-%m-%dT%H:%M:%S", tm_info);
    
    if (!node_config->ssh_enabled) {
        return metrics;
    }
    
    char cmd[1024];
    char output[4096] = {0};
    
    if (strlen(node_config->ssh_key) > 0) {
        snprintf(cmd, sizeof(cmd),
                 "ssh -o ConnectTimeout=10 -o BatchMode=yes -i %s -o IdentitiesOnly=yes %s@%s '"
                 "# CPU\n"
                 "echo \"CPU:$(top -bn1 | grep \"Cpu(s)\" | awk \"{print \\$2}\" | cut -d\"%%\" -f1)\"\n"
                 "\n"
                 "# RAM\n"
                 "echo \"RAM:$(free | grep Mem | awk \"{print (\\$3/\\$2) * 100.0}\")\"\n"
                 "\n"
                 "# Disk\n"
                 "echo \"DISK:$(df -h / | tail -1 | awk \"{print \\$5}\" | tr -d \"%%\")\"\n"
                 "\n"
                 "# Load\n"
                 "echo \"LOAD:$(uptime | awk -F\"load average:\" \"{print \\$2}\" | awk \"{print \\$1}\" | tr -d \",\")\"\n"
                 "\n"
                 "# Gateway Status\n"
                 "if command -v openclaw >/dev/null 2>&1; then\n"
                 "    printf \"GATEWAY:%%s\\n\" \"$(systemctl is-active openclaw-gateway 2>/dev/null || true)\"\n"
                 "fi'",
                 node_config->ssh_key, node_config->user, node_config->host);
    } else {
        snprintf(cmd, sizeof(cmd),
                 "ssh -o ConnectTimeout=10 -o BatchMode=yes %s@%s '"
                 "# CPU\n"
                 "echo \"CPU:$(top -bn1 | grep \"Cpu(s)\" | awk \"{print \\$2}\" | cut -d\"%%\" -f1)\"\n"
                 "\n"
                 "# RAM\n"
                 "echo \"RAM:$(free | grep Mem | awk \"{print (\\$3/\\$2) * 100.0}\")\"\n"
                 "\n"
                 "# Disk\n"
                 "echo \"DISK:$(df -h / | tail -1 | awk \"{print \\$5}\" | tr -d \"%%\")\"\n"
                 "\n"
                 "# Load\n"
                 "echo \"LOAD:$(uptime | awk -F\"load average:\" \"{print \\$2}\" | awk \"{print \\$1}\" | tr -d \",\")\"\n"
                 "\n"
                 "# Gateway Status\n"
                 "if command -v openclaw >/dev/null 2>&1; then\n"
                 "    printf \"GATEWAY:%%s\\n\" \"$(systemctl is-active openclaw-gateway 2>/dev/null || true)\"\n"
                 "fi'",
                 node_config->user, node_config->host);
    }
    
    FILE* pipe = popen(cmd, "r");
    if (!pipe) {
        log_message("Failed to run SSH command", "ERROR");
        return metrics;
    }
    
    char buffer[128];
    size_t output_len = 0;
    while (fgets(buffer, sizeof(buffer), pipe) != NULL && output_len < sizeof(output) - 1) {
        strcat(output, buffer);
        output_len += strlen(buffer);
    }
    
    int status = pclose(pipe);
    if (status != 0) {
        log_message("SSH command failed", "ERROR");
        return metrics;
    }
    
    metrics.available = 1;
    
    char* line = strtok(output, "\n");
    while (line != NULL) {
        char* colon = strchr(line, ':');
        if (colon != NULL) {
            *colon = '\0';
            char* key = line;
            char* value = colon + 1;
            
            if (strcmp(key, "CPU") == 0) {
                metrics.cpu = atof(value);
            } else if (strcmp(key, "RAM") == 0) {
                metrics.ram = atof(value);
            } else if (strcmp(key, "DISK") == 0) {
                metrics.disk = atoi(value);
            } else if (strcmp(key, "LOAD") == 0) {
                metrics.load = atof(value);
            } else if (strcmp(key, "GATEWAY") == 0) {
                strncpy(metrics.gateway_status, value, sizeof(metrics.gateway_status) - 1);
            }
        }
        line = strtok(NULL, "\n");
    }
    
    return metrics;
}

typedef struct {
    char level[16];
    char message[256];
} Alert;

int check_alerts(NodeConfig* node_config, NodeMetrics* metrics, Alert* alerts, int max_alerts) {
    int alert_count = 0;
    
    if (!metrics->available) {
        if (!node_config->optional) {
            strncpy(alerts[alert_count].level, "CRITICAL", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message),
                     "Node %s nicht erreichbar!", node_config->name);
            alert_count++;
        }
    } else {
        if (metrics->cpu > 90) {
            strncpy(alerts[alert_count].level, "WARNING", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message),
                     "Node %s: CPU bei %.1f%%", node_config->name, metrics->cpu);
            alert_count++;
        }
        
        if (metrics->ram > 90) {
            strncpy(alerts[alert_count].level, "WARNING", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message),
                     "Node %s: RAM bei %.1f%%", node_config->name, metrics->ram);
            alert_count++;
        }
        
        int disk_threshold = node_config->disk_warning;
        if (metrics->disk > disk_threshold) {
            const char* level = (metrics->disk > 95) ? "CRITICAL" : "WARNING";
            strncpy(alerts[alert_count].level, level, sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message),
                     "Node %s: Disk bei %d%%", node_config->name, metrics->disk);
            alert_count++;
        }
        
        if (node_config->critical && strcmp(metrics->gateway_status, "inactive") == 0) {
            strncpy(alerts[alert_count].level, "CRITICAL", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message),
                     "Node %s: OpenClaw Gateway nicht aktiv!", node_config->name);
            alert_count++;
        }
    }
    
    return alert_count;
}

void send_alert(Alert* alert) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
             "python3 %s/skills/channel-status-agent/scripts/channel_status.py --type alert --message \"%s: %s\" > /dev/null 2>&1",
             WORKSPACE, alert->level, alert->message);
    
    int result = system(cmd);
    if (result != 0) {
        log_message("Failed to send alert", "ERROR");
    } else {
        char log_msg[256];
        snprintf(log_msg, sizeof(log_msg), "Alert sent: %s", alert->message);
        log_message(log_msg, "INFO");
    }
}

int main(int argc, char* argv[]) {
    char target_node[32] = "all";
    char check_type[16] = "all";
    int send_alerts = 0;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--node") == 0 && i + 1 < argc) {
            strncpy(target_node, argv[++i], sizeof(target_node) - 1);
        } else if (strcmp(argv[i], "--check") == 0 && i + 1 < argc) {
            strncpy(check_type, argv[++i], sizeof(check_type) - 1);
        } else if (strcmp(argv[i], "--alert") == 0) {
            send_alerts = 1;
        }
    }
    
    ensure_log_dir();
    
    Alert all_alerts[100];
    int total_alerts = 0;
    
    for (int i = 0; i < NODE_COUNT; i++) {
        NodeConfig* node_config = &NODES[i];
        
        if (strcmp(target_node, "all") != 0 && strcmp(target_node, node_config->id) != 0) {
            continue;
        }
        
        char log_msg[128];
        snprintf(log_msg, sizeof(log_msg), "Checking %s (%s)", node_config->name, node_config->id);
        log_message(log_msg, "INFO");
        
        if (strcmp(check_type, "ping") == 0 || strcmp(check_type, "all") == 0) {
            if (strcmp(node_config->host, "localhost") != 0) {
                int ping_ok = check_ping(node_config->host, 5);
                log_message(ping_ok ? "  Ping: OK" : "  Ping: FAILED", "INFO");
            }
        }
        
        if (strcmp(check_type, "ssh") == 0 || strcmp(check_type, "all") == 0) {
            if (!node_config->ssh_enabled) {
                log_message("  SSH: SKIPPED (nicht konfiguriert)", "INFO");
            } else {
                int ssh_ok = check_ssh(node_config);
                log_message(ssh_ok ? "  SSH: OK" : "  SSH: FAILED", "INFO");
            }
        }
        
        if (strcmp(check_type, "metrics") == 0 || strcmp(check_type, "all") == 0) {
            NodeMetrics metrics = get_node_metrics(node_config);
            
            if (metrics.available) {
                char cpu_msg[64];
                char ram_msg[64];
                char disk_msg[64];
                char load_msg[64];
                
                snprintf(cpu_msg, sizeof(cpu_msg), "  CPU: %.1f%%", metrics.cpu);
                snprintf(ram_msg, sizeof(ram_msg), "  RAM: %.1f%%", metrics.ram);
                snprintf(disk_msg, sizeof(disk_msg), "  Disk: %d%%", metrics.disk);
                snprintf(load_msg, sizeof(load_msg), "  Load: %.2f", metrics.load);
                
                log_message(cpu_msg, "INFO");
                log_message(ram_msg, "INFO");
                log_message(disk_msg, "INFO");
                log_message(load_msg, "INFO");
            } else {
                log_message("  Metrics: UNAVAILABLE", "INFO");
            }
            
            Alert node_alerts[10];
            int alert_count = check_alerts(node_config, &metrics, node_alerts, 10);
            
            for (int j = 0; j < alert_count; j++) {
                all_alerts[total_alerts++] = node_alerts[j];
            }
        }
    }
    
    if (send_alerts && total_alerts > 0) {
        char alert_msg[64];
        snprintf(alert_msg, sizeof(alert_msg), "Sending %d alerts...", total_alerts);
        log_message(alert_msg, "INFO");
        
        for (int i = 0; i < total_alerts; i++) {
            send_alert(&all_alerts[i]);
        }
    } else if (total_alerts > 0) {
        char alert_msg[128];
        snprintf(alert_msg, sizeof(alert_msg), "%d alerts found (use --alert to send)", total_alerts);
        log_message(alert_msg, "INFO");
    } else {
        log_message("Prüfung abgeschlossen; Details und nicht verfügbare Prüfungen siehe oben.", "INFO");
    }
    
    return 0;
}
