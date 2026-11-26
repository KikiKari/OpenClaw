// abstraction-provenance: {"artifact_sha256": "7fb6f9901aed84243144acb19c5a55e53893e0aeb1f943b4d058a5172f3714b2", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "cpp"}
// server-maintenance.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
// auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
// auch in: workspace@local:scripts/server-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <sstream>
#include <iomanip>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <array>

class ServerMaintenance {
private:
    std::string LOG_FILE = "/var/log/server-maintenance.log";
    std::string DATE;
    std::string HOST;

    // Farben für Terminal
    std::string RED = "\033[0;31m";
    std::string GREEN = "\033[0;32m";
    std::string YELLOW = "\033[1;33m";
    std::string NC = "\033[0m";

    std::string getCurrentDateTime() {
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
        
        std::stringstream ss;
        ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
        return ss.str();
    }

    std::string exec(const char* cmd) {
        std::array<char, 128> buffer;
        std::string result;
        std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
        if (!pipe) {
            throw std::runtime_error("popen() failed!");
        }
        while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
            result += buffer.data();
        }
        return result;
    }

    void logMessage(const std::string& message) {
        std::cout << "[" << DATE << "] " << message << std::endl;
        
        std::ofstream logfile(LOG_FILE, std::ios::app);
        if (logfile.is_open()) {
            logfile << "[" << DATE << "] " << message << std::endl;
            logfile.close();
        }
    }

public:
    ServerMaintenance() {
        DATE = getCurrentDateTime();
        char hostname[1024];
        hostname[1023] = '\0';
        gethostname(hostname, 1023);
        HOST = std::string(hostname);
    }

    void runMaintenance() {
        logMessage("=== Server Maintenance Check ===");

        // 1. APT Update Check
        logMessage("Checking for updates...");
        try {
            std::string updateResult = exec("apt update -qq 2>&1 | tail -5");
            logMessage(updateResult);
            
            std::string upgradableResult = exec("apt list --upgradable 2>/dev/null | wc -l");
            int updates = std::stoi(upgradableResult);
            if (updates > 1) {
                logMessage("⚠️ " + std::to_string(updates) + " packages can be upgraded");
            }
        } catch (...) {
            logMessage("Error checking for updates");
        }

        // 2. RAM Check (8GB total)
        logMessage("Checking RAM usage...");
        try {
            int RAM_TOTAL = 8192;  // 8GB in MB
            std::string freeResult = exec("free -m | awk '/^Mem:/{print $3}'");
            freeResult.erase(std::remove(freeResult.begin(), freeResult.end(), '\n'), freeResult.end());
            int RAM_USED = std::stoi(freeResult);
            int RAM_PERCENT = (RAM_USED * 100) / RAM_TOTAL;
            logMessage("RAM: " + std::to_string(RAM_USED) + "MB / " + std::to_string(RAM_TOTAL) + "MB (" + std::to_string(RAM_PERCENT) + "%)");
            if (RAM_PERCENT > 90) {
                logMessage("🔴 WARNING: RAM usage > 90%!");
            } else if (RAM_PERCENT > 80) {
                logMessage("🟡 WARNING: RAM usage > 80%");
            }
        } catch (...) {
            logMessage("Error checking RAM usage");
        }

        // 3. Disk Space Check
        logMessage("Checking disk space...");
        try {
            std::string dfResult = exec("df -h / | tail -1 | awk '{print \"Disk: \" $3 \" / \" $2 \" (\" $5 \" used)\"}'");
            logMessage(dfResult);
            
            std::string percentResult = exec("df / | tail -1 | awk '{print $5}' | sed 's/%//'"); 
            percentResult.erase(std::remove(percentResult.begin(), percentResult.end(), '\n'), percentResult.end());
            int DISK_PERCENT = std::stoi(percentResult);
            if (DISK_PERCENT > 90) {
                logMessage("🔴 WARNING: Disk > 90%!");
            } else if (DISK_PERCENT > 80) {
                logMessage("🟡 WARNING: Disk > 80%");
            }
        } catch (...) {
            logMessage("Error checking disk space");
        }

        // 4. NTP Check
        logMessage("Checking NTP sync...");
        try {
            std::string ntpResult = exec("timedatectl status");
            if (ntpResult.find("NTP synchronized: yes") != std::string::npos) {
                logMessage("✅ NTP synchronized");
            } else {
                logMessage("⚠️ NTP not synchronized");
            }
        } catch (...) {
            logMessage("Error checking NTP sync");
        }

        // 5. OpenClaw Gateway Status
        logMessage("Checking OpenClaw Gateway...");
        try {
            int status = system("systemctl is-active --quiet openclaw-gateway");
            if (status == 0) {
                logMessage("✅ OpenClaw Gateway running");
            } else {
                logMessage("🔴 OpenClaw Gateway NOT running!");
                system("systemctl restart openclaw-gateway");
            }
        } catch (...) {
            logMessage("Error checking OpenClaw Gateway");
        }

        // 6. Load Average
        logMessage("Checking load average...");
        try {
            std::string loadResult = exec("uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//'");
            loadResult.erase(std::remove(loadResult.begin(), loadResult.end(), '\n'), loadResult.end());
            logMessage("Load Average: " + loadResult);
        } catch (...) {
            logMessage("Error checking load average");
        }

        logMessage("=== Maintenance Complete ===");
        logMessage("");
    }
};

int main() {
    ServerMaintenance maintenance;
    maintenance.runMaintenance();
    return 0;
}
