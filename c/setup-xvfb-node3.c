// abstraction-provenance: {"artifact_sha256": "4feab410e2a92a5439ec89894b77aa9770f195d461c05943f70f2bb3cd720750", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "c"}
// setup-xvfb-node3.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// auch in: workspace@local:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

// Funktion zur Ausführung von Shell-Befehlen
int execute_command(const char *command) {
    int result = system(command);
    if (result == -1) {
        perror("Fehler beim Ausführen des Befehls");
        return -1;
    }
    return WEXITSTATUS(result);
}

// Funktion zum Erstellen einer Datei mit Inhalt
int create_file_with_content(const char *filepath, const char *content) {
    FILE *file = fopen(filepath, "w");
    if (!file) {
        perror("Fehler beim Öffnen der Datei");
        return -1;
    }
    
    fprintf(file, "%s", content);
    fclose(file);
    return 0;
}

// Funktion zum rekursiven Löschen eines Verzeichnisses
int remove_directory(const char *path) {
    // Hinweis: Dies ist eine vereinfachte Implementierung
    // Für Produktivsysteme sollte eine robustere Lösung verwendet werden
    char command[512];
    snprintf(command, sizeof(command), "rm -rf %s", path);
    return system(command);
}

int main() {
    printf("=== Xvfb + Chromium Setup für Node 3 ===\n");
    printf("=== Entferne altes VNC-Setup ===\n");

    // Altes VNC stoppen & entfernen (falls vorhanden)
    printf("Stoppe alte VNC-Dienste...\n");
    system("sudo systemctl stop vncserver@* 2>/dev/null || true");
    
    printf("Deaktiviere alte VNC-Dienste...\n");
    system("sudo systemctl disable vncserver@* 2>/dev/null || true");
    
    printf("Entferne alte VNC-Pakete...\n");
    system("sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null || true");
    
    printf("Lösche alte VNC-Konfigurationsdateien...\n");
    system("sudo rm -rf ~/.vnc /tmp/.X11-unix/X* 2>/dev/null || true");

    printf("=== Installiere Xvfb + Chromium ===\n");

    // Update & Install
    printf("Aktualisiere Paketliste...\n");
    if (execute_command("sudo apt-get update") != 0) {
        fprintf(stderr, "Fehler beim Aktualisieren der Paketliste\n");
        return 1;
    }

    printf("Installiere benötigte Pakete...\n");
    if (execute_command("sudo apt-get install -y xvfb chromium chromium-driver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils") != 0) {
        fprintf(stderr, "Fehler beim Installieren der Pakete\n");
        return 1;
    }

    // Xvfb Systemd Service erstellen
    const char *service_content = 
"[Unit]\n"
"Description=X Virtual Framebuffer\n"
"After=network.target\n"
"\n"
"[Service]\n"
"Type=simple\n"
"User=root\n"
"ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset\n"
"Restart=always\n"
"RestartSec=5\n"
"\n"
"[Install]\n"
"WantedBy=multi-user.target\n";

    printf("Erstelle Xvfb systemd-Service...\n");
    if (create_file_with_content("/etc/systemd/system/xvfb.service", service_content) != 0) {
        fprintf(stderr, "Fehler beim Erstellen der Service-Datei\n");
        return 1;
    }

    // Service aktivieren
    printf("Lade systemd-Konfiguration neu...\n");
    if (execute_command("sudo systemctl daemon-reload") != 0) {
        fprintf(stderr, "Fehler beim Neuladen der systemd-Konfiguration\n");
        return 1;
    }

    printf("Aktiviere Xvfb-Service...\n");
    if (execute_command("sudo systemctl enable xvfb") != 0) {
        fprintf(stderr, "Fehler beim Aktivieren des Xvfb-Services\n");
        return 1;
    }

    printf("Starte Xvfb-Service...\n");
    if (execute_command("sudo systemctl start xvfb") != 0) {
        fprintf(stderr, "Fehler beim Starten des Xvfb-Services\n");
        return 1;
    }

    printf("=== Xvfb läuft auf DISPLAY :99 ===\n");
    
    printf("Chromium Version:\n");
    if (execute_command("chromium --version") != 0) {
        printf("Chromium nicht gefunden\n");
    }

    printf("=== Setup abgeschlossen ===\n");
    printf("=== Altes VNC-Setup wurde entfernt ===\n");

    return 0;
}
