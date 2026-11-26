// abstraction-provenance: {"artifact_sha256": "bd1657a33b9968c687de352c6e0f70cecb2acd1b904161679a1c8d494f80c8dc", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "cpp"}
// node_health.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <fstream>
#include <sstream>
#include <chrono>
#include <filesystem>
#include <cstdlib>
#include <stdexcept>
#include <memory>
#include <thread>
#include <future>
#include <algorithm>

// Konfiguration
const std::string WORKSPACE = "/home/openclaw/.openclaw/workspace";
const std::string HEALTH_DB = WORKSPACE + "/db/health.db";
const std::string LOG_FILE = WORKSPACE + "/logs/node-health.log";

// Node-Konfigurationsstruktur
struct NodeConfig {
    std::string name;
    std::string host;
    std::string user;
    std::string ssh_key;
    std::string ssh_opts;
    int port = 0;
    int disk_warning = 85;
    bool critical = false;
    bool optional = false;
};

// Metrik-Struktur
struct NodeMetrics {
    std::string timestamp;
    bool available = false;
    double cpu = 0.0;
    double ram = 0.0;
    int disk = 0;
    double load_avg = 0.0;
    std::string gateway_status;
};

// Alert-Struktur
struct Alert {
    std::string level;
    std::string message;
};

// Globale Node-Definitionen
std::map<std::string, NodeConfig> NODES = {
    {"node1", {"Node 1", "localhost", "openclaw", "", "", 0, 85, true, false}},
    {"node2", {"Node 2", "10.10.0.2", "root", "~/.ssh/id_rsa", "-o ConnectTimeout=10 -o BatchMode=yes", 0, 85, false, false}},
    {"node3", {"Node 3", "localhost", "root", "", "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes", 18794, 85, false, false}},
    {"node5", {"Redmi", "192.168.1.x", "openclaw", "", "", 0, 85, false, true}}
};

class Logger {
public:
    static void log(const std::string& message, const std::string& level = "INFO") {
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        std::stringstream ss;
        ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
        std::string timestamp = ss.str();
        
        std::string entry = "[" + timestamp + "] [" + level + "] " + message;
        std::cout << entry << std::endl;
        
        // Log-Datei erstellen/öffnen
        std::filesystem::create_directories(std::filesystem::path(LOG_FILE).parent_path());
        std::ofstream file(LOG_FILE, std::ios::app);
        if (file.is_open()) {
            file << entry << std::endl;
        }
    }
};

class SubprocessExecutor {
public:
    static std::pair<int, std::string> run(const std::vector<std::string>& cmd) {
        std::string command_str;
        for (size_t i = 0; i < cmd.size(); ++i) {
            if (i > 0) command_str += " ";
            command_str += cmd[i];
        }
        return execute_command(command_str);
    }
    
    static std::pair<int, std::string> run_shell(const std::string& cmd) {
        return execute_command(cmd);
    }
    
private:
    static std::pair<int, std::string> execute_command(const std::string& cmd) {
        std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
        if (!pipe) {
            throw std::runtime_error("popen() failed!");
        }
        
        std::string output;
        char buffer[128];
        while (fgets(buffer, sizeof buffer, pipe.get()) != nullptr) {
            output += buffer;
        }
        
        int status = pclose(pipe.release());
        int exit_code = WEXITSTATUS(status);
        
        return {exit_code, output};
    }
};

bool check_ping(const std::string& host, int timeout = 10) {
    /** Prüft Erreichbarkeit (Timeout seconds) */
    std::string cmd = "ping -c 1 -W " + std::to_string(timeout) + " " + host + " >/dev/null 2>&1";
    int result = system(cmd.c_str());
    return WEXITSTATUS(result) == 0;
}

bool check_ssh(const NodeConfig& node_config) {
    /** Prüft SSH-Verbindung */
    std::string host = node_config.host;
    std::string user = node_config.user.empty() ? "root" : node_config.user;
    std::string ssh_opts = node_config.ssh_opts;
    int port = node_config.port;
    
    std::string cmd = "ssh ";
    if (!ssh_opts.empty()) {
        cmd += ssh_opts + " ";
    }
    if (port > 0) {
        cmd += "-p " + std::to_string(port) + " ";
    }
    cmd += "-o ConnectTimeout=10 -o BatchMode=yes " + user + "@" + host + " echo \"OK\" 2>/dev/null";
    
    auto [exit_code, output] = SubprocessExecutor::run_shell(cmd);
    return exit_code == 0 && output.find("OK") != std::string::npos;
}

NodeMetrics get_node_metrics(const NodeConfig& node_config) {
    /** Holt Metriken via SSH */
    NodeMetrics metrics;
    
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%dT%H:%M:%S");
    metrics.timestamp = ss.str();
    
    std::string host = node_config.host;
    std::string user = node_config.user.empty() ? "root" : node_config.user;
    
    // SSH-Command für alle Metriken
    std::string cmd = "ssh -o ConnectTimeout=10 " + user + "@" + host + " '"
        "# CPU\n"
        "echo \"CPU:$(top -bn1 | grep \\\"Cpu(s)\\\" | awk \\\"{print \\\\\\$2}\\\" | cut -d\\\"%\\\" -f1)\"\n"
        "\n"
        "# RAM\n"
        "echo \"RAM:$(free | grep Mem | awk \\\"{print (\\\\\\$3/\\\\\\$2) * 100.0}\\\")\"\n"
        "\n"
        "# Disk\n"
        "echo \"DISK:$(df -h / | tail -1 | awk \\\"{print \\\\\\$5}\\\" | tr -d \\\"%\\\")\"\n"
        "\n"
        "# Load\n"
        "echo \"LOAD:$(uptime | awk -F\\\"load average:\\\" \\\"{print \\\\\\$2}\\\" | awk \\\"{print \\\\\\$1}\\\" | tr -d \\\"\\\",\\\")\"\n"
        "\n"
        "# Gateway Status\n"
        "if command -v openclaw >/dev/null 2>&1; then\n"
        "    systemctl is-active openclaw-gateway 2>/dev/null || echo \\\"GATEWAY:inactive\\\"\n"
        "fi\n"
        "' 2>/dev/null";
    
    try {
        auto [exit_code, output] = SubprocessExecutor::run_shell(cmd);
        
        if (exit_code == 0) {
            metrics.available = true;
            
            std::istringstream iss(output);
            std::string line;
            while (std::getline(iss, line)) {
                size_t colon_pos = line.find(':');
                if (colon_pos != std::string::npos) {
                    std::string key = line.substr(0, colon_pos);
                    std::string value = line.substr(colon_pos + 1);
                    
                    if (key == "CPU" && !value.empty()) {
                        try {
                            metrics.cpu = std::stod(value);
                        } catch (...) {}
                    } else if (key == "RAM" && !value.empty()) {
                        try {
                            metrics.ram = std::stod(value);
                        } catch (...) {}
                    } else if (key == "DISK" && !value.empty()) {
                        try {
                            metrics.disk = std::stoi(value);
                        } catch (...) {}
                    } else if (key == "LOAD" && !value.empty()) {
                        try {
                            metrics.load_avg = std::stod(value);
                        } catch (...) {}
                    } else if (key == "GATEWAY") {
                        metrics.gateway_status = value;
                    }
                }
            }
        }
    } catch (const std::exception& e) {
        Logger::log("Error checking " + node_config.name + ": " + e.what(), "ERROR");
    }
    
    return metrics;
}

std::vector<Alert> check_alerts(const std::string& node_id, const NodeConfig& node_config, const NodeMetrics& metrics) {
    /** Prüft Schwellwerte und generiert Alerts */
    std::vector<Alert> alerts;
    
    // Verfügbarkeit
    if (!metrics.available) {
        if (!node_config.optional) {
            alerts.push_back({"CRITICAL", "Node " + node_config.name + " nicht erreichbar!"});
        }
    } else {
        // CPU
        if (metrics.cpu > 90) {
            alerts.push_back({"WARNING", "Node " + node_config.name + ": CPU bei " + std::to_string(metrics.cpu) + "%"});
        }
        
        // RAM
        if (metrics.ram > 90) {
            alerts.push_back({"WARNING", "Node " + node_config.name + ": RAM bei " + std::to_string(metrics.ram) + "%"});
        }
        
        // Disk
        int disk_threshold = node_config.disk_warning;
        if (metrics.disk > disk_threshold) {
            std::string level = (metrics.disk > 95) ? "CRITICAL" : "WARNING";
            alerts.push_back({level, "Node " + node_config.name + ": Disk bei " + std::to_string(metrics.disk) + "%"});
        }
        
        // Gateway
        if (node_config.critical && metrics.gateway_status == "inactive") {
            alerts.push_back({"CRITICAL", "Node " + node_config.name + ": OpenClaw Gateway nicht aktiv!"});
        }
    }
    
    return alerts;
}

void send_alert(const Alert& alert) {
    /** Sendet Alert via channel-status-agent */
    try {
        std::string script_path = WORKSPACE + "/skills/channel-status-agent/scripts/channel_status.py";
        std::string cmd = "python3 " + script_path + " --type alert --message \"" + alert.level + ": " + alert.message + "\" 2>/dev/null";
        int result = system(cmd.c_str());
        Logger::log("Alert sent: " + alert.message);
    } catch (const std::exception& e) {
        Logger::log("Failed to send alert: " + std::string(e.what()), "ERROR");
    }
}

int main(int argc, char* argv[]) {
    /** Hauptfunktion */
    std::string node_arg = "all";
    std::string check_arg = "all";
    bool alert_flag = false;
    
    // Kommandozeilenargumente parsen
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--node" && i + 1 < argc) {
            node_arg = argv[++i];
        } else if (arg == "--check" && i + 1 < argc) {
            check_arg = argv[++i];
        } else if (arg == "--alert") {
            alert_flag = true;
        }
    }
    
    // Nodes bestimmen
    std::vector<std::pair<std::string, NodeConfig>> nodes_to_check;
    
    if (node_arg == "all") {
        for (const auto& pair : NODES) {
            nodes_to_check.push_back(pair);
        }
    } else {
        auto it = NODES.find(node_arg);
        if (it != NODES.end()) {
            nodes_to_check.push_back(*it);
        } else {
            Logger::log("Unknown node: " + node_arg, "ERROR");
            return 1;
        }
    }
    
    // Health-Checks durchführen
    std::vector<Alert> all_alerts;
    
    for (const auto& pair : nodes_to_check) {
        const std::string& node_id = pair.first;
        const NodeConfig& node_config = pair.second;
        
        Logger::log("Checking " + node_config.name + " (" + node_id + ")");
        
        // Ping
        if (check_arg == "ping" || check_arg == "all") {
            if (node_config.host != "localhost") {
                bool ping_ok = check_ping(node_config.host);
                Logger::log("  Ping: " + std::string(ping_ok ? "OK" : "FAILED"));
            }
        }
        
        // SSH
        if (check_arg == "ssh" || check_arg == "all") {
            bool ssh_ok = check_ssh(node_config);
            Logger::log("  SSH: " + std::string(ssh_ok ? "OK" : "FAILED"));
        }
        
        // Metriken
        if (check_arg == "metrics" || check_arg == "all") {
            NodeMetrics metrics = get_node_metrics(node_config);
            
            if (metrics.available) {
                Logger::log("  CPU: " + (metrics.cpu > 0 ? std::to_string(metrics.cpu) + "%" : "N/A"));
                Logger::log("  RAM: " + (metrics.ram > 0 ? std::to_string(metrics.ram) + "%" : "N/A"));
                Logger::log("  Disk: " + (metrics.disk > 0 ? std::to_string(metrics.disk) + "%" : "N/A"));
                Logger::log("  Load: " + (metrics.load_avg > 0 ? std::to_string(metrics.load_avg) : "N/A"));
            } else {
                Logger::log("  Metrics: UNAVAILABLE");
            }
            
            // Alerts prüfen
            std::vector<Alert> alerts = check_alerts(node_id, node_config, metrics);
            all_alerts.insert(all_alerts.end(), alerts.begin(), alerts.end());
        }
    }
    
    // Alerts senden
    if (alert_flag && !all_alerts.empty()) {
        Logger::log("\nSending " + std::to_string(all_alerts.size()) + " alerts...");
        for (const auto& alert : all_alerts) {
            send_alert(alert);
        }
    } else if (!all_alerts.empty()) {
        Logger::log("\n" + std::to_string(all_alerts.size()) + " alerts found (use --alert to send)");
    } else {
        Logger::log("\nAll nodes healthy!");
    }
    
    return 0;
}
