// abstraction-provenance: {"artifact_sha256": "02b2e5900c29549dc02f986f5fd3e41715c1d05cb72c0c5d3daac7a5b7dfdab9", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "java"}
// openclaw-maintenance.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;

public class OpenClawMaintenance {
    private static final String OPENCLAW_BIN = System.getenv().getOrDefault("OPENCLAW_BIN", 
        Paths.get(System.getProperty("user.home"), ".local", "bin", "openclaw").toString());

    public static void main(String[] args) {
        try {
            // Prüfe ob OpenClaw Binary existiert und ausführbar ist
            if (!Files.isExecutable(Paths.get(OPENCLAW_BIN))) {
                System.err.println("ERROR: OpenClaw binary not found: " + OPENCLAW_BIN);
                System.exit(1);
            }

            System.out.println("Using OpenClaw: " + executeCommand(OPENCLAW_BIN, "--version"));

            // === 1. Service-/Config-Drift ===
            executeCommand(OPENCLAW_BIN, "doctor");

            // === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
            executeCommand(OPENCLAW_BIN, "plugins", "registry", "--refresh");
            
            String runPluginUpdate = System.getenv().getOrDefault("RUN_PLUGIN_UPDATE", "0");
            if ("1".equals(runPluginUpdate)) {
                executeCommand(OPENCLAW_BIN, "plugins", "update", "--all");
            } else {
                System.out.println("Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.");
            }

            // === 3. Tasks ===
            executeCommand(OPENCLAW_BIN, "tasks", "maintenance", "--apply");

            // === 4. Sessions – alle Agents auf einmal ===
            executeCommand(OPENCLAW_BIN, "sessions", "cleanup", "--enforce", "--all-agents");

            // === 5. Memory – status/index decken alle Agents ab ===
            executeCommand(OPENCLAW_BIN, "memory", "status", "--deep", "--fix");
            executeCommand(OPENCLAW_BIN, "memory", "index", "--force");

            // === 6. Memory promote – MUSS pro Agent ===
            String[] agents = {"main", "knecht", "docs", "ops-hub", "cron"};
            for (String agent : agents) {
                executeCommand(OPENCLAW_BIN, "memory", "promote", "--apply", "--agent", agent);
            }

            // === 7. Secrets ===
            executeCommand(OPENCLAW_BIN, "secrets", "reload");

        } catch (Exception e) {
            System.err.println("Error executing OpenClaw maintenance: " + e.getMessage());
            System.exit(1);
        }
    }

    private static String executeCommand(String... command) throws IOException, InterruptedException {
        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.environment().putAll(System.getenv());
        
        Process process = processBuilder.start();
        StringBuilder output = new StringBuilder();
        
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }
        
        int exitCode = process.waitFor();
        if (exitCode != 0 && command[1].equals("--version")) {
            throw new RuntimeException("Command failed with exit code " + exitCode + ": " + String.join(" ", command));
        }
        
        if (command[1].equals("--version")) {
            return output.toString().trim();
        } else {
            System.out.print(output.toString());
            return "";
        }
    }
}
