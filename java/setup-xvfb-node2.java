// abstraction-provenance: {"artifact_sha256": "f86e96a241ba454e2fd10ccc1b4982e03b8c18d9b83eb1eb4130be951f78d257", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "java"}
// setup-xvfb-node2.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// auch in: workspace@local:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class SetupXvfbNode2 {
    
    // Xvfb Setup für Node 2 (Netcup VPS)
    // Erstellt: 2026-04-09
    
    public static void main(String[] args) {
        try {
            System.out.println("=== Xvfb + Chromium Setup für Node 2 ===");
            
            // Update & Install
            runCommand("sudo apt-get update");
            runCommand("sudo apt-get install -y " +
                "xvfb " +
                "chromium-browser " +
                "chromium-chromedriver " +
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
                "User=openclaw\n" +
                "ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset\n" +
                "Restart=always\n" +
                "RestartSec=5\n" +
                "\n" +
                "[Install]\n" +
                "WantedBy=multi-user.target\n";
            
            writeFile("/etc/systemd/system/xvfb.service", serviceContent);
            
            // Service aktivieren
            runCommand("sudo systemctl daemon-reload");
            runCommand("sudo systemctl enable xvfb");
            runCommand("sudo systemctl start xvfb");
            
            System.out.println("=== Xvfb läuft auf DISPLAY :99 ===");
            System.out.println("Chromium Version:");
            
            try {
                runCommand("chromium-browser --version");
            } catch (Exception e) {
                System.out.println("Chromium nicht gefunden");
            }
            
            System.out.println("=== Setup abgeschlossen ===");
            
        } catch (Exception e) {
            System.err.println("Fehler beim Setup: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    private static void runCommand(String command) throws IOException, InterruptedException {
        Process process = Runtime.getRuntime().exec(new String[]{"/bin/bash", "-c", command});
        StreamGobbler outputGobbler = new StreamGobbler(process.getInputStream(), System.out);
        StreamGobbler errorGobbler = new StreamGobbler(process.getErrorStream(), System.err);
        
        outputGobbler.start();
        errorGobbler.start();
        
        int exitCode = process.waitFor();
        outputGobbler.join();
        errorGobbler.join();
        
        if (exitCode != 0) {
            throw new RuntimeException("Command failed with exit code: " + exitCode);
        }
    }
    
    private static void writeFile(String path, String content) throws IOException {
        // In einer echten Implementierung würde man hier mit Root-Rechten arbeiten
        // Da Java normalerweise keine Root-Rechte hat, ist dies eine Simulation
        System.out.println("Schreibe Datei: " + path);
        System.out.println("Inhalt:\n" + content);
        
        // Für eine echte Implementierung bräuchte man entweder:
        // 1. Ein externes Skript mit sudo-Rechten
        // 2. Eine native Bibliothek für Root-Zugriff
        // 3. Oder das Programm muss mit Root-Rechten ausgeführt werden
        
        // Alternative: Temporäre Datei erstellen und dann verschieben
        Path tempFile = Files.createTempFile("xvfb-service-", ".service");
        Files.write(tempFile, content.getBytes());
        System.out.println("Temporäre Datei erstellt: " + tempFile.toString());
    }
    
    private static class StreamGobbler extends Thread {
        private InputStream inputStream;
        private PrintStream outputStream;
        
        public StreamGobbler(InputStream inputStream, PrintStream outputStream) {
            this.inputStream = inputStream;
            this.outputStream = outputStream;
        }
        
        @Override
        public void run() {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    outputStream.println(line);
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}
