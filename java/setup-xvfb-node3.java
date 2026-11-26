// abstraction-provenance: {"artifact_sha256": "919d3c8c9f525c7e52a3056ea7796be23e05ece64109812a5e26edd41f3dcc77", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "java"}
// setup-xvfb-node3.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// auch in: workspace@local:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class SetupXvfbNode3 {

    public static void main(String[] args) {
        try {
            System.out.println("=== Xvfb + Chromium Setup für Node 3 ===");
            System.out.println("=== Entferne altes VNC-Setup ===");

            // Altes VNC stoppen & entfernen (falls vorhanden)
            executeCommand("sudo systemctl stop vncserver@*", true);
            executeCommand("sudo systemctl disable vncserver@*", true);
            executeCommand("sudo apt-get remove -y tightvncserver tigervnc-standalone-server", true);
            
            // Entferne VNC-Dateien
            deleteFileIfExists(System.getProperty("user.home") + "/.vnc");
            deleteDirectoryIfExists("/tmp/.X11-unix");

            System.out.println("=== Installiere Xvfb + Chromium ===");

            // Update & Install
            executeCommand("sudo apt-get update");
            executeCommand("sudo apt-get install -y " +
                "xvfb " +
                "chromium " +
                "chromium-driver " +
                "fonts-liberation " +
                "libappindicator3-1 " +
                "libasound2 " +
                "libatk-bridge2.0-0 " +
                "libatk1.0-0 " +
                "libcups2 " +
                "libgtk-3-0 " +
                "libnspr4 " +
                "libnss3 " +
                "libxss1 " +
                "xdg-utils");

            // Xvfb Systemd Service erstellen
            String serviceContent = "[Unit]\n" +
                "Description=X Virtual Framebuffer\n" +
                "After=network.target\n" +
                "\n" +
                "[Service]\n" +
                "Type=simple\n" +
                "User=root\n" +
                "ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset\n" +
                "Restart=always\n" +
                "RestartSec=5\n" +
                "\n" +
                "[Install]\n" +
                "WantedBy=multi-user.target\n";

            writeFile("/etc/systemd/system/xvfb.service", serviceContent);

            // Service aktivieren
            executeCommand("sudo systemctl daemon-reload");
            executeCommand("sudo systemctl enable xvfb");
            executeCommand("sudo systemctl start xvfb");

            System.out.println("=== Xvfb läuft auf DISPLAY :99 ===");
            System.out.println("Chromium Version:");
            
            try {
                Process process = executeCommand("chromium --version", true);
                if (process.exitValue() != 0) {
                    System.out.println("Chromium nicht gefunden");
                }
            } catch (Exception e) {
                System.out.println("Chromium nicht gefunden");
            }

            System.out.println("=== Setup abgeschlossen ===");
            System.out.println("=== Altes VNC-Setup wurde entfernt ===");

        } catch (Exception e) {
            System.err.println("Fehler beim Setup: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static Process executeCommand(String command) throws IOException, InterruptedException {
        return executeCommand(command, false);
    }

    private static Process executeCommand(String command, boolean ignoreErrors) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder("bash", "-c", command);
        if (ignoreErrors) {
            pb.redirectError(new File("/dev/null"));
        }
        Process process = pb.start();
        process.waitFor();
        return process;
    }

    private static void writeFile(String filePath, String content) throws IOException {
        Path path = Paths.get(filePath);
        Files.createDirectories(path.getParent());
        Files.write(path, content.getBytes());
    }

    private static void deleteFileIfExists(String filePath) {
        try {
            Files.deleteIfExists(Paths.get(filePath));
        } catch (IOException e) {
            System.err.println("Konnte Datei nicht löschen: " + filePath);
        }
    }

    private static void deleteDirectoryIfExists(String dirPath) {
        try {
            Path path = Paths.get(dirPath);
            if (Files.exists(path)) {
                Files.walk(path)
                    .sorted(Comparator.reverseOrder())
                    .map(Path::toFile)
                    .forEach(File::delete);
            }
        } catch (IOException e) {
            System.err.println("Konnte Verzeichnis nicht löschen: " + dirPath);
        }
    }
}
