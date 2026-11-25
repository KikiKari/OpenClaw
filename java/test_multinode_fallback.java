// abstraction-provenance: {"artifact_sha256": "1d8423851d0c71c4f725db35e451a79e2f3325ce33e7c1f630a33f8e53dd12ac", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "java"}
// test_multinode_fallback.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
// auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.concurrent.TimeUnit;

/**
 * Testet Multi-Node Fallback-Logik des db-maintainer
 * Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
 */
public class TestMultinodeFallback {

    private static final Path WORKSPACE = Paths.get("/home/openclaw/.openclaw/workspace");

    /**
     * Prüft ob Node erreichbar ist
     */
    private static boolean checkNodeReachable(String nodeId) {
        try {
            // Versuche Node-Status abzufragen
            Process process = new ProcessBuilder("openclaw", "nodes", "status").start();
            if (!process.waitFor(10, TimeUnit.SECONDS)) {
                process.destroyForcibly();
                return false;
            }
            
            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }
            
            return output.toString().contains(nodeId) && output.toString().contains("connected");
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Versucht Task auf Node auszuführen
     */
    private static boolean spawnOnNode(String nodeId, String task) {
        System.out.println("Versuche Task auf Node " + nodeId + " zu starten...");
        try {
            // Simuliert: openclaw agent spawn --node {node_id}
            Process process = new ProcessBuilder("echo", "Spawned on " + nodeId + ": " + task).start();
            if (!process.waitFor(5, TimeUnit.SECONDS)) {
                process.destroyForcibly();
                System.out.println("❌ Node " + nodeId + " nicht erreichbar: Timeout");
                return false;
            }
            
            System.out.println("✅ Erfolgreich delegiert an " + nodeId);
            return true;
        } catch (Exception e) {
            System.out.println("❌ Node " + nodeId + " nicht erreichbar: " + e.getMessage());
            return false;
        }
    }

    /**
     * Führt Task lokal aus (Fallback)
     */
    private static boolean executeLocally(String task) {
        System.out.println("🔄 Fallback: Führe Task lokal aus...");
        try {
            if ("db_maintainer".equals(task)) {
                Process process = new ProcessBuilder(
                    "python3", 
                    WORKSPACE.resolve("skills").resolve("db-maintainer").resolve("scripts").resolve("db_maintainer.py").toString()
                ).start();
                
                if (!process.waitFor(60, TimeUnit.SECONDS)) {
                    process.destroyForcibly();
                    System.out.println("❌ Fehler: Timeout bei lokaler Ausführung");
                    return false;
                }
                
                if (process.exitValue() == 0) {
                    System.out.println("✅ Lokale Ausführung erfolgreich");
                    return true;
                } else {
                    StringBuilder errorOutput = new StringBuilder();
                    try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                        String line;
                        while ((line = reader.readLine()) != null && errorOutput.length() < 200) {
                            errorOutput.append(line).append("\n");
                        }
                    }
                    System.out.println("❌ Fehler: " + errorOutput.toString());
                    return false;
                }
            }
        } catch (Exception e) {
            System.out.println("❌ Lokale Ausführung fehlgeschlagen: " + e.getMessage());
            return false;
        }
        return false;
    }

    public static void main(String[] args) {
        System.out.println("============================================================");
        System.out.println("MULTI-NODE FALLBACK TEST");
        System.out.println("============================================================");
        System.out.println();

        // Konfiguration
        String primaryNode = "v2202603104722445775";  // Node 2
        String task = "db_maintainer";

        System.out.println("Primärer Node: " + primaryNode);
        System.out.println("Task: " + task);
        System.out.println();

        // 1. Prüfe Node-Erreichbarkeit
        System.out.println("--- 1. Prüfe Node-Erreichbarkeit ---");
        if (checkNodeReachable(primaryNode)) {
            System.out.println("✅ Node " + primaryNode + " ist erreichbar");

            // 2. Versuche Delegation
            System.out.println("\n--- 2. Versuche Delegation ---");
            if (spawnOnNode(primaryNode, task)) {
                System.out.println("\n✅ MULTI-NODE: Task erfolgreich delegiert");
                System.exit(0);
            } else {
                System.out.println("\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...");
            }
        } else {
            System.out.println("❌ Node " + primaryNode + " nicht erreichbar");
            System.out.println("🔄 Fallback wird aktiviert...");
        }

        // 3. Lokale Ausführung (Fallback)
        System.out.println("\n--- 3. Lokale Ausführung (Fallback) ---");
        if (executeLocally(task)) {
            System.out.println("\n✅ FALLBACK: Task lokal erfolgreich ausgeführt");
            System.exit(0);
        } else {
            System.out.println("\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich");
            System.exit(1);
        }
    }
}
