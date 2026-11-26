// abstraction-provenance: {"artifact_sha256": "91eaf9e43024153783e1052b344587fce83e750f33db833c8997af1d0ab6d092", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "cpp"}
// channel_status.py — portiert nach cpp
// Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <map>
#include <set>
#include <vector>
#include <fstream>
#include <sstream>
#include <chrono>
#include <filesystem>
#include <nlohmann/json.hpp>
#include <cstdio>
#include <memory>

using json = nlohmann::json;
namespace fs = std::filesystem;

// Konfiguration
const fs::path WORKSPACE = "/home/openclaw/.openclaw/workspace";
const fs::path LOGS_DB = WORKSPACE / "db/logs.db";
const fs::path CONFIG_FILE = WORKSPACE / "config/channel-status.json";
const fs::path LOG_FILE = WORKSPACE / "logs/channel-status.log";

void log(const std::string& message, const std::string& level = "INFO") {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
    
    std::tm tm{};
    localtime_r(&time_t, &tm);
    
    char buffer[100];
    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", &tm);
    
    std::ostringstream timestamp;
    timestamp << buffer << "." << std::setfill('0') << std::setw(3) << ms.count();
    
    std::string entry = "[" + timestamp.str() + "] [" + level + "] " + message;
    std::cout << entry << std::endl;
    
    // Ensure directory exists
    fs::create_directories(LOG_FILE.parent_path());
    
    std::ofstream file(LOG_FILE, std::ios::app);
    if (file.is_open()) {
        file << entry << std::endl;
    }
}

const std::map<std::string, std::set<std::string>> NODE_NAMES = {
    {"node2", {"openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"}},
    {"node3", {"openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"}},
    {"node4", {"openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"}},
    {"node5", {"openclaw-node5", "lenovo-node7", "lenovo-node7.taild25fea.ts.net", "100.103.140.35"}}
};

std::string exec_command(const std::vector<std::string>& cmd) {
    std::string command_str;
    for (const auto& part : cmd) {
        command_str += part + " ";
    }
    
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(command_str.c_str(), "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    
    std::string result;
    char buffer[128];
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        result += buffer;
    }
    
    return result;
}

std::optional<std::map<std::string, bool>> fetch_node_status() {
    try {
        std::vector<std::string> cmd = {"openclaw", "nodes", "status", "--json"};
        std::string output = exec_command(cmd);
        
        json payload = json::parse(output);
        
        if (!payload.is_object() || !payload.contains("nodes") || !payload["nodes"].is_array()) {
            return std::nullopt;
        }
        
        std::map<std::string, bool> states;
        for (const auto& pair : NODE_NAMES) {
            states[pair.first] = false;
        }
        states["node1"] = true; // successful Gateway status request
        
        for (const auto& item : payload["nodes"]) {
            if (!item.is_object()) continue;
            
            std::set<std::string> names;
            for (const auto& key : {"displayName", "nodeId", "remoteIp"}) {
                if (item.contains(key)) {
                    std::string val = item[key].get<std::string>();
                    std::transform(val.begin(), val.end(), val.begin(), ::tolower);
                    names.insert(val);
                }
            }
            
            for (const auto& node_pair : NODE_NAMES) {
                const std::string& node = node_pair.first;
                const std::set<std::string>& aliases = node_pair.second;
                
                for (const auto& alias : aliases) {
                    if (names.find(alias) != names.end() && item.value("connected", false) == true) {
                        states[node] = true;
                        break;
                    }
                }
            }
        }
        
        return states;
    } catch (...) {
        return std::nullopt;
    }
}

std::string get_current_time_iso() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    
    std::tm tm{};
    localtime_r(&time_t, &tm);
    
    char buffer[100];
    strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &tm);
    return std::string(buffer);
}

std::string exec_simple(const std::string& cmd) {
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) return "";
    
    std::string result;
    char buffer[128];
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        result += buffer;
    }
    
    return result;
}

json get_system_status() {
    json status;
    status["timestamp"] = get_current_time_iso();
    status["nodes"] = json::object();
    status["agents"] = json::object();
    status["system"] = json::object();
    
    auto states = fetch_node_status();
    std::map<std::string, std::string> names = {
        {"node1", "Gateway"}, {"node2", "Node2"}, {"node3", "Node3"}, 
        {"node4", "Redmi"}, {"node5", "Lenovo"}
    };
    
    for (const auto& pair : names) {
        const std::string& node = pair.first;
        const std::string& name = pair.second;
        
        json node_info;
        node_info["name"] = name;
        
        if (!states.has_value()) {
            node_info["status"] = "unknown";
        } else {
            node_info["status"] = states.value().at(node) ? "online" : "offline";
        }
        
        status["nodes"][node] = node_info;
    }
    
    try {
        std::string crontab_output = exec_simple("crontab -l 2>/dev/null");
        int cron_lines = 0;
        std::istringstream iss(crontab_output);
        std::string line;
        while (std::getline(iss, line)) {
            if (line.empty() || line[0] == '#') continue;
            cron_lines++;
        }
        status["agents"]["active_crons"] = cron_lines;
    } catch (...) {
        status["agents"]["active_crons"] = "unknown";
    }
    
    try {
        std::string df_output = exec_simple("df -h /");
        std::istringstream iss(df_output);
        std::string line;
        std::getline(iss, line); // Skip header
        if (std::getline(iss, line)) {
            std::istringstream line_iss(line);
            std::string part;
            std::vector<std::string> parts;
            while (line_iss >> part) {
                parts.push_back(part);
            }
            if (parts.size() >= 5) {
                status["system"]["disk_used"] = parts[4];
            }
        }
        
        std::string free_output = exec_simple("free -h");
        std::istringstream free_iss(free_output);
        std::string free_line;
        while (std::getline(free_iss, free_line)) {
            if (free_line.find("Mem:") != std::string::npos) {
                std::istringstream mem_iss(free_line);
                std::string mem_part;
                std::vector<std::string> mem_parts;
                while (mem_iss >> mem_part) {
                    mem_parts.push_back(mem_part);
                }
                if (mem_parts.size() >= 3) {
                    status["system"]["ram_total"] = mem_parts[1];
                    status["system"]["ram_used"] = mem_parts[2];
                }
                break;
            }
        }
    } catch (...) {
        // Ignore errors
    }
    
    return status;
}

std::string format_daily_status(const json& status) {
    int online = 0;
    for (const auto& element : status["nodes"]) {
        if (element["status"] == "online") {
            online++;
        }
    }
    
    auto now = std::time(nullptr);
    char time_buffer[100];
    std::tm tm{};
    localtime_r(&now, &tm);
    strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%d %H:%M", &tm);
    
    std::string message = "📊 **Täglicher Status-Report**\n🗓️ ";
    message += std::string(time_buffer) + "\n\n**🖥️ Nodes (" + std::to_string(online) + "/" + std::to_string(status["nodes"].size()) + " online):**\n";
    
    std::map<std::string, std::string> node_names = {
        {"node1", "Gateway"}, {"node2", "Node2"}, {"node3", "Node3"}, 
        {"node4", "Redmi"}, {"node5", "Lenovo"}
    };
    
    for (const auto& pair : node_names) {
        const std::string& node_id = pair.first;
        const std::string& name = pair.second;
        
        if (status["nodes"].contains(node_id)) {
            std::string node_status = status["nodes"][node_id]["status"];
            std::string emoji = "🟡";
            if (node_status == "online") emoji = "🟢";
            else if (node_status == "offline") emoji = "🔴";
            
            message += emoji + " " + name + ": " + node_status + "\n";
        }
    }
    
    message += "\n**🤖 Agents:**\n";
    message += "Aktive Cron-Jobs: " + status["agents"]["active_crons"].get<std::string>() + "\n";
    
    if (status["system"].contains("disk_used")) {
        message += "\n**💾 System:**\n";
        message += "Disk: " + status["system"]["disk_used"].get<std::string>() + " belegt\n";
        message += "RAM: " + status["system"]["ram_used"].get<std::string>() + " / " + status["system"]["ram_total"].get<std::string>() + "\n";
    }
    
    return message;
}

std::string format_weekly_status(const json& status) {
    auto now = std::time(nullptr);
    char week_buffer[10];
    char year_buffer[10];
    std::tm tm{};
    localtime_r(&now, &tm);
    strftime(week_buffer, sizeof(week_buffer), "%V", &tm);
    strftime(year_buffer, sizeof(year_buffer), "%Y", &tm);
    
    std::string message = "📈 **Wöchentlicher Report**\n📅 Woche ";
    message += std::string(week_buffer) + " - " + std::string(year_buffer) + "\n\n**Nodes:**\n";
    
    std::map<std::string, std::string> node_names = {
        {"node1", "Gateway"}, {"node2", "Node2"}, {"node3", "Node3"}, 
        {"node4", "Redmi"}, {"node5", "Lenovo"}
    };
    
    for (const auto& pair : node_names) {
        const std::string& node_id = pair.first;
        const std::string& name = pair.second;
        
        if (status["nodes"].contains(node_id)) {
            std::string node_status = status["nodes"][node_id]["status"];
            message += "- " + name + ": " + node_status + "\n";
        }
    }
    
    return message;
}

bool send_to_channel(const std::string& message, const std::string& channel_type = "telegram", const std::string& channel_id = "-1002381931352") {
    if (channel_type == "telegram") {
        std::string cmd = "openclaw message send --target " + channel_id + " --message \"" + message + "\"";
        int result = std::system(cmd.c_str());
        if (result == 0) {
            log("Message sent to " + channel_type + " " + channel_id);
            return true;
        } else {
            log("Failed to send message", "ERROR");
            return false;
        }
    } else {
        log("Channel type " + channel_type + " not implemented", "WARN");
        return false;
    }
}

int main(int argc, char* argv[]) {
    std::string type, message, channel = "-1002381931352";
    bool dry_run = false;
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--type" && i + 1 < argc) {
            type = argv[++i];
        } else if (arg == "--message" && i + 1 < argc) {
            message = argv[++i];
        } else if (arg == "--channel" && i + 1 < argc) {
            channel = argv[++i];
        } else if (arg == "--dry-run") {
            dry_run = true;
        }
    }
    
    if (type.empty()) {
        std::cerr << "Error: --type is required" << std::endl;
        return 1;
    }
    
    log("Starting " + type + " status update");
    
    auto status = get_system_status();
    
    std::string formatted_message;
    if (type == "daily") {
        formatted_message = format_daily_status(status);
    } else if (type == "weekly") {
        formatted_message = format_weekly_status(status);
    } else if (type == "alert") {
        formatted_message = "🚨 **ALERT**\n" + (message.empty() ? "Manual alert" : message);
    }
    
    if (dry_run) {
        std::cout << "\n--- DRY RUN ---" << std::endl;
        std::cout << formatted_message << std::endl;
        std::cout << "--- END ---" << std::endl;
    } else {
        send_to_channel(formatted_message, "telegram", channel);
    }
    
    log("Status update completed");
    
    return 0;
}
