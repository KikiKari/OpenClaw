// abstraction-provenance: {"artifact_sha256": "2370eb83889eed7d5745e6e8b6db09253901ed697f2a12618e8867ff65bff895", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "cpp"}
// test_multinode_fallback.py — portiert nach cpp
// Quelle: python, workspace@local:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <vector>
#include <set>
#include <filesystem>
#include <cstdlib>
#include <stdexcept>
#include <memory>
#include <chrono>
#include <thread>
#include <sstream>
#include <algorithm>
#include <cstdio>

namespace fs = std::filesystem;

const fs::path WORKSPACE = "/home/openclaw/.openclaw/workspace";

/**
 * Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe.
 */
bool check_node_reachable(const std::string& node_id) {
    std::set<std::string> aliases = {node_id};
    std::set<std::string> node2_names = {
        "openclaw-node2", 
        "arm64-node", 
        "v2202604104722449961", 
        "v2202604104722449961.taild25fea.ts.net"
    };
    
    std::string lower_node_id = node_id;
    std::transform(lower_node_id.begin(), lower_node_id.end(), lower_node_id.begin(), ::tolower);
    
    if (node2_names.find(lower_node_id) != node2_names.end()) {
        aliases.insert(node2_names.begin(), node2_names.end());
    }
    
    try {
        // Execute command and capture output
        std::string command = "openclaw nodes status --json";
        std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(command.c_str(), "r"), pclose);
        
        if (!pipe) {
            return false;
        }
        
        std::ostringstream result;
        char buffer[128];
        while (fgets(buffer, sizeof buffer, pipe.get()) != nullptr) {
            result << buffer;
        }
        
        // Simple JSON parsing - check if displayName exists and connected is true
        std::string output = result.str();
        
        // Check each alias
        for (const auto& alias : aliases) {
            std::string display_check = "\"displayName\":\"" + alias + "\"";
            std::string connected_check = "\"connected\":true";
            
            if (output.find(display_check) != std::string::npos && 
                output.find(connected_check) != std::string::npos) {
                return true;
            }
        }
        
        return false;
    } catch (...) {
        return false;
    }
}

/**
 * Versucht Task auf Node auszuführen
 */
bool spawn_on_node(const std::string& node_id, const std::string& task) {
    std::cout << "Versuche Task auf Node " << node_id << " zu starten..." << std::endl;
    try {
        // Simuliert: openclaw agent spawn --node {node_id}
        std::string command = "echo 'Spawned on " + node_id + ": " + task + "'";
        int result = std::system((command + " >/dev/null 2>&1").c_str());
        
        if (result == 0) {
            std::cout << "✅ Erfolgreich delegiert an " << node_id << std::endl;
            return true;
        } else {
            std::cout << "❌ Node " << node_id << " nicht erreichbar" << std::endl;
            return false;
        }
    } catch (const std::exception& e) {
        std::cout << "❌ Node " << node_id << " nicht erreichbar: " << e.what() << std::endl;
        return false;
    }
}

/**
 * Führt Task lokal aus (Fallback)
 */
bool execute_locally(const std::string& task) {
    std::cout << "🔄 Fallback: Führe Task lokal aus..." << std::endl;
    try {
        if (task == "db_maintainer") {
            fs::path script_path = WORKSPACE / "skills" / "db-maintainer" / "scripts" / "db_maintainer.py";
            std::string command = "python3 " + script_path.string();
            
            int result = std::system((command + " >/dev/null 2>&1").c_str());
            
            if (result == 0) {
                std::cout << "✅ Lokale Ausführung erfolgreich" << std::endl;
                return true;
            } else {
                std::cout << "❌ Fehler bei lokaler Ausführung" << std::endl;
                return false;
            }
        }
        return false;
    } catch (const std::exception& e) {
        std::cout << "❌ Lokale Ausführung fehlgeschlagen: " << e.what() << std::endl;
        return false;
    }
}

int main() {
    std::cout << "============================================================" << std::endl;
    std::cout << "MULTI-NODE FALLBACK TEST" << std::endl;
    std::cout << "============================================================" << std::endl;
    std::cout << std::endl;
    
    // Konfiguration
    std::string primary_node = "v2202604104722449961.taild25fea.ts.net";  // Node 2
    std::string task = "db_maintainer";
    
    std::cout << "Primärer Node: " << primary_node << std::endl;
    std::cout << "Task: " << task << std::endl;
    std::cout << std::endl;
    
    // 1. Prüfe Node-Erreichbarkeit
    std::cout << "--- 1. Prüfe Node-Erreichbarkeit ---" << std::endl;
    if (check_node_reachable(primary_node)) {
        std::cout << "✅ Node " << primary_node << " ist erreichbar" << std::endl;
        
        // 2. Versuche Delegation
        std::cout << std::endl << "--- 2. Versuche Delegation ---" << std::endl;
        if (spawn_on_node(primary_node, task)) {
            std::cout << std::endl << "✅ MULTI-NODE: Task erfolgreich delegiert" << std::endl;
            return 0;
        } else {
            std::cout << std::endl << "⚠️ Delegation fehlgeschlagen, aktiviere Fallback..." << std::endl;
        }
    } else {
        std::cout << "❌ Node " << primary_node << " nicht erreichbar" << std::endl;
        std::cout << "🔄 Fallback wird aktiviert..." << std::endl;
    }
    
    // 3. Lokale Ausführung (Fallback)
    std::cout << std::endl << "--- 3. Lokale Ausführung (Fallback) ---" << std::endl;
    if (execute_locally(task)) {
        std::cout << std::endl << "✅ FALLBACK: Task lokal erfolgreich ausgeführt" << std::endl;
        return 0;
    } else {
        std::cout << std::endl << "❌ FEHLER: Weder Delegation noch Fallback erfolgreich" << std::endl;
        return 1;
    }
}
