// abstraction-provenance: {"artifact_sha256": "5ca4b286a34a5592421111d70e69e3325f19befb3cc4c1dea49dbc043f078e6b", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "c"}
// setup-xvfb-node2.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// auch in: workspace@local:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main() {
    printf("=== Xvfb + Chromium Setup für Node 2 ===\n");

    // Update & Install
    int result = system("sudo apt-get update");
    if (result != 0) {
        fprintf(stderr, "Fehler beim Ausführen von apt-get update\n");
        return 1;
    }

    result = system("sudo apt-get install -y xvfb chromium-browser chromium-chromedriver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils");
    if (result != 0) {
        fprintf(stderr, "Fehler beim Installieren der Pakete\n");
        return 1;
    }

    // Xvfb Systemd Service erstellen
    FILE *file = fopen("/etc/systemd/system/xvfb.service", "w");
    if (file == NULL) {
        perror("Fehler beim Öffnen der Service-Datei");
        return 1;
    }

    const char *service_content = 
"[Unit]\n"
"Description=X Virtual Framebuffer\n"
"After=network.target\n"
"\n"
"[Service]\n"
"Type=simple\n"
"User=openclaw\n"
"ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset\n"
"Restart=always\n"
"RestartSec=5\n"
"\n"
"[Install]\n"
"WantedBy=multi-user.target\n";

    fputs(service_content, file);
    fclose(file);

    // Service aktivieren
    result = system("sudo systemctl daemon-reload");
    if (result != 0) {
        fprintf(stderr, "Fehler beim Neuladen des Systemd-Daemons\n");
        return 1;
    }

    result = system("sudo systemctl enable xvfb");
    if (result != 0) {
        fprintf(stderr, "Fehler beim Aktivieren des Xvfb-Services\n");
        return 1;
    }

    result = system("sudo systemctl start xvfb");
    if (result != 0) {
        fprintf(stderr, "Fehler beim Starten des Xvfb-Services\n");
        return 1;
    }

    printf("=== Xvfb läuft auf DISPLAY :99 ===\n");
    printf("Chromium Version:\n");
    
    result = system("chromium-browser --version");
    if (result != 0) {
        printf("Chromium nicht gefunden\n");
    }

    printf("=== Setup abgeschlossen ===\n");
    return 0;
}
