// abstraction-provenance: {"artifact_sha256": "8dc0e96dd8efdb8c3301912425114e04bc9f8035f97f4968e2000a5a16ff3486", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "c"}
// channel_status.py — portiert nach c
// Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <dirent.h>

#define WORKSPACE "/home/openclaw/.openclaw/workspace"
#define LOGS_DB WORKSPACE "/db/logs.db"
#define CONFIG_FILE WORKSPACE "/config/channel-status.json"
#define LOG_FILE WORKSPACE "/logs/channel-status.log"

// Globale Variablen für Node-Namen
const char* NODE_NAMES[][5] = {
    {"openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"},
    {"openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125", NULL, NULL},
    {"openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39", NULL},
    {"openclaw-node5", "lenovo-node7", "lenovo-node7.taild25fea.ts.net", "100.103.140.35", NULL}
};

const int NODE_COUNTS[] = {5, 3, 4, 4};

void log_message(const char* message, const char* level) {
    time_t now;
    struct tm *tm_info;
    char timestamp[20];
    
    time(&now);
    tm_info = localtime(&now);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    
    FILE* log_file = fopen(LOG_FILE, "a");
    if (log_file) {
        fprintf(log_file, "[%s] [%s] %s\n", timestamp, level, message);
        fclose(log_file);
    }
    
    printf("[%s] [%s] %s\n", timestamp, level, message);
}

int execute_command(const char* command, char** output) {
    FILE* fp;
    char buffer[1024];
    size_t total_size = 0;
    size_t buffer_size = 1024;
    
    *output = malloc(buffer_size);
    if (!(*output)) return -1;
    
    fp = popen(command, "r");
    if (!fp) {
        free(*output);
        return -1;
    }
    
    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        size_t len = strlen(buffer);
        if (total_size + len + 1 > buffer_size) {
            buffer_size *= 2;
            char* temp = realloc(*output, buffer_size);
            if (!temp) {
                free(*output);
                pclose(fp);
                return -1;
            }
            *output = temp;
        }
        strcpy(*output + total_size, buffer);
        total_size += len;
    }
    
    (*output)[total_size] = '\0';
    int status = pclose(fp);
    return WEXITSTATUS(status);
}

char* get_current_time_iso() {
    time_t now;
    struct tm *tm_info;
    char* iso_time = malloc(30);
    
    time(&now);
    tm_info = localtime(&now);
    strftime(iso_time, 30, "%Y-%m-%dT%H:%M:%S", tm_info);
    
    return iso_time;
}

int fetch_node_status(int* states) {
    char* output = NULL;
    int result = execute_command("openclaw nodes status --json", &output);
    
    if (result != 0 || !output) {
        free(output);
        return -1;
    }
    
    // Initialize all states to 0 (offline)
    for (int i = 0; i < 4; i++) {
        states[i] = 0;
    }
    
    // Simple JSON parsing - looking for connected nodes
    // This is a simplified version that looks for patterns in the output
    for (int node_idx = 0; node_idx < 4; node_idx++) {
        for (int alias_idx = 0; alias_idx < NODE_COUNTS[node_idx]; alias_idx++) {
            if (strstr(output, NODE_NAMES[node_idx][alias_idx])) {
                // Check if this node is connected (simple pattern matching)
                char* pos = strstr(output, NODE_NAMES[node_idx][alias_idx]);
                if (pos && (strstr(pos, "\"connected\":true") || 
                           (strstr(pos, "\"connected\"") && strstr(pos, "true")))) {
                    states[node_idx] = 1;
                    break;
                }
            }
        }
    }
    
    // node1 (Gateway) is always online if we can reach it
    states[4] = 1;
    
    free(output);
    return 0;
}

void get_disk_usage(char* disk_used, size_t size) {
    FILE* fp = popen("df -h / | awk 'NR==2 {print $5}'", "r");
    if (fp) {
        fgets(disk_used, size, fp);
        // Remove newline
        char* newline = strchr(disk_used, '\n');
        if (newline) *newline = '\0';
        pclose(fp);
    } else {
        strcpy(disk_used, "unknown");
    }
}

void get_ram_usage(char* ram_total, char* ram_used, size_t size) {
    FILE* fp = popen("free -h | awk 'NR==2 {print $2, $3}'", "r");
    if (fp) {
        char buffer[100];
        if (fgets(buffer, sizeof(buffer), fp)) {
            sscanf(buffer, "%s %s", ram_total, ram_used);
        }
        pclose(fp);
    } else {
        strcpy(ram_total, "unknown");
        strcpy(ram_used, "unknown");
    }
}

void format_daily_status(int* node_states, int active_crons, 
                         const char* disk_used, const char* ram_total, const char* ram_used, 
                         char* message, size_t message_size) {
    time_t now;
    struct tm *tm_info;
    char time_str[50];
    
    time(&now);
    tm_info = localtime(&now);
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M", tm_info);
    
    snprintf(message, message_size,
        "📊 **Täglicher Status-Report**\n"
        "🗓️ %s\n\n"
        "**🖥️ Nodes (TODO/%d online):**\n",
        time_str, 
        (node_states[0] ? 1 : 0) + (node_states[1] ? 1 : 0) + 
        (node_states[2] ? 1 : 0) + (node_states[3] ? 1 : 0) + 
        (node_states[4] ? 1 : 0));
    
    // Add node statuses
    const char* node_names[] = {"Gateway", "Node2", "Node3", "Redmi", "Lenovo"};
    for (int i = 0; i < 5; i++) {
        const char* emoji = node_states[i] ? "🟢" : "🔴";
        char node_line[100];
        snprintf(node_line, sizeof(node_line), "%s %s: %s\n", 
                 emoji, node_names[i], node_states[i] ? "online" : "offline");
        strncat(message, node_line, message_size - strlen(message) - 1);
    }
    
    char agents_section[200];
    snprintf(agents_section, sizeof(agents_section),
        "\n**🤖 Agents:**\n"
        "Aktive Cron-Jobs: %d\n",
        active_crons);
    strncat(message, agents_section, message_size - strlen(message) - 1);
    
    if (strcmp(disk_used, "unknown") != 0) {
        char system_section[200];
        snprintf(system_section, sizeof(system_section),
            "\n**💾 System:**\n"
            "Disk: %s belegt\n"
            "RAM: %s / %s\n",
            disk_used, ram_used, ram_total);
        strncat(message, system_section, message_size - strlen(message) - 1);
    }
}

void format_weekly_status(int* node_states, char* message, size_t message_size) {
    time_t now;
    struct tm *tm_info;
    char week_str[10];
    char year_str[10];
    
    time(&now);
    tm_info = localtime(&now);
    strftime(week_str, sizeof(week_str), "%V", tm_info);
    strftime(year_str, sizeof(year_str), "%Y", tm_info);
    
    snprintf(message, message_size,
        "📈 **Wöchentlicher Report**\n"
        "📅 Woche %s - %s\n\n"
        "**Nodes:**\n",
        week_str, year_str);
    
    const char* node_names[] = {"Gateway", "Node2", "Node3", "Redmi", "Lenovo"};
    for (int i = 0; i < 5; i++) {
        char node_line[100];
        snprintf(node_line, sizeof(node_line), "- %s: %s\n", 
                 node_names[i], node_states[i] ? "online" : "offline");
        strncat(message, node_line, message_size - strlen(message) - 1);
    }
}

int send_to_channel(const char* message, const char* channel_type, const char* channel_id) {
    if (strcmp(channel_type, "telegram") != 0) {
        log_message("Channel type not implemented", "WARN");
        return 0;
    }
    
    char command[1024];
    snprintf(command, sizeof(command), 
             "openclaw message send --target %s --message '%s'", 
             channel_id, message);
    
    int result = system(command);
    if (result == 0) {
        char log_msg[200];
        snprintf(log_msg, sizeof(log_msg), "Message sent to %s %s", channel_type, channel_id);
        log_message(log_msg, "INFO");
        return 1;
    } else {
        char log_msg[200];
        snprintf(log_msg, sizeof(log_msg), "Failed to send message");
        log_message(log_msg, "ERROR");
        return 0;
    }
}

int get_active_cron_jobs() {
    FILE* fp = popen("crontab -l 2>/dev/null | grep -v '^#' | wc -l", "r");
    if (fp) {
        char buffer[20];
        if (fgets(buffer, sizeof(buffer), fp)) {
            int count = atoi(buffer);
            pclose(fp);
            return count;
        }
        pclose(fp);
    }
    return -1; // unknown
}

int main(int argc, char* argv[]) {
    const char* report_type = NULL;
    const char* alert_message = NULL;
    const char* channel_id = "-1002381931352";
    int dry_run = 0;
    
    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--type") == 0 && i + 1 < argc) {
            report_type = argv[++i];
        } else if (strcmp(argv[i], "--message") == 0 && i + 1 < argc) {
            alert_message = argv[++i];
        } else if (strcmp(argv[i], "--channel") == 0 && i + 1 < argc) {
            channel_id = argv[++i];
        } else if (strcmp(argv[i], "--dry-run") == 0) {
            dry_run = 1;
        }
    }
    
    if (!report_type) {
        fprintf(stderr, "Usage: %s --type <daily|weekly|alert> [--message <msg>] [--channel <id>] [--dry-run]\n", argv[0]);
        return 1;
    }
    
    char log_start[100];
    snprintf(log_start, sizeof(log_start), "Starting %s status update", report_type);
    log_message(log_start, "INFO");
    
    // Create log directory if it doesn't exist
    mkdir(WORKSPACE "/logs", 0755);
    
    // Fetch node status
    int node_states[5] = {0}; // node1 through node5
    if (fetch_node_status(node_states) != 0) {
        log_message("Failed to fetch node status", "ERROR");
        // Continue anyway with unknown states
    }
    
    // Get system metrics
    char disk_used[20] = "unknown";
    char ram_total[20] = "unknown";
    char ram_used[20] = "unknown";
    
    get_disk_usage(disk_used, sizeof(disk_used));
    get_ram_usage(ram_total, ram_used, sizeof(ram_total));
    
    // Get active cron jobs
    int active_crons = get_active_cron_jobs();
    
    // Format message based on type
    char message[2048] = {0};
    
    if (strcmp(report_type, "daily") == 0) {
        format_daily_status(node_states, active_crons, disk_used, ram_total, ram_used, message, sizeof(message));
    } else if (strcmp(report_type, "weekly") == 0) {
        format_weekly_status(node_states, message, sizeof(message));
    } else if (strcmp(report_type, "alert") == 0) {
        snprintf(message, sizeof(message), "🚨 **ALERT**\n%s", alert_message ? alert_message : "Manual alert");
    } else {
        fprintf(stderr, "Unknown report type: %s\n", report_type);
        return 1;
    }
    
    // Send or print message
    if (dry_run) {
        printf("\n--- DRY RUN ---\n");
        printf("%s\n", message);
        printf("--- END ---\n");
    } else {
        send_to_channel(message, "telegram", channel_id);
    }
    
    log_message("Status update completed", "INFO");
    
    return 0;
}
