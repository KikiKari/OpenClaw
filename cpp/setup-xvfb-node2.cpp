// abstraction-provenance: {"artifact_sha256": "718b44337612a8e9271bb2f74a68900b4282a7f77aa91fd0c4f39bc82b1a31c5", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "cpp"}
// setup-xvfb-node2.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// auch in: workspace@local:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <cstdlib>
#include <unistd.h>
#include <sys/wait.h>

using namespace std;

int main() {
    // Xvfb Setup für Node 2 (Netcup VPS)
    // Erstellt: 2026-04-09

    cout << "=== Xvfb + Chromium Setup für Node 2 ===" << endl;

    // Update & Install
    int result = system("sudo apt-get update");
    if (result != 0) {
        cerr << "Fehler beim Update" << endl;
        return 1;
    }

    const char* packages[] = {
        "xvfb",
        "chromium-browser",
        "chromium-chromedriver",
        "fonts-liberation",
        "libappindicator3-1",
        "libasound2",
        "libatk-bridge2.0-0",
        "libatk1.0-0",
        "libcups2",
        "libgtk-3-0",
        "libnspr4",
        "libnss3",
        "libxss1",
        "xdg-utils",
        nullptr
    };

    string install_cmd = "sudo apt-get install -y";
    for (int i = 0; packages[i] != nullptr; ++i) {
        install_cmd += " ";
        install_cmd += packages[i];
    }

    result = system(install_cmd.c_str());
    if (result != 0) {
        cerr << "Fehler bei der Installation der Pakete" << endl;
        return 1;
    }

    // Xvfb Systemd Service erstellen
    const char* service_content = 
R"([Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=openclaw
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
)";

    FILE* file = fopen("/etc/systemd/system/xvfb.service", "w");
    if (!file) {
        cerr << "Fehler beim Öffnen der Service-Datei" << endl;
        return 1;
    }
    
    fputs(service_content, file);
    fclose(file);

    // Service aktivieren
    system("sudo systemctl daemon-reload");
    system("sudo systemctl enable xvfb");
    system("sudo systemctl start xvfb");

    cout << "=== Xvfb läuft auf DISPLAY :99 ===" << endl;
    cout << "Chromium Version:" << endl;
    
    result = system("chromium-browser --version");
    if (result != 0) {
        cout << "Chromium nicht gefunden" << endl;
    }

    cout << "=== Setup abgeschlossen ===" << endl;

    return 0;
}
