// abstraction-provenance: {"artifact_sha256": "9b7c101c7e5646adbd423dcd84c02c10bca0f7a8dc69f10ff1ab41ae5feef7b1", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "cpp"}
// openclaw-maintenance.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>
#include <filesystem>
#include <stdexcept>

namespace fs = std::filesystem;

// Helper function to execute a command and return its exit code
int executeCommand(const std::string& cmd) {
    std::cout << "Executing: " << cmd << std::endl;
    int result = std::system(cmd.c_str());
    if (result != 0) {
        std::cerr << "Command failed with exit code: " << result << std::endl;
    }
    return result;
}

// Helper function to get environment variable or default value
std::string getEnvOrDefault(const std::string& var, const std::string& defaultValue) {
    const char* val = std::getenv(var.c_str());
    return val ? std::string(val) : defaultValue;
}

int main() {
    try {
        // Determine OPENCLAW_BIN path
        std::string openclawBin = getEnvOrDefault("OPENCLAW_BIN", 
            (fs::path(std::getenv("HOME")) / ".local/bin/openclaw").string());

        // Check if the binary exists and is executable
        if (!fs::exists(openclawBin) || !fs::is_regular_file(openclawBin)) {
            std::cerr << "ERROR: OpenClaw binary not found: " << openclawBin << std::endl;
            return 1;
        }

        // Display version information
        std::cout << "Using OpenClaw: ";
        if (executeCommand(openclawBin + " --version") != 0) {
            std::cerr << "Failed to retrieve OpenClaw version." << std::endl;
            return 1;
        }

        // === 1. Service-/Config-Drift ===
        if (executeCommand(openclawBin + " doctor") != 0) {
            std::cerr << "Step 1 (doctor) failed." << std::endl;
            return 1;
        }

        // === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
        if (executeCommand(openclawBin + " plugins registry --refresh") != 0) {
            std::cerr << "Plugin registry refresh failed." << std::endl;
            return 1;
        }

        std::string runPluginUpdate = getEnvOrDefault("RUN_PLUGIN_UPDATE", "0");
        if (runPluginUpdate == "1") {
            if (executeCommand(openclawBin + " plugins update --all") != 0) {
                std::cerr << "Plugin update failed." << std::endl;
                return 1;
            }
        } else {
            std::cout << "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable." << std::endl;
        }

        // === 3. Tasks ===
        if (executeCommand(openclawBin + " tasks maintenance --apply") != 0) {
            std::cerr << "Tasks maintenance failed." << std::endl;
            return 1;
        }

        // === 4. Sessions – alle Agents auf einmal ===
        if (executeCommand(openclawBin + " sessions cleanup --enforce --all-agents") != 0) {
            std::cerr << "Sessions cleanup failed." << std::endl;
            return 1;
        }

        // === 5. Memory – status/index decken alle Agents ab ===
        if (executeCommand(openclawBin + " memory status --deep --fix") != 0) {
            std::cerr << "Memory status check failed." << std::endl;
            return 1;
        }

        if (executeCommand(openclawBin + " memory index --force") != 0) {
            std::cerr << "Memory indexing failed." << std::endl;
            return 1;
        }

        // === 6. Memory promote – MUSS pro Agent ===
        std::vector<std::string> agents = {"main", "knecht", "docs", "ops-hub", "cron"};
        for (const auto& agent : agents) {
            std::string cmd = openclawBin + " memory promote --apply --agent " + agent;
            if (executeCommand(cmd) != 0) {
                std::cerr << "Memory promotion for agent '" << agent << "' failed." << std::endl;
                return 1;
            }
        }

        // === 7. Secrets ===
        if (executeCommand(openclawBin + " secrets reload") != 0) {
            std::cerr << "Secrets reload failed." << std::endl;
            return 1;
        }

        std::cout << "All maintenance steps completed successfully." << std::endl;
        return 0;

    } catch (const std::exception& e) {
        std::cerr << "Exception occurred: " << e.what() << std::endl;
        return 1;
    }
}
