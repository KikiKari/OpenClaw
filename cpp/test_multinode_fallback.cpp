// abstraction-provenance: {"artifact_sha256": "d02c33456f73e6d94be14bd1efeecd74820342180d411ac3f41902ad1350b94b", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "cpp"}
// test_multinode_fallback.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
// auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <filesystem>
#include <cstdlib>
#include <stdexcept>
#include <chrono>
#include <thread>

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

namespace fs = std::filesystem;

const fs::path WORKSPACE = "/home/openclaw/.openclaw/workspace";

bool check_node_reachable(const std::string& node_id) {
    // Prüft ob Node erreichbar ist
    try {
        // Versuche Node-Status abzufragen
        std::string command = "openclaw nodes status";
        FILE* pipe = popen(command.c_str(), "r");
        if (!pipe) return false;

        char buffer[128];
        std::string result = "";
        while (fgets(buffer, sizeof buffer, pipe) != nullptr) {
            result += buffer;
        }
        pclose(pipe);

        return result.find(node_id) != std::string::npos && 
               result.find("connected") != std::string::npos;
    } catch (...) {
        return false;
    }
}

bool spawn_on_node(const std::string& node_id, const std::string& task) {
    // Versucht Task auf Node auszuführen
    std::cout << "Versuche Task auf Node " << node_id << " zu starten..." << std::endl;
    try {
        // Simuliert: openclaw agent spawn --node {node_id}
        std::string command = "echo 'Spawned on " + node_id + ": " + task + "'";
        int result = std::system(command.c_str());
        
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

bool execute_locally(const std::string& task) {
    // Führt Task lokal aus (Fallback)
    std::cout << "🔄 Fallback: Führe Task lokal aus..." << std::endl;
    try {
        if (task == "db_maintainer") {
            fs::path script_path = WORKSPACE / "skills" / "db-maintainer" / "scripts" / "db_maintainer.py";
            std::string command = "python3 " + script_path.string();
            
            int result = std::system(command.c_str());
            
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
    std::string primary_node = "v2202603104722445775";  // Node 2
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
