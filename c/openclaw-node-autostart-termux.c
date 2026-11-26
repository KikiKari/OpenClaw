// abstraction-provenance: {"artifact_sha256": "9091ec65b28f69f372914cd3a52642b2941fad05c9facf61f928d18d90c6906f", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "c"}
// openclaw-node-autostart-termux.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>
#include <sys/wait.h>
#include <signal.h>

#define SESSION_NAME "openclaw-node"
#define LOGFILE_PATH "/data/data/com.termux/files/home/.openclaw/node.log"
#define GATEWAY "10.10.0.1"
#define PORT "18789"

// Funktion zum Schreiben in die Logdatei
void write_log(const char *message) {
    FILE *logfile = fopen(LOGFILE_PATH, "a");
    if (logfile != NULL) {
        time_t now;
        time(&now);
        struct tm *local = localtime(&now);
        char timestamp[100];
        strftime(timestamp, sizeof(timestamp), "%a %b %d %H:%M:%S %Z %Y", local);
        fprintf(logfile, "[%s] %s\n", timestamp, message);
        fclose(logfile);
    }
}

// Funktion zum Überprüfen, ob eine tmux Session läuft
int tmux_session_exists(const char *session_name) {
    // Wir führen den Befehl 'tmux has-session -t session_name' aus
    char command[256];
    snprintf(command, sizeof(command), "tmux has-session -t \"%s\" 2>/dev/null", session_name);
    return system(command) == 0;
}

// Funktion zum Pingen eines Hosts
int ping_host(const char *host) {
    char command[256];
    snprintf(command, sizeof(command), "ping -c 1 -W 3 %s >/dev/null 2>&1", host);
    return system(command) == 0;
}

int main() {
    // Log-Verzeichnis erstellen
    mkdir("/data/data/com.termux/files/home/.openclaw", 0755);

    // Prüfen ob tmux Session bereits läuft
    if (tmux_session_exists(SESSION_NAME)) {
        char log_message[256];
        snprintf(log_message, sizeof(log_message),
                 "OpenClaw Node läuft bereits in tmux Session '%s'", SESSION_NAME);
        write_log(log_message);
        return 0;
    }

    // Neue tmux Session erstellen und OpenClaw starten
    char tmux_command[2048];
    snprintf(tmux_command, sizeof(tmux_command),
        "tmux new-session -d -s \"%s\" -n \"node\" \""
        "while true; do "
            "echo \\\"[$(date)] Starting OpenClaw Node Mode...\\\" | tee -a \\\"%s\\\"; "
            
            // Prüfe WireGuard Verbindung
            "if ! ping -c 1 -W 3 %s >/dev/null 2>&1; then "
                "echo \\\"[$(date)] FEHLER: WireGuard Gateway %s nicht erreichbar!\\\" | tee -a \\\"%s\\\"; "
                "echo \\\"[$(date)] Warte 10 Sekunden...\\\" | tee -a \\\"%s\\\"; "
                "sleep 10; "
                "continue; "
            "fi; "
            
            // OpenClaw Node Mode starten
            "openclaw node run --host %s --port %s 2>&1 | tee -a \\\"%s\\\"; "
            
            // Wenn der Prozess endet, warte und neustarten
            "echo \\\"[$(date)] OpenClaw beendet. Neustart in 5 Sekunden...\\\" | tee -a \\\"%s\\\"; "
            "sleep 5; "
        "done\"",
        SESSION_NAME,
        LOGFILE_PATH,
        GATEWAY,
        GATEWAY,
        LOGFILE_PATH,
        LOGFILE_PATH,
        GATEWAY,
        PORT,
        LOGFILE_PATH,
        LOGFILE_PATH
    );

    system(tmux_command);

    char log_message[256];
    snprintf(log_message, sizeof(log_message),
             "OpenClaw Node Autostart aktiviert (tmux Session: %s)", SESSION_NAME);
    write_log(log_message);

    // Optional: tmux attach Hinweis falls interaktiv gestartet
    if (isatty(STDOUT_FILENO)) {
        printf("OpenClaw Node Mode gestartet in tmux Session '%s'\n", SESSION_NAME);
        printf("Zum Anschauen: tmux attach -t %s\n", SESSION_NAME);
        printf("Log-Datei: %s\n", LOGFILE_PATH);
    }

    return 0;
}
