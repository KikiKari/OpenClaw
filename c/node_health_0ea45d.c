// abstraction-provenance: {"artifact_sha256": "2612425c007e4344409c321d9c82ff7949eca06431e10d845c2fcc217992964a", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "c"}
// node_health.py — portiert nach c
// Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <time.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>
#include <signal.h>

#define WORKSPACE "/home/openclaw/.openclaw/workspace"
#define HEALTH_DB WORKSPACE "/db/health.db"
#define LOG_FILE WORKSPACE "/logs/node-health.log"

typedef struct {
    char id[32];
    char name[64];
    char host[64];
    char user[32];
    char ssh_key[128];
    char ssh_opts[128];
    int port;
    int critical;
    int optional;
    int disk_warning;
} NodeConfig;

typedef struct {
    char timestamp[64];
    int available;
    double cpu;
    double ram;
    int disk;
    double load;
    char gateway_status[32];
} NodeMetrics;

NodeConfig NODES[] = {
    {"node1", "Node 1", "localhost", "openclaw", "", "", 0, 1, 0, 85},
    {"node2", "Node 2", "10.10.0.2", "root", "~/.ssh/id_rsa", "-o ConnectTimeout=10 -o BatchMode=yes", 0, 0, 0, 85},
    {"node3", "Node 3", "localhost", "root", "", "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes", 18794, 0, 0, 85},
    {"node5", "Redmi", "192.168.1.x", "openclaw", "", "", 0, 0, 1, 85}
};

int NODE_COUNT = 4;

void log_message(const char* message, const char* level) {
    time_t now;
    struct tm *tm_info;
    char timestamp[64];
    
    time(&now);
    tm_info = localtime(&now);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    
    char entry[512];
    snprintf(entry, sizeof(entry), "[%s] [%s] %s\n", timestamp, level, message);
    printf("%s", entry);
    
    FILE* log_file = fopen(LOG_FILE, "a");
    if (log_file) {
        fprintf(log_file, "%s", entry);
        fclose(log_file);
    }
}

int create_directories(const char* path) {
    char tmp[256];
    char* p = NULL;
    size_t len;
    
    snprintf(tmp, sizeof(tmp), "%s", path);
    len = strlen(tmp);
    if (tmp[len - 1] == '/')
        tmp[len - 1] = 0;
    for (p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            mkdir(tmp, S_IRWXU);
            *p = '/';
        }
    }
    return mkdir(tmp, S_IRWXU);
}

int check_ping(const char* host, int timeout) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "ping -c 1 -W %d %s >/dev/null 2>&1", timeout, host);
    return system(cmd) == 0;
}

int check_ssh(NodeConfig* node_config) {
    char cmd[512];
    char full_cmd[512];
    
    if (strlen(node_config->ssh_opts) > 0) {
        snprintf(full_cmd, sizeof(full_cmd), "ssh %s -o ConnectTimeout=10 -o BatchMode=yes %s@%s echo \"OK\" 2>/dev/null",
                 node_config->ssh_opts, node_config->user, node_config->host);
    } else if (node_config->port > 0) {
        snprintf(full_cmd, sizeof(full_cmd), "ssh -p %d -o ConnectTimeout=10 -o BatchMode=yes %s@%s echo \"OK\" 2>/dev/null",
                 node_config->port, node_config->user, node_config->host);
    } else {
        snprintf(full_cmd, sizeof(full_cmd), "ssh -o ConnectTimeout=10 -o BatchMode=yes %s@%s echo \"OK\" 2>/dev/null",
                 node_config->user, node_config->host);
    }
    
    FILE* pipe = popen(full_cmd, "r");
    if (!pipe) return 0;
    
    char buffer[128];
    int found = 0;
    while (fgets(buffer, sizeof(buffer), pipe)) {
        if (strstr(buffer, "OK")) {
            found = 1;
            break;
        }
    }
    
    int status = pclose(pipe);
    return (status == 0) && found;
}

void get_current_timestamp(char* buffer, size_t size) {
    time_t now;
    struct tm *tm_info;
    
    time(&now);
    tm_info = localtime(&now);
    strftime(buffer, size, "%Y-%m-%dT%H:%M:%S", tm_info);
}

void get_node_metrics(NodeConfig* node_config, NodeMetrics* metrics) {
    get_current_timestamp(metrics->timestamp, sizeof(metrics->timestamp));
    metrics->available = 0;
    metrics->cpu = -1.0;
    metrics->ram = -1.0;
    metrics->disk = -1;
    metrics->load = -1.0;
    strcpy(metrics->gateway_status, "");
    
    char cmd[2048];
    snprintf(cmd, sizeof(cmd),
             "ssh -o ConnectTimeout=10 %s@%s '"
             "echo \"CPU:$(top -bn1 | grep \"Cpu(s)\" | awk \"{print \\$2}\" | cut -d\"%%\" -f1)\"; "
             "echo \"RAM:$(free | grep Mem | awk \"{print (\\$3/\\$2) * 100.0}\")\"; "
             "echo \"DISK:$(df -h / | tail -1 | awk \"{print \\$5}\" | tr -d \"%%\")\"; "
             "echo \"LOAD:$(uptime | awk -F\"load average:\" \"{print \\$2}\" | awk \"{print \\$1}\" | tr -d \",\")\"; "
             "if command -v openclaw >/dev/null 2>&1; then "
             "systemctl is-active openclaw-gateway 2>/dev/null || echo \"GATEWAY:inactive\"; "
             "fi' 2>/dev/null",
             node_config->user, node_config->host);
    
    FILE* pipe = popen(cmd, "r");
    if (!pipe) return;
    
    char buffer[256];
    while (fgets(buffer, sizeof(buffer), pipe)) {
        buffer[strcspn(buffer, "\n")] = 0;
        
        if (strstr(buffer, "CPU:")) {
            char* value = strchr(buffer, ':');
            if (value) {
                metrics->cpu = atof(value + 1);
                metrics->available = 1;
            }
        } else if (strstr(buffer, "RAM:")) {
            char* value = strchr(buffer, ':');
            if (value) {
                metrics->ram = atof(value + 1);
                metrics->available = 1;
            }
        } else if (strstr(buffer, "DISK:")) {
            char* value = strchr(buffer, ':');
            if (value) {
                metrics->disk = atoi(value + 1);
                metrics->available = 1;
            }
        } else if (strstr(buffer, "LOAD:")) {
            char* value = strchr(buffer, ':');
            if (value) {
                metrics->load = atof(value + 1);
                metrics->available = 1;
            }
        } else if (strstr(buffer, "GATEWAY:")) {
            char* value = strchr(buffer, ':');
            if (value) {
                strncpy(metrics->gateway_status, value + 1, sizeof(metrics->gateway_status) - 1);
                metrics->gateway_status[sizeof(metrics->gateway_status) - 1] = '\0';
            }
        }
    }
    
    pclose(pipe);
}

typedef struct {
    char level[16];
    char message[256];
} Alert;

int check_alerts(const char* node_id, NodeConfig* node_config, NodeMetrics* metrics, Alert* alerts, int max_alerts) {
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
        
        if (metrics->disk > node_config->disk_warning) {
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
             "python3 %s/skills/channel-status-agent/scripts/channel_status.py "
             "--type alert --message \"%s: %s\" >/dev/null 2>&1",
             WORKSPACE, alert->level, alert->message);
    
    system(cmd);
    log_message(alert->message, "INFO");
}

int find_node_index(const char* node_id) {
    for (int i = 0; i < NODE_COUNT; i++) {
        if (strcmp(NODES[i].id, node_id) == 0) {
            return i;
        }
    }
    return -1;
}

void print_usage() {
    printf("Usage: node_health [options]\n");
    printf("Options:\n");
    printf("  --node NODE_ID    Node ID oder \"all\"\n");
    printf("  --check TYPE      Check type: ping, ssh, metrics, all\n");
    printf("  --alert           Sende Alerts\n");
}

int main(int argc, char* argv[]) {
    char node_arg[32] = "all";
    char check_arg[16] = "all";
    int send_alerts = 0;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--node") == 0 && i + 1 < argc) {
            strncpy(node_arg, argv[++i], sizeof(node_arg) - 1);
            node_arg[sizeof(node_arg) - 1] = '\0';
        } else if (strcmp(argv[i], "--check") == 0 && i + 1 < argc) {
            strncpy(check_arg, argv[++i], sizeof(check_arg) - 1);
            check_arg[sizeof(check_arg) - 1] = '\0';
        } else if (strcmp(argv[i], "--alert") == 0) {
            send_alerts = 1;
        } else if (strcmp(argv[i], "--help") == 0) {
            print_usage();
            return 0;
        }
    }
    
    create_directories(LOG_FILE);
    
    NodeConfig* nodes_to_check[NODE_COUNT];
    int nodes_count = 0;
    
    if (strcmp(node_arg, "all") == 0) {
        for (int i = 0; i < NODE_COUNT; i++) {
            nodes_to_check[nodes_count++] = &NODES[i];
        }
    } else {
        int index = find_node_index(node_arg);
        if (index >= 0) {
            nodes_to_check[0] = &NODES[index];
            nodes_count = 1;
        } else {
            char error_msg[128];
            snprintf(error_msg, sizeof(error_msg), "Unknown node: %s", node_arg);
            log_message(error_msg, "ERROR");
            return 1;
        }
    }
    
    Alert all_alerts[64];
    int total_alerts = 0;
    
    for (int i = 0; i < nodes_count; i++) {
        NodeConfig* node_config = nodes_to_check[i];
        char log_msg[128];
        snprintf(log_msg, sizeof(log_msg), "Checking %s (%s)", node_config->name, node_config->id);
        log_message(log_msg, "INFO");
        
        if (strcmp(check_arg, "ping") == 0 || strcmp(check_arg, "all") == 0) {
            if (strcmp(node_config->host, "localhost") != 0) {
                int ping_ok = check_ping(node_config->host, 10);
                log_message(ping_ok ? "  Ping: OK" : "  Ping: FAILED", "INFO");
            }
        }
        
        if (strcmp(check_arg, "ssh") == 0 || strcmp(check_arg, "all") == 0) {
            int ssh_ok = check_ssh(node_config);
            log_message(ssh_ok ? "  SSH: OK" : "  SSH: FAILED", "INFO");
        }
        
        if (strcmp(check_arg, "metrics") == 0 || strcmp(check_arg, "all") == 0) {
            NodeMetrics metrics;
            get_node_metrics(node_config, &metrics);
            
            if (metrics.available) {
                char msg[64];
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
            
            Alert node_alerts[16];
            int alert_count = check_alerts(node_config->id, node_config, &metrics, node_alerts, 16);
            
            for (int j = 0; j < alert_count; j++) {
                strncpy(all_alerts[total_alerts].level, node_alerts[j].level, sizeof(all_alerts[total_alerts].level) - 1);
                strncpy(all_alerts[total_alerts].message, node_alerts[j].message, sizeof(all_alerts[total_alerts].message) - 1);
                total_alerts++;
            }
        }
    }
    
    if (send_alerts && total_alerts > 0) {
        char alert_msg[64];
        snprintf(alert_msg, sizeof(alert_msg), "\nSending %d alerts...", total_alerts);
        log_message(alert_msg, "INFO");
        
        for (int i = 0; i < total_alerts; i++) {
            send_alert(&all_alerts[i]);
        }
    } else if (total_alerts > 0) {
        char alert_msg[128];
        snprintf(alert_msg, sizeof(alert_msg), "\n%d alerts found (use --alert to send)", total_alerts);
        log_message(alert_msg, "INFO");
    } else {
        log_message("\nAll nodes healthy!", "INFO");
    }
    
    return 0;
}
