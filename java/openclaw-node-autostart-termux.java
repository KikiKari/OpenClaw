// abstraction-provenance: {"artifact_sha256": "ae2cd86223ac59c011c82ec2c76348c46732fb76b2a48ee8ad5834618b43452f", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "java"}
// openclaw-node-autostart-termux.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class OpenClawNodeAutostart {
    private static final String SESSION = "openclaw-node";
    private static final String LOGFILE = System.getProperty("user.home") + "/.openclaw/node.log";
    private static final String GATEWAY = "10.10.0.1";
    private static final String PORT = "18789";

    public static void main(String[] args) {
        try {
            // Log-Verzeichnis erstellen
            Files.createDirectories(Paths.get(System.getProperty("user.home") + "/.openclaw"));

            // Prüfen ob tmux Session bereits läuft (vereinfachte Prüfung)
            if (isTmuxSessionRunning(SESSION)) {
                logMessage("OpenClaw Node läuft bereits in tmux Session '" + SESSION + "'");
                System.exit(0);
            }

            // Neue tmux Session erstellen und OpenClaw starten
            startOpenClawNode();

            logMessage("OpenClaw Node Autostart aktiviert (tmux Session: " + SESSION + ")");

            // Optional: Hinweis falls interaktiv gestartet
            if (System.console() != null) {
                System.out.println("OpenClaw Node Mode gestartet in tmux Session '" + SESSION + "'");
                System.out.println("Zum Anschauen: tmux attach -t " + SESSION);
                System.out.println("Log-Datei: " + LOGFILE);
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static boolean isTmuxSessionRunning(String sessionName) {
        try {
            Process process = new ProcessBuilder("tmux", "has-session", "-t", sessionName)
                    .redirectError(new File("/dev/null"))
                    .start();
            return process.waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    private static void startOpenClawNode() throws IOException {
        String command = String.join("\n",
                "#!/bin/bash",
                "while true; do",
                "    echo '[" + getCurrentTimestamp() + "] Starting OpenClaw Node Mode...' | tee -a '" + LOGFILE + "'",
                "",
                "    # Prüfe WireGuard Verbindung",
                "    if ! ping -c 1 -W 3 " + GATEWAY + " >/dev/null 2>&1; then",
                "        echo '[" + getCurrentTimestamp() + "] FEHLER: WireGuard Gateway " + GATEWAY + " nicht erreichbar!' | tee -a '" + LOGFILE + "'",
                "        echo '[" + getCurrentTimestamp() + "] Warte 10 Sekunden...' | tee -a '" + LOGFILE + "'",
                "        sleep 10",
                "        continue",
                "    fi",
                "",
                "    # OpenClaw Node Mode starten",
                "    openclaw node run --host " + GATEWAY + " --port " + PORT + " 2>&1 | tee -a '" + LOGFILE + "'",
                "",
                "    # Wenn der Prozess endet, warte und neustarten",
                "    echo '[" + getCurrentTimestamp() + "] OpenClaw beendet. Neustart in 5 Sekunden...' | tee -a '" + LOGFILE + "'",
                "    sleep 5",
                "done"
        );

        ProcessBuilder pb = new ProcessBuilder("tmux", "new-session", "-d", "-s", SESSION, "-n", "node", "bash", "-c", command);
        pb.start();
    }

    private static void logMessage(String message) {
        try {
            String timestamp = "[" + getCurrentTimestamp() + "] ";
            Files.write(
                Paths.get(LOGFILE),
                (timestamp + message + "\n").getBytes(),
                StandardOpenOption.CREATE,
                StandardOpenOption.APPEND
            );
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static String getCurrentTimestamp() {
        return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
    }
}
