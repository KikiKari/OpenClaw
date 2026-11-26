// abstraction-provenance: {"artifact_sha256": "2c9b4af5eb02e5c348413da89f8e76bec9e7c3c587aae51fe177287476d81c16", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "cpp"}
// serve_compare_transfer.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
// auch in: workspace@local:scripts/serve_compare_transfer.sh
// auch in: workspace@local:vscode/compare/transfer/serve_compare_transfer.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <vector>
#include <string>
#include <filesystem>
#include <algorithm>
#include <cstdlib>
#include <unistd.h>
#include <sys/wait.h>

namespace fs = std::filesystem;

const std::string COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
const std::string TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
const std::string HOST_IP = "152.53.145.65";
const std::string PORT = "80";

std::string get_self_path() {
    char buffer[1024];
    ssize_t len = readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
    if (len != -1) {
        buffer[len] = '\0';
        return std::string(buffer);
    }
    return "";
}

std::vector<std::string> find_files(const std::string& directory, const std::string& self_path) {
    std::vector<std::string> files;
    
    for (const auto& entry : fs::directory_iterator(directory)) {
        if (entry.is_regular_file() && entry.path().string() != self_path) {
            files.push_back(entry.path().string());
        }
    }
    
    std::sort(files.begin(), files.end());
    return files;
}

int main() {
    std::string self_path = get_self_path();
    std::vector<std::string> files = find_files(COMPARE_DIR, self_path);
    
    if (files.empty()) {
        std::cout << "Keine Dateien in " << COMPARE_DIR << " gefunden." << std::endl;
        return 1;
    }
    
    std::cout << std::endl;
    std::cout << "Bereitgestellte Dateien aus " << COMPARE_DIR << ":" << std::endl;
    for (const auto& src : files) {
        std::cout << "- " << fs::path(src).filename().string() << std::endl;
    }
    
    std::cout << std::endl;
    std::cout << "Copy/Paste auf anderem Gateway (Download nach " << TRANSFER_DIR << "):" << std::endl;
    for (const auto& src : files) {
        std::string file = fs::path(src).filename().string();
        std::cout << "curl -fL --retry 3 --connect-timeout 10 -o " 
                  << TRANSFER_DIR << "/" << file 
                  << " http://" << HOST_IP << ":" << PORT << "/" << file << std::endl;
    }
    
    std::cout << std::endl;
    std::cout << "Server auf Port " << PORT << " aktiv. Beenden mit STRG+C." << std::endl;
    std::cout << std::endl;
    
    // Wechsel ins Verzeichnis und starte Python HTTP Server
    if (chdir(COMPARE_DIR.c_str()) != 0) {
        std::cerr << "Konnte nicht ins Verzeichnis " << COMPARE_DIR << " wechseln." << std::endl;
        return 1;
    }
    
    // Starte Python HTTP Server
    execl("/usr/bin/python3", "python3", "-m", "http.server", PORT.c_str(), "--bind", "0.0.0.0", nullptr);
    
    // Falls execl fehlschlägt
    std::cerr << "Fehler beim Starten des HTTP Servers." << std::endl;
    return 1;
}
