// abstraction-provenance: {"artifact_sha256": "d251d8130edfe87acb2a73740e251e31bee942dbf694610469c266872d693a43", "source_sha256": "86aad5ae0d9b77ebdb9a2aaecbf0c4875ad3a241571b573934c882ecd55df14e", "target_language": "cpp"}
// node_health.py — portiert nach cpp
// Quelle: python, workspace@local:git/skills/node-health-monitor/scripts/node_health.py
// auch in: workspace@local:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <thread>
#include <cstdlib>
#include <memory>
#include <stdexcept>
#include <algorithm>

// Konfiguration
const std::string WORKSPACE = "/home/openclaw/.openclaw/workspace";
const std::string HEALTH_DB = WORKSPACE + "/db/health.db";
const std::string LOG_FILE = WORKSPACE + "/logs/node-health.log";

struct NodeConfig {
    std::string name;
    std::string host;
    std::string user;
    bool critical = false;
    bool optional = false;
    bool ssh_enabled = true;
    std::string ssh_key;
    int disk_warning = 85;
};

struct Metrics {
    std::string timestamp;
    bool available = false;
    double cpu = 0.0;
    double ram = 0.0;
    int disk = 0;
    double load = 0.0;
    std::string gateway_status;
};

struct Alert {
    std::string level;
    std::string message;
};

std::map<std::string, NodeConfig> NODES = {
    {"node1", {"Gateway", "localhost", "openclaw", true, false, true, "", 85}},
    {"node2", {"Node2", "100.82.198.122", "root", false, false, true, "/root/.ssh/id_ed25519_openclaw_admin", 85}},
    {"node3", {"Node3", "100.73.154.125", "root", false, false, true, "", 85}},
    {"node4", {"Redmi", "100.94.134.39", false, true, false, "", 85}},
    {"node5", {"Lenovo", "100.103.140.35", false, true, false, "", 85}}
};

std::string getCurrentTimestamp() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
    
    std::stringstream ss;
    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
    ss << "." << std::setfill('0') << std::setw(3) << ms.count();
    return ss.str();
}

void log(const std::string& message, const std::string& level = "INFO") {
    std::string timestamp = getCurrentTimestamp();
    std::string entry = "[" + timestamp + "] [" + level + "] " + message;
    std::cout << entry << std::endl;
    
    // Stelle sicher, dass das Verzeichnis existiert
    std::filesystem::create_directories(std::filesystem::path(LOG_FILE).parent_path());
    
    std::ofstream file(LOG_FILE, std::ios::app);
    if (file.is_open()) {
        file << entry << std::endl;
        file.close();
    }
}

bool checkPing(const std::string& host, int timeout = 5) {
    try {
        std::string cmd = "ping -c 1 -W " + std::to_string(timeout) + " " + host + " >/dev/null 2>&1";
        int result = std::system(cmd.c_str());
        return (result == 0);
    } catch (...) {
        return false;
    }
}

bool checkSSH(const NodeConfig& node_config) {
    if (!node_config.ssh_enabled) {
        return false;
    }
    
    std::string host = node_config.host;
    std::string user = node_config.user.empty() ? "root" : node_config.user;
    
    std::string cmd = "ssh -o ConnectTimeout=10 -o BatchMode=yes ";
    if (!node_config.ssh_key.empty()) {
        cmd += "-i " + node_config.ssh_key + " -o IdentitiesOnly=yes ";
    }
    cmd += user + "@" + host + " echo OK >/dev/null 2>&1";
    
    try {
        int result = std::system(cmd.c_str());
        return (result == 0);
    } catch (...) {
        return false;
    }
}

std::string execCommand(const std::string& cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

Metrics getNodeMetrics(const NodeConfig& node_config) {
    Metrics metrics;
    metrics.timestamp = getCurrentTimestamp();
    metrics.available = false;
    
    if (!node_config.ssh_enabled) {
        return metrics;
    }
    
    std::string host = node_config.host;
    std::string user = node_config.user.empty() ? "root" : node_config.user;
    
    // SSH-Command für alle Metriken
    std::string remote_cmd = R"(ssh -o ConnectTimeout=10 -o BatchMode=yes )";
    if (!node_config.ssh_key.empty()) {
        remote_cmd += "-i " + node_config.ssh_key + " -o IdentitiesOnly=yes ";
    }
    remote_cmd += user + "@" + host + R"( "
        # CPU
        echo \"CPU:\$(top -bn1 | grep \\\"Cpu(s)\\\" | awk '{print \$2}' | cut -d\\\"%\\\" -f1)\"
        
        # RAM
        echo \"RAM:\$(free | grep Mem | awk '{print (\$3/\$2) * 100.0}')\"
        
        # Disk
        echo \"DISK:\$(df -h / | tail -1 | awk '{print \$5}' | tr -d \\\"%\\\")\"
        
        # Load
        echo \"LOAD:\$(uptime | awk -F\\\"load average:\\\" \\\"{print \$2}\\\" | awk '{print \$1}' | tr -d \\\",\\\")\"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            printf \\\"GATEWAY:%s\\\\n\\\" \\\"\$(systemctl is-active openclaw-gateway 2>/dev/null || true)\\\"
        fi
    ")";
    
    try {
        std::string result = execCommand(remote_cmd);
        
        metrics.available = true;
        
        std::istringstream iss(result);
        std::string line;
        while (std::getline(iss, line)) {
            size_t pos = line.find(':');
            if (pos != std::string::npos) {
                std::string key = line.substr(0, pos);
                std::string value = line.substr(pos + 1);
                
                if (key == "CPU" && !value.empty()) {
                    metrics.cpu = std::stod(value);
                } else if (key == "RAM" && !value.empty()) {
                    metrics.ram = std::stod(value);
                } else if (key == "DISK" && !value.empty()) {
                    metrics.disk = std::stoi(value);
                } else if (key == "LOAD" && !value.empty()) {
                    metrics.load = std::stod(value);
                } else if (key == "GATEWAY") {
                    metrics.gateway_status = value;
                }
            }
        }
    } catch (const std::exception& e) {
        log("Error checking " + node_config.name + ": " + e.what(), "ERROR");
    }
    
    return metrics;
}

std::vector<Alert> checkAlerts(const std::string& node_id, const NodeConfig& node_config, const Metrics& metrics) {
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

void sendAlert(const Alert& alert) {
    try {
        std::string cmd = "python3 " + WORKSPACE + "/skills/channel-status-agent/scripts/channel_status.py --type alert --message \"" + alert.level + ": " + alert.message + "\" >/dev/null 2>&1";
        std::system(cmd.c_str());
        log("Alert sent: " + alert.message);
    } catch (const std::exception& e) {
        log("Failed to send alert: " + std::string(e.what()), "ERROR");
    }
}

int main(int argc, char* argv[]) {
    std::string node_arg = "all";
    std::string check_arg = "all";
    bool alert_flag = false;
    
    // Einfache Argumentverarbeitung
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
    
    std::vector<std::pair<std::string, NodeConfig>> nodes_to_check;
    
    // Nodes bestimmen
    if (node_arg == "all") {
        for (const auto& pair : NODES) {
            nodes_to_check.push_back(pair);
        }
    } else {
        auto it = NODES.find(node_arg);
        if (it != NODES.end()) {
            nodes_to_check.push_back(*it);
        } else {
            log("Unknown node: " + node_arg, "ERROR");
            return 1;
        }
    }
    
    // Health-Checks durchführen
    std::vector<Alert> all_alerts;
    
    for (const auto& pair : nodes_to_check) {
        const std::string& node_id = pair.first;
        const NodeConfig& node_config = pair.second;
        
        log("Checking " + node_config.name + " (" + node_id + ")");
        
        // Ping
        if (check_arg == "ping" || check_arg == "all") {
            if (node_config.host != "localhost") {
                bool ping_ok = checkPing(node_config.host);
                log("  Ping: " + std::string(ping_ok ? "OK" : "FAILED"));
            }
        }
        
        // SSH
        if (check_arg == "ssh" || check_arg == "all") {
            if (!node_config.ssh_enabled) {
                log("  SSH: SKIPPED (nicht konfiguriert)");
            } else {
                bool ssh_ok = checkSSH(node_config);
                log("  SSH: " + std::string(ssh_ok ? "OK" : "FAILED"));
            }
        }
        
        // Metriken
        if (check_arg == "metrics" || check_arg == "all") {
            Metrics metrics = getNodeMetrics(node_config);
            
            if (metrics.available) {
                log("  CPU: " + (metrics.cpu > 0 ? std::to_string(metrics.cpu) + "%" : "N/A"));
                log("  RAM: " + (metrics.ram > 0 ? std::to_string(metrics.ram) + "%" : "N/A"));
                log("  Disk: " + (metrics.disk > 0 ? std::to_string(metrics.disk) + "%" : "N/A"));
                log("  Load: " + (metrics.load > 0 ? std::to_string(metrics.load) : "N/A"));
            } else {
                log("  Metrics: UNAVAILABLE");
            }
            
            // Alerts prüfen
            std::vector<Alert> alerts = checkAlerts(node_id, node_config, metrics);
            all_alerts.insert(all_alerts.end(), alerts.begin(), alerts.end());
        }
    }
    
    // Alerts senden
    if (alert_flag && !all_alerts.empty()) {
        log("\nSending " + std::to_string(all_alerts.size()) + " alerts...");
        for (const auto& alert : all_alerts) {
            sendAlert(alert);
        }
    } else if (!all_alerts.empty()) {
        log("\n" + std::to_string(all_alerts.size()) + " alerts found (use --alert to send)");
    } else {
        log("\nPrüfung abgeschlossen; Details und nicht verfügbare Prüfungen siehe oben.");
    }
    
    return 0;
}
