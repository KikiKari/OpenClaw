// abstraction-provenance: {"artifact_sha256": "d12312324bdbf7ff7e4595265d7c2936573172005e91fb56adaaaa0789360db7", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "java"}
// sync_bulk.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.*;

/**
 * Bulk Sync - Synchronisiert alle Skills
 */
public class SyncBulk {
    private static final Path CLAWHUB_DIR = Paths.get("/home/openclaw/.openclaw/workspace/skills");
    private static final Path GIT_DIR = Paths.get("/home/openclaw/.openclaw/workspace/git/skills");
    
    // Simulierte externe Funktionen
    private static boolean syncToGit(String skill, boolean dryRun) {
        // Implementierung würde hier erfolgen
        return true;
    }
    
    private static boolean syncToClawhub(String skill, boolean dryRun) {
        // Implementierung würde hier erfolgen
        return true;
    }
    
    private static void log(String message) {
        log(message, "INFO");
    }
    
    private static void log(String message, String level) {
        System.out.println("[" + level + "] " + message);
    }
    
    private static boolean validateSkill(Path path) {
        // Implementierung würde hier erfolgen
        return true;
    }
    
    public static class Results {
        public List<String> synced = new ArrayList<>();
        public List<String> skipped = new ArrayList<>();
        public List<String> failed = new ArrayList<>();
    }
    
    public static void syncAllSkills(boolean dryRun) {
        // Alle Skills finden
        Set<String> allSkills = new HashSet<>();
        
        if (Files.exists(CLAWHUB_DIR)) {
            try (Stream<Path> paths = Files.list(CLAWHUB_DIR)) {
                allSkills.addAll(paths
                    .filter(Files::isDirectory)
                    .filter(path -> !path.getFileName().toString().startsWith("."))
                    .map(path -> path.getFileName().toString())
                    .collect(Collectors.toList()));
            } catch (IOException e) {
                log("Fehler beim Lesen von ClawHub-Verzeichnis: " + e.getMessage(), "ERROR");
            }
        }
        
        if (Files.exists(GIT_DIR)) {
            try (Stream<Path> paths = Files.list(GIT_DIR)) {
                allSkills.addAll(paths
                    .filter(Files::isDirectory)
                    .filter(path -> !path.getFileName().toString().startsWith("."))
                    .map(path -> path.getFileName().toString())
                    .collect(Collectors.toList()));
            } catch (IOException e) {
                log("Fehler beim Lesen von Git-Verzeichnis: " + e.getMessage(), "ERROR");
            }
        }
        
        log("Bulk Sync: " + allSkills.size() + " Skills gefunden");
        
        Results results = new Results();
        
        for (String skill : new TreeSet<>(allSkills)) {
            Path clawhubPath = CLAWHUB_DIR.resolve(skill);
            Path gitPath = GIT_DIR.resolve(skill);
            
            try {
                // Nur in ClawHub → zu Git
                if (Files.exists(clawhubPath) && !Files.exists(gitPath)) {
                    if (validateSkill(clawhubPath)) {
                        log("Syncing " + skill + " to Git...");
                        if (syncToGit(skill, dryRun)) {
                            results.synced.add(skill + " → Git");
                        } else {
                            results.failed.add(skill);
                        }
                    } else {
                        results.skipped.add(skill + " (validation failed)");
                    }
                }
                // Nur in Git → zu ClawHub
                else if (Files.exists(gitPath) && !Files.exists(clawhubPath)) {
                    if (validateSkill(gitPath)) {
                        log("Syncing " + skill + " to ClawHub...");
                        if (syncToClawhub(skill, dryRun)) {
                            results.synced.add(skill + " → ClawHub");
                        } else {
                            results.failed.add(skill);
                        }
                    } else {
                        results.skipped.add(skill + " (validation failed)");
                    }
                }
                // In beiden - prüfe ob Update nötig
                else if (Files.exists(clawhubPath) && Files.exists(gitPath)) {
                    // Vereinfachte Prüfung
                    long clawhubMtime = getMaxModificationTime(clawhubPath);
                    long gitMtime = getMaxModificationTimeExcludeGit(gitPath);
                    
                    if (Math.abs(clawhubMtime - gitMtime) > 60) {
                        if (clawhubMtime > gitMtime) {
                            log("Updating " + skill + " in Git...");
                            if (syncToGit(skill, dryRun)) {
                                results.synced.add(skill + " → Git (update)");
                            } else {
                                results.failed.add(skill);
                            }
                        } else {
                            log("Updating " + skill + " in ClawHub...");
                            if (syncToClawhub(skill, dryRun)) {
                                results.synced.add(skill + " → ClawHub (update)");
                            } else {
                                results.failed.add(skill);
                            }
                        }
                    } else {
                        results.skipped.add(skill + " (already synced)");
                    }
                }
            } catch (Exception e) {
                log("Error processing " + skill + ": " + e.getMessage(), "ERROR");
                results.failed.add(skill);
            }
        }
        
        // Zusammenfassung
        System.out.println("\n" + "=".repeat(60));
        System.out.println("Bulk Sync " + (dryRun ? "DRY-RUN" : "EXECUTED") + " - Zusammenfassung");
        System.out.println("=".repeat(60));
        System.out.println("✅ Synchronisiert: " + results.synced.size());
        for (String item : results.synced) {
            System.out.println("   - " + item);
        }
        System.out.println("\n⏭️  Übersprungen: " + results.skipped.size());
        if (results.skipped.size() <= 10) {
            for (String item : results.skipped) {
                System.out.println("   - " + item);
            }
        } else {
            System.out.println("   - " + results.skipped.size() + " Skills (bereits synchron oder Validierung fehlgeschlagen)");
        }
        System.out.println("\n❌ Fehlgeschlagen: " + results.failed.size());
        for (String item : results.failed) {
            System.out.println("   - " + item);
        }
        System.out.println("=".repeat(60));
    }
    
    private static long getMaxModificationTime(Path directory) throws IOException {
        try (Stream<Path> paths = Files.walk(directory)) {
            return paths
                .filter(Files::isRegularFile)
                .mapToLong(path -> {
                    try {
                        return Files.getLastModifiedTime(path).toMillis() / 1000;
                    } catch (IOException e) {
                        return 0;
                    }
                })
                .max()
                .orElse(0);
        }
    }
    
    private static long getMaxModificationTimeExcludeGit(Path directory) throws IOException {
        try (Stream<Path> paths = Files.walk(directory)) {
            return paths
                .filter(Files::isRegularFile)
                .filter(path -> !path.toString().contains(".git"))
                .mapToLong(path -> {
                    try {
                        return Files.getLastModifiedTime(path).toMillis() / 1000;
                    } catch (IOException e) {
                        return 0;
                    }
                })
                .max()
                .orElse(0);
        }
    }
    
    public static void main(String[] args) {
        boolean dryRun = false;
        boolean execute = false;
        
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--dry-run":
                    dryRun = true;
                    break;
                case "--execute":
                    execute = true;
                    break;
                default:
                    System.err.println("Unbekanntes Argument: " + args[i]);
                    System.exit(1);
            }
        }
        
        if (!dryRun && !execute) {
            System.out.println("Bitte --dry-run oder --execute angeben");
            System.exit(1);
        }
        
        syncAllSkills(dryRun);
    }
}
