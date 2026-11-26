// abstraction-provenance: {"artifact_sha256": "63c6da76d1f29140a567027e7571dfe7b6582272afcb78a1433b58e6b4a58c1c", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "cpp"}
// setup-xvfb-node3.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// auch in: workspace@local:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

using namespace std;

// Funktion zum Ausführen von Shell-Befehlen
int executeCommand(const char* command) {
    cout << "Führe aus: " << command << endl;
    return system(command);
}

// Funktion zum Schreiben einer Datei mit Inhalt
bool writeFile(const char* path, const char* content) {
    FILE* file = fopen(path, "w");
    if (!file) {
        perror("Fehler beim Öffnen der Datei");
        return false;
    }
    
    fputs(content, file);
    fclose(file);
    return true;
}

int main() {
    cout << "=== Xvfb + Chromium Setup für Node 3 ===" << endl;
    cout << "=== Entferne altes VNC-Setup ===" << endl;

    // Altes VNC stoppen & entfernen (falls vorhanden)
    executeCommand("sudo systemctl stop vncserver@* 2>/dev/null || true");
    executeCommand("sudo systemctl disable vncserver@* 2>/dev/null || true");
    executeCommand("sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null || true");
    executeCommand("sudo rm -rf ~/.vnc /tmp/.X11-unix/X* 2>/dev/null || true");

    cout << "=== Installiere Xvfb + Chromium ===" << endl;

    // Update & Install
    executeCommand("sudo apt-get update");
    executeCommand("sudo apt-get install -y xvfb chromium chromium-driver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils");

    // Xvfb Systemd Service erstellen
    const char* serviceContent = 
R"([Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
)";

    if (!writeFile("/etc/systemd/system/xvfb.service", serviceContent)) {
        cerr << "Fehler beim Erstellen der Service-Datei" << endl;
        return 1;
    }

    // Service aktivieren
    executeCommand("sudo systemctl daemon-reload");
    executeCommand("sudo systemctl enable xvfb");
    executeCommand("sudo systemctl start xvfb");

    cout << "=== Xvfb läuft auf DISPLAY :99 ===" << endl;
    cout << "Chromium Version:" << endl;
    if (executeCommand("chromium --version") != 0) {
        cout << "Chromium nicht gefunden" << endl;
    }

    cout << "=== Setup abgeschlossen ===" << endl;
    cout << "=== Altes VNC-Setup wurde entfernt ===" << endl;

    return 0;
}
