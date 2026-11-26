// abstraction-provenance: {"artifact_sha256": "2a3438d4e17b2eb0ee8981922aae0d3145c761c8a7a068a11a66db84ee38baee", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "cpp"}
// openclaw-node-autostart-termux.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <filesystem>
#include <cstdlib>
#include <ctime>
#include <thread>
#include <chrono>
#include <sstream>

// OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
// Installiert nach: ~/.termux/boot/openclaw-node.sh
// Getestet mit: Termux + Android + OpenClaw

const std::string SESSION = "openclaw-node";
const std::string LOGFILE = std::getenv("HOME") + std::string("/.openclaw/node.log");
const std::string GATEWAY = "10.10.0.1";
const std::string PORT = "18789";

void log_message(const std::string& message) {
    std::ofstream logfile(LOGFILE, std::ios_base::app);
    if (logfile.is_open()) {
        std::time_t now = std::time(nullptr);
        char buffer[100];
        std::strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", std::localtime(&now));
        logfile << "[" << buffer << "] " << message << std::endl;
    }
}

bool session_exists() {
    std::string command = "tmux has-session -t " + SESSION + " 2>/dev/null";
    return std::system(command.c_str()) == 0;
}

bool ping_gateway(const std::string& gateway) {
    std::string command = "ping -c 1 -W 3 " + gateway + " >/dev/null 2>&1";
    return std::system(command.c_str()) == 0;
}

void run_openclaw_node() {
    while (true) {
        log_message("Starting OpenClaw Node Mode...");
        
        // Prüfe WireGuard Verbindung
        if (!ping_gateway(GATEWAY)) {
            log_message("FEHLER: WireGuard Gateway " + GATEWAY + " nicht erreichbar!");
            log_message("Warte 10 Sekunden...");
            std::this_thread::sleep_for(std::chrono::seconds(10));
            continue;
        }
        
        // OpenClaw Node Mode starten
        std::string command = "openclaw node run --host " + GATEWAY + " --port " + PORT + " 2>&1 | tee -a " + LOGFILE;
        std::system(command.c_str());
        
        // Wenn der Prozess endet, warte und neustarten
        log_message("OpenClaw beendet. Neustart in 5 Sekunden...");
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }
}

int main() {
    // Log-Verzeichnis erstellen
    std::filesystem::create_directories(std::getenv("HOME") + std::string("/.openclaw"));
    
    // Prüfen ob tmux Session bereits läuft
    if (session_exists()) {
        log_message("OpenClaw Node läuft bereits in tmux Session '" + SESSION + "'");
        return 0;
    }
    
    // Neue tmux Session erstellen und OpenClaw starten
    std::string tmux_command = "tmux new-session -d -s " + SESSION + " -n node";
    std::system(tmux_command.c_str());
    
    // Starte den OpenClaw Node Prozess in einem separaten Thread
    std::thread openclaw_thread(run_openclaw_node);
    openclaw_thread.detach();
    
    log_message("OpenClaw Node Autostart aktiviert (tmux Session: " + SESSION + ")");
    
    // Optional: tmux attach Hinweis falls interaktiv gestartet
    if (isatty(STDOUT_FILENO)) {
        std::cout << "OpenClaw Node Mode gestartet in tmux Session '" << SESSION << "'" << std::endl;
        std::cout << "Zum Anschauen: tmux attach -t " << SESSION << std::endl;
        std::cout << "Log-Datei: " << LOGFILE << std::endl;
    }
    
    return 0;
}
