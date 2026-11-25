// abstraction-provenance: {"artifact_sha256": "5880605cde79d548cb641046c29b5901f49d09ae81c7afb2179d38b6c1ee4702", "source_sha256": "f8c56b5aecfa8cd091cc5fe50697c5613148d19f0d4e0eb311bf6d129c600018", "target_language": "java"}
// test_sync_real.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
// auch in: OpenClaw@gateway2:scripts/test_sync_real.py
// auch in: workspace@local:scripts/test_sync_real.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class TestSyncReal {
    
    // Simuliere das Python-Verhalten: sys.path.append und import
    // In Java verwenden wir statische Methoden oder separate Klassen
    // Angenommen, sync_clawhub_git ist eine Klasse mit statischen Methoden
    
    /** Test echte Synchronisation */
    public static void main(String[] args) {
        System.out.println("=== TEST: db-maintainer sync (REAL) ===");
        
        String skill = "db-maintainer";
        boolean result = SyncClawHubGit.syncToGit(skill, false);
        System.out.println("Result: " + (result ? "SUCCESS" : "FAILED"));
        
        // Prüfe Ergebnis
        String target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer";
        Path targetPath = Paths.get(target);
        
        if (Files.exists(targetPath)) {
            System.out.println("\n✅ Git-Repo erstellt: " + target);
            try {
                Files.walk(targetPath, Integer.MAX_VALUE)
                    .filter(path -> Files.isDirectory(path) || path.equals(targetPath))
                    .forEach(path -> {
                        int level = targetPath.relativize(path).toString().split("[/\\\\]+").length;
                        if (!targetPath.equals(path)) level++; // Root nicht zählen
                        
                        String indent = " ".repeat(2 * (level - 1));
                        
                        if (Files.isDirectory(path)) {
                            System.out.println(indent + path.getFileName() + "/");
                            
                            // Dateien im Verzeichnis auflisten
                            try {
                                Files.list(path)
                                    .filter(p -> !Files.isDirectory(p))
                                    .forEach(file -> 
                                        System.out.println(" ".repeat(2 * level) + file.getFileName())
                                    );
                            } catch (IOException e) {
                                // Ignorieren
                            }
                        } else if (targetPath.equals(path)) {
                            System.out.println(path.getFileName() + "/");
                        }
                    });
            } catch (IOException e) {
                System.err.println("Fehler beim Durchsuchen des Verzeichnisses: " + e.getMessage());
            }
        }
    }
}
