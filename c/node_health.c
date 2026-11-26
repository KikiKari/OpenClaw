// abstraction-provenance: {"artifact_sha256": "1a48e8458d96fb200187818705f5ef9561d1d881792d9fe4dfb29cd9d70be884", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "c"}
// node_health.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>
#include <sys/stat.h>
#include <errno.h>
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
    char ssh_key[128];
    int critical;
    int optional;
    int disk_warning;
} Node;

Node nodes[MAX_NODES] = {
    {"node1", "Gateway", "localhost", "openclaw", "", 1, 0, 85},
    {"node2", "Worker", "100.92.155.34", "root", "~/.ssh/id_rsa", 0, 0, 85},
    {"node3", "Relay", "185.242.xxx.xxx", "root", "", 0, 0, 85},
    {"node5", "Redmi", "192.168.1.x", "openclaw", "", 0, 1, 85}
};

int node_count = 4;

void log_message(const char* message, const char* level) {
    time_t now;
    time(&now);
    struct tm *local = localtime(&now);
    
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", local);
    
    char entry[1024];
    snprintf(entry, sizeof(entry), "[%s] [%s] %s\n", timestamp, level, message);
    
    printf("%s", entry);
    
    // Create directory if needed
    char log_dir[256];
    strcpy(log_dir, LOG_FILE);
    dirname(log_dir);
    mkdir(log_dir, 0755);
    
    FILE* f = fopen(LOG_FILE, "a");
    if (f) {
        fprintf(f, "%s", entry);
        fclose(f);
    }
}

int check_ping(const char* host, int timeout) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "ping -c 1 -W %d %s >/dev/null 2>&1", timeout, host);
    return system(cmd) == 0;
}

int check_ssh(const Node* node_config) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "ssh -o ConnectTimeout=10 -o BatchMode=yes %s@%s 'echo OK' 2>/dev/null | grep -q 'OK'", 
             node_config->user, node_config->host);
    return system(cmd) == 0;
}

typedef struct {
    char timestamp[64];
    int available;
    float cpu;
    float ram;
    int disk;
    float load;
    char gateway_status[32];
} Metrics;

Metrics get_node_metrics(const Node* node_config) {
    Metrics metrics = {0};
    time_t now = time(NULL);
    struct tm *local = localtime(&now);
    strftime(metrics.timestamp, sizeof(metrics.timestamp), "%Y-%m-%dT%H:%M:%S", local);
    metrics.available = 0;
    metrics.cpu = -1;
    metrics.ram = -1;
    metrics.disk = -1;
    metrics.load = -1;
    strcpy(metrics.gateway_status, "");
    
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), 
        "ssh -o ConnectTimeout=10 %s@%s '"
        "# CPU\\n"
        "echo \"CPU:$(top -bn1 | grep \\\"Cpu(s)\\\" | awk \\\"{print \\\\\\$2}\\\" | cut -d\\\"%%\\\" -f1)\"\\n"
        "\\n"
        "# RAM\\n"
        "echo \"RAM:$(free | grep Mem | awk \\\"{print (\\\\\$3/\\\\\$2) * 100.0}\\\")\"\\n"
        "\\n"
        "# Disk\\n"
        "echo \"DISK:$(df -h / | tail -1 | awk \\\"{print \\\\\\$5}\\\" | tr -d \\\"%%\\\")\"\\n"
        "\\n"
        "# Load\\n"
        "echo \"LOAD:$(uptime | awk -F\\\"load average:\\\" \\\"{print \\\\\\$2}\\\" | awk \\\"{print \\\\\\$1}\\\" | tr -d \\\",\\\")\"\\n"
        "\\n"
        "# Gateway Status\\n"
        "if command -v openclaw >/dev/null 2>&1; then\\n"
        "    systemctl is-active openclaw-gateway 2>/dev/null || echo \\\"GATEWAY:inactive\\\"\\n"
        "fi\\n"
        "' 2>/dev/null", 
        node_config->user, node_config->host);
    
    FILE* pipe = popen(cmd, "r");
    if (!pipe) {
        log_message("Failed to run SSH command", "ERROR");
        return metrics;
    }
    
    char line[512];
    while (fgets(line, sizeof(line), pipe)) {
        line[strcspn(line, "\n")] = 0; // Remove newline
        
        char* colon = strchr(line, ':');
        if (colon) {
            *colon = '\0';
            char* key = line;
            char* value = colon + 1;
            
            if (strcmp(key, "CPU") == 0 && strlen(value) > 0) {
                metrics.cpu = atof(value);
                metrics.available = 1;
            } else if (strcmp(key, "RAM") == 0 && strlen(value) > 0) {
                metrics.ram = atof(value);
                metrics.available = 1;
            } else if (strcmp(key, "DISK") == 0 && strlen(value) > 0) {
                metrics.disk = atoi(value);
                metrics.available = 1;
            } else if (strcmp(key, "LOAD") == 0 && strlen(value) > 0) {
                metrics.load = atof(value);
                metrics.available = 1;
            } else if (strcmp(key, "GATEWAY") == 0) {
                strncpy(metrics.gateway_status, value, sizeof(metrics.gateway_status) - 1);
                metrics.available = 1;
            }
        }
    }
    
    pclose(pipe);
    return metrics;
}

typedef struct {
    char level[16];
    char message[256];
} Alert;

int check_alerts(const char* node_id, const Node* node_config, const Metrics* metrics, Alert* alerts, int max_alerts) {
    int alert_count = 0;
    
    // Verfügbarkeit
    if (!metrics->available) {
        if (!node_config->optional) {
            strncpy(alerts[alert_count].level, "CRITICAL", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message), 
                     "Node %s nicht erreichbar!", node_config->name);
            alert_count++;
        }
    } else {
        // CPU
        if (metrics->cpu >= 0 && metrics->cpu > 90) {
            strncpy(alerts[alert_count].level, "WARNING", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message), 
                     "Node %s: CPU bei %.1f%%", node_config->name, metrics->cpu);
            alert_count++;
        }
        
        // RAM
        if (metrics->ram >= 0 && metrics->ram > 90) {
            strncpy(alerts[alert_count].level, "WARNING", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message), 
                     "Node %s: RAM bei %.1f%%", node_config->name, metrics->ram);
            alert_count++;
        }
        
        // Disk
        int disk_threshold = node_config->disk_warning;
        if (metrics->disk >= 0 && metrics->disk > disk_threshold) {
            if (metrics->disk > 95) {
                strncpy(alerts[alert_count].level, "CRITICAL", sizeof(alerts[alert_count].level) - 1);
            } else {
                strncpy(alerts[alert_count].level, "WARNING", sizeof(alerts[alert_count].level) - 1);
            }
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message), 
                     "Node %s: Disk bei %d%%", node_config->name, metrics->disk);
            alert_count++;
        }
        
        // Gateway
        if (node_config->critical && strcmp(metrics->gateway_status, "inactive") == 0) {
            strncpy(alerts[alert_count].level, "CRITICAL", sizeof(alerts[alert_count].level) - 1);
            snprintf(alerts[alert_count].message, sizeof(alerts[alert_count].message), 
                     "Node %s: OpenClaw Gateway nicht aktiv!", node_config->name);
            alert_count++;
        }
    }
    
    return alert_count;
}

void send_alert(const Alert* alert) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), 
             "python3 %s/skills/channel-status-agent/scripts/channel_status.py --type alert --message '%s: %s' >/dev/null 2>&1", 
             WORKSPACE, alert->level, alert->message);
    
    if (system(cmd) != 0) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "Failed to send alert: %s", alert->message);
        log_message(error_msg, "ERROR");
    } else {
        char success_msg[512];
        snprintf(success_msg, sizeof(success_msg), "Alert sent: %s", alert->message);
        log_message(success_msg, "INFO");
    }
}

int find_node_index(const char* node_id) {
    for (int i = 0; i < node_count; i++) {
        if (strcmp(nodes[i].id, node_id) == 0) {
            return i;
        }
    }
    return -1;
}

int main(int argc, char* argv[]) {
    char node_arg[32] = "all";
    char check_arg[16] = "all";
    int send_alerts = 0;
    
    // Simple argument parsing
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--node") == 0 && i + 1 < argc) {
            strncpy(node_arg, argv[++i], sizeof(node_arg) - 1);
        } else if (strcmp(argv[i], "--check") == 0 && i + 1 < argc) {
            strncpy(check_arg, argv[++i], sizeof(check_arg) - 1);
        } else if (strcmp(argv[i], "--alert") == 0) {
            send_alerts = 1;
        }
    }
    
    // Nodes bestimmen
    int start_idx = 0;
    int end_idx = 0;
    Node* nodes_to_check[MAX_NODES];
    int nodes_to_check_count = 0;
    
    if (strcmp(node_arg, "all") == 0) {
        for (int i = 0; i < node_count; i++) {
            nodes_to_check[nodes_to_check_count++] = &nodes[i];
        }
    } else {
        int idx = find_node_index(node_arg);
        if (idx >= 0) {
            nodes_to_check[nodes_to_check_count++] = &nodes[idx];
        } else {
            char error_msg[128];
            snprintf(error_msg, sizeof(error_msg), "Unknown node: %s", node_arg);
            log_message(error_msg, "ERROR");
            return 1;
        }
    }
    
    // Health-Checks durchführen
    Alert all_alerts[100];
    int total_alerts = 0;
    
    for (int n = 0; n < nodes_to_check_count; n++) {
        Node* node_config = nodes_to_check[n];
        char msg[128];
        snprintf(msg, sizeof(msg), "Checking %s (%s)", node_config->name, node_config->id);
        log_message(msg, "INFO");
        
        // Ping
        if (strcmp(check_arg, "ping") == 0 || strcmp(check_arg, "all") == 0) {
            if (strcmp(node_config->host, "localhost") != 0) {
                int ping_ok = check_ping(node_config->host, 5);
                snprintf(msg, sizeof(msg), "  Ping: %s", ping_ok ? "OK" : "FAILED");
                log_message(msg, "INFO");
            }
        }
        
        // SSH
        if (strcmp(check_arg, "ssh") == 0 || strcmp(check_arg, "all") == 0) {
            int ssh_ok = check_ssh(node_config);
            snprintf(msg, sizeof(msg), "  SSH: %s", ssh_ok ? "OK" : "FAILED");
            log_message(msg, "INFO");
        }
        
        // Metriken
        if (strcmp(check_arg, "metrics") == 0 || strcmp(check_arg, "all") == 0) {
            Metrics metrics = get_node_metrics(node_config);
            
            if (metrics.available) {
                if (metrics.cpu >= 0) {
                    snprintf(msg, sizeof(msg), "  CPU: %.1f%%", metrics.cpu);
                    log_message(msg, "INFO");
                } else {
                    log_message("  CPU: N/A", "INFO");
                }
                
                if (metrics.ram >= 0) {
                    snprintf(msg, sizeof(msg), "  RAM: %.1f%%", metrics.ram);
                    log_message(msg, "INFO");
                } else {
                    log_message("  RAM: N/A", "INFO");
                }
                
                if (metrics.disk >= 0) {
                    snprintf(msg, sizeof(msg), "  Disk: %d%%", metrics.disk);
                    log_message(msg, "INFO");
                } else {
                    log_message("  Disk: N/A", "INFO");
                }
                
                if (metrics.load >= 0) {
                    snprintf(msg, sizeof(msg), "  Load: %.2f", metrics.load);
                    log_message(msg, "INFO");
                } else {
                    log_message("  Load: N/A", "INFO");
                }
            } else {
                log_message("  Metrics: UNAVAILABLE", "INFO");
            }
            
            // Alerts prüfen
            Alert node_alerts[20];
            int alert_count = check_alerts(node_config->id, node_config, &metrics, node_alerts, 20);
            
            for (int i = 0; i < alert_count; i++) {
                all_alerts[total_alerts++] = node_alerts[i];
            }
        }
    }
    
    // Alerts senden
    if (send_alerts && total_alerts > 0) {
        char msg[128];
        snprintf(msg, sizeof(msg), "\nSending %d alerts...", total_alerts);
        log_message(msg, "INFO");
        
        for (int i = 0; i < total_alerts; i++) {
            send_alert(&all_alerts[i]);
        }
    } else if (total_alerts > 0) {
        char msg[128];
        snprintf(msg, sizeof(msg), "\n%d alerts found (use --alert to send)", total_alerts);
        log_message(msg, "INFO");
    } else {
        log_message("\nAll nodes healthy!", "INFO");
    }
    
    return 0;
}
