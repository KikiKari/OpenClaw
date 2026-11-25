// abstraction-provenance: {"artifact_sha256": "0516c2cf1293fa490eb6cb73b93a66e6810c501be6c5c56b4756ca863c4d1110", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "java"}
// test_multinode_fallback.py — portiert nach java
// Quelle: python, workspace@local:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.TimeUnit;

public class TestMultinodeFallback {
    private static final Path WORKSPACE = Paths.get("/home/openclaw/.openclaw/workspace");
    
    private static boolean checkNodeReachable(String nodeId) {
        Set<String> aliases = new HashSet<>();
        aliases.add(nodeId.toLowerCase());
        Set<String> node2Names = new HashSet<>(Arrays.asList(
            "openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net"
        ));
        if (node2Names.contains(nodeId.toLowerCase())) {
            aliases.addAll(node2Names);
        }
        
        try {
            Process process = new ProcessBuilder("openclaw", "nodes", "status", "--json")
                .redirectErrorStream(true)
                .start();
            
            boolean finished = process.waitFor(10, TimeUnit.SECONDS);
            if (!finished) {
                process.destroy();
                return false;
            }
            
            if (process.exitValue() != 0) {
                return false;
            }
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder output = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line);
            }
            
            // Simplified JSON parsing - in production use a proper JSON library
            String jsonOutput = output.toString();
            return jsonOutput.contains("\"connected\": true") && 
                   aliases.stream().anyMatch(alias -> jsonOutput.contains(alias.toLowerCase()));
            
        } catch (IOException | InterruptedException e) {
            return false;
        }
    }
    
    private static boolean spawnOnNode(String nodeId, String task) {
        System.out.println("Versuche Task auf Node " + nodeId + " zu starten...");
        try {
            Process process = new ProcessBuilder("echo", "Spawned on " + nodeId + ": " + task)
                .redirectErrorStream(true)
                .start();
            
            boolean finished = process.waitFor(5, TimeUnit.SECONDS);
            if (!finished) {
                process.destroy();
                return false;
            }
            
            if (process.exitValue() == 0) {
                System.out.println("✅ Erfolgreich delegiert an " + nodeId);
                return true;
            } else {
                System.out.println("❌ Node " + nodeId + " nicht erreichbar");
                return false;
            }
            
        } catch (IOException | InterruptedException e) {
            System.out.println("❌ Node " + nodeId + " nicht erreichbar: " + e.getMessage());
            return false;
        }
    }
    
    private static boolean executeLocally(String task) {
        System.out.println("🔄 Fallback: Führe Task lokal aus...");
        try {
            if ("db_maintainer".equals(task)) {
                Path scriptPath = WORKSPACE.resolve("skills").resolve("db-maintainer").resolve("scripts").resolve("db_maintainer.py");
                Process process = new ProcessBuilder("python3", scriptPath.toString())
                    .redirectErrorStream(true)
                    .start();
                
                boolean finished = process.waitFor(60, TimeUnit.SECONDS);
                if (!finished) {
                    process.destroy();
                    return false;
                }
                
                if (process.exitValue() == 0) {
                    System.out.println("✅ Lokale Ausführung erfolgreich");
                    return true;
                } else {
                    BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                    String errorOutput = reader.readLine();
                    if (errorOutput != null && errorOutput.length() > 200) {
                        errorOutput = errorOutput.substring(0, 200);
                    }
                    System.out.println("❌ Fehler: " + errorOutput);
                    return false;
                }
            }
            return false;
        } catch (IOException | InterruptedException e) {
            System.out.println("❌ Lokale Ausführung fehlgeschlagen: " + e.getMessage());
            return false;
        }
    }
    
    public static void main(String[] args) {
        System.out.println("=".repeat(60));
        System.out.println("MULTI-NODE FALLBACK TEST");
        System.out.println("=".repeat(60));
        System.out.println();
        
        String primaryNode = "v2202604104722449961.taild25fea.ts.net";
        String task = "db_maintainer";
        
        System.out.println("Primärer Node: " + primaryNode);
        System.out.println("Task: " + task);
        System.out.println();
        
        System.out.println("--- 1. Prüfe Node-Erreichbarkeit ---");
        if (checkNodeReachable(primaryNode)) {
            System.out.println("✅ Node " + primaryNode + " ist erreichbar");
            
            System.out.println("\n--- 2. Versuche Delegation ---");
            if (spawnOnNode(primaryNode, task)) {
                System.out.println("\n✅ MULTI-NODE: Task erfolgreich delegiert");
                System.exit(0);
            } else {
                System.out.println("\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...");
            }
        } else {
            System.out.println("❌ Node " + primaryNode + " nicht erreichbar");
            System.out.println("🔄 Fallback wird aktivierte...");
        }
        
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
