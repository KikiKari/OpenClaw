// abstraction-provenance: {"artifact_sha256": "3ce44c88045a4cd57f80ac3812a81989eefcf163484483a85ac3a159779863a3", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "java"}
// sync_agent_cron.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
// auch in: workspace@local:scripts/sync_agent_cron.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

public class SyncAgentCron {
    private static final Path CLAWHUB_DIR = Paths.get("/home/openclaw/.openclaw/workspace/skills");
    private static final Path GIT_DIR = Paths.get("/home/openclaw/.openclaw/workspace/git/skills");
    private static final Path LOG_FILE = Paths.get("/home/openclaw/.openclaw/workspace/logs/sync-agent.log");

    public static void main(String[] args) {
        writeToLog("======================================================================");
        writeToLog("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF");
        writeToLog("Zeitstempel: " + LocalDateTime.now().toString());
        writeToLog("======================================================================");

        Set<String> clawhubSkills = getSkillDirectories(CLAWHUB_DIR);
        Set<String> gitSkills = getSkillDirectories(GIT_DIR);

        // DRY-RUN: Erkenne Änderungen
        writeToLog("\n[DRY-RUN] Analysiere Änderungen...");

        Map<String, Object> changesDetected = new HashMap<>();
        List<String> newInClawhub = new ArrayList<>(clawhubSkills);
        newInClawhub.removeAll(gitSkills);
        Collections.sort(newInClawhub);

        List<String> newInGit = new ArrayList<>(gitSkills);
        newInGit.removeAll(clawhubSkills);
        Collections.sort(newInGit);

        changesDetected.put("new_in_clawhub", newInClawhub);
        changesDetected.put("new_in_git", newInGit);

        List<String> synced = new ArrayList<>();
        List<Map<String, Object>> clawhubNewer = new ArrayList<>();
        List<Map<String, Object>> gitNewer = new ArrayList<>();

        Set<String> inBoth = new HashSet<>(clawhubSkills);
        inBoth.retainAll(gitSkills);
        List<String> sortedInBoth = new ArrayList<>(inBoth);
        Collections.sort(sortedInBoth);

        for (String skill : sortedInBoth) {
            long cMtime = fileMtime(CLAWHUB_DIR.resolve(skill));
            long gMtime = fileMtime(GIT_DIR.resolve(skill));
            long diff = cMtime - gMtime;

            if (Math.abs(diff) > 60) {
                Map<String, Object> entry = new HashMap<>();
                entry.put("skill", skill);
                if (diff > 0) {
                    entry.put("diff", diff);
                    clawhubNewer.add(entry);
                } else {
                    entry.put("diff", Math.abs(diff));
                    gitNewer.add(entry);
                }
            } else {
                synced.add(skill);
            }
        }

        changesDetected.put("clawhub_newer", clawhubNewer);
        changesDetected.put("git_newer", gitNewer);
        changesDetected.put("synced", synced);

        int totalChanges = newInClawhub.size() + newInGit.size() + clawhubNewer.size() + gitNewer.size();
        writeToLog("Neu in ClawHub: " + newInClawhub.size());
        writeToLog("Neu in Git: " + newInGit.size());
        writeToLog("ClawHub neuer: " + clawhubNewer.size());
        writeToLog("Git neuer: " + gitNewer.size());
        writeToLog("Synchron: " + synced.size());

        if (totalChanges == 0) {
            writeToLog("\n✅ Keine Änderungen erkannt. Sync nicht nötig.");
            writeToLog("======================================================================");
            System.exit(0);
        }

        writeToLog("\n🔄 " + totalChanges + " Änderungen erkannt - starte Synchronisation...");

        Map<String, Object> results = new HashMap<>();
        List<String> syncedToGit = new ArrayList<>();
        List<String> syncedToClawhub = new ArrayList<>();
        List<String> upToDate = new ArrayList<>(synced);
        List<String> errors = new ArrayList<>();

        // 1. NEU in ClawHub → zu Git
        for (String skill : newInClawhub) {
            try {
                if (validateSkill(CLAWHUB_DIR.resolve(skill))) {
                    writeToLog("→ Synchronisiere " + skill + " zu Git...");
                    if (syncToGit(skill, false)) {
                        Path gitPath = GIT_DIR.resolve(skill);
                        executeCommand("cd " + gitPath.toString() + " && git init -q 2>/dev/null");
                        executeCommand("cd " + gitPath.toString() + " && git add . -f 2>/dev/null");
                        String commitMsg = "Initial: " + skill;
                        executeCommand("cd " + gitPath.toString() + " && git commit -m \"" + commitMsg + "\" -q 2>/dev/null");
                        syncedToGit.add(skill);
                        writeToLog("  ✓ " + skill + " synchronisiert");
                    }
                } else {
                    errors.add(skill + " (invalid)");
                }
            } catch (Exception e) {
                writeToLog("  ✗ ERROR: " + skill + " - " + e.getMessage(), "ERROR");
                errors.add(skill);
            }
        }

        // 2. NEU in Git → zu ClawHub
        for (String skill : newInGit) {
            try {
                if (validateSkill(GIT_DIR.resolve(skill))) {
                    writeToLog("→ Synchronisiere " + skill + " zu ClawHub...");
                    if (syncToClawhub(skill, false)) {
                        syncedToClawhub.add(skill);
                        writeToLog("  ✓ " + skill + " synchronisiert");
                    }
                } else {
                    errors.add(skill + " (invalid)");
                }
            } catch (Exception e) {
                writeToLog("  ✗ ERROR: " + skill + " - " + e.getMessage(), "ERROR");
                errors.add(skill);
            }
        }

        // 3. Updates
        for (Map<String, Object> entry : clawhubNewer) {
            String skill = (String) entry.get("skill");
            Long diff = (Long) entry.get("diff");
            try {
                writeToLog("→ Update " + skill + " (ClawHub +" + diff + "s neuer)...");
                if (syncToGit(skill, false)) {
                    Path gitPath = GIT_DIR.resolve(skill);
                    executeCommand("cd " + gitPath.toString() + " && git add . -f 2>/dev/null");
                    String dt = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
                    String commitMsg = "Sync from ClawHub: " + dt;
                    executeCommand("cd " + gitPath.toString() + " && git commit -m \"" + commitMsg + "\" -q 2>/dev/null");
                    syncedToGit.add(skill);
                    writeToLog("  ✓ " + skill + " aktualisiert");
                }
            } catch (Exception e) {
                writeToLog("  ✗ ERROR: " + skill + " - " + e.getMessage(), "ERROR");
                errors.add(skill);
            }
        }

        for (Map<String, Object> entry : gitNewer) {
            String skill = (String) entry.get("skill");
            Long diff = (Long) entry.get("diff");
            try {
                writeToLog("→ Update " + skill + " (Git +" + diff + "s neuer)...");
                if (syncToClawhub(skill, false)) {
                    syncedToClawhub.add(skill);
                    writeToLog("  ✓ " + skill + " aktualisiert");
                }
            } catch (Exception e) {
                writeToLog("  ✗ ERROR: " + skill + " - " + e.getMessage(), "ERROR");
                errors.add(skill);
            }
        }

        results.put("synced_to_git", syncedToGit);
        results.put("synced_to_clawhub", syncedToClawhub);
        results.put("up_to_date", upToDate);
        results.put("errors", errors);

        // ZUSAMMENFASSUNG
        writeToLog("\n" + "======================================================================");
        writeToLog("SYNCHRONISATION ABGESCHLOSSEN");
        writeToLog("======================================================================");
        writeToLog("Zu Git synchronisiert:     " + syncedToGit.size());
        writeToLog("Zu ClawHub synchronisiert: " + syncedToClawhub.size());
        writeToLog("Bereits aktuell:           " + upToDate.size());
        writeToLog("Fehler:                    " + errors.size());
        if (!errors.isEmpty()) {
            writeToLog("  Fehlerhafte: " + String.join(", ", errors));
        }
        writeToLog("======================================================================");

        // State speichern
        Path stateFile = Paths.get("/home/openclaw/.openclaw/workspace/db/sync_state.json");
        try {
            Files.createDirectories(stateFile.getParent());
            Map<String, Object> state = new HashMap<>();
            state.put("last_run", LocalDateTime.now().toString());
            state.put("results", results);
            
            Map<String, Object> changesCount = new HashMap<>();
            for (Map.Entry<String, Object> entry : changesDetected.entrySet()) {
                if (entry.getValue() instanceof List) {
                    changesCount.put(entry.getKey(), ((List<?>) entry.getValue()).size());
                } else {
                    changesCount.put(entry.getKey(), entry.getValue());
                }
            }
            state.put("changes_detected", changesCount);

            try (FileWriter writer = new FileWriter(stateFile.toFile())) {
                writer.write(toJson(state));
            }
            writeToLog("State gespeichert: " + stateFile.toString());
        } catch (IOException e) {
            writeToLog("Fehler beim Speichern des States: " + e.getMessage(), "ERROR");
        }
    }

    private static long fileMtime(Path path) {
        try {
            List<Path> files = Files.walk(path)
                .filter(p -> !p.toString().contains(".git"))
                .filter(Files::isRegularFile)
                .collect(Collectors.toList());
            return files.stream()
                .mapToLong(p -> {
                    try {
                        return Files.getLastModifiedTime(p).toMillis() / 1000;
                    } catch (IOException e) {
                        return 0;
                    }
                })
                .max()
                .orElse(0);
        } catch (IOException e) {
            return 0;
        }
    }

    private static void writeToLog(String message) {
        writeToLog(message, "INFO");
    }

    private static void writeToLog(String message, String level) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        String entry = "[" + timestamp + "] [" + level + "] " + message;
        System.out.println(entry);
        try {
            Files.write(LOG_FILE, (entry + "\n").getBytes(), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException e) {
            System.err.println("Fehler beim Schreiben ins Log: " + e.getMessage());
        }
    }

    private static Set<String> getSkillDirectories(Path dir) {
        Set<String> skills = new HashSet<>();
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dir)) {
            for (Path entry : stream) {
                if (Files.isDirectory(entry) && !entry.getFileName().toString().startsWith(".")) {
                    skills.add(entry.getFileName().toString());
                }
            }
        } catch (IOException e) {
            writeToLog("Fehler beim Lesen des Verzeichnisses " + dir + ": " + e.getMessage(), "ERROR");
        }
        return skills;
    }

    // Diese Methoden müssen entsprechend implementiert werden
    private static boolean validateSkill(Path skillPath) {
        // Implementierung von validate_skill
        return true;
    }

    private static boolean syncToGit(String skill, boolean dryRun) {
        // Implementierung von sync_to_git
        return true;
    }

    private static boolean syncToClawhub(String skill, boolean dryRun) {
        // Implementierung von sync_to_clawhub
        return true;
    }

    private static void executeCommand(String command) {
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"/bin/bash", "-c", command});
            process.waitFor();
        } catch (Exception e) {
            writeToLog("Fehler beim Ausführen des Kommandos: " + command + " - " + e.getMessage(), "ERROR");
        }
    }

    private static String toJson(Map<String, Object> map) {
        StringBuilder sb = new StringBuilder("{\n");
        List<String> entries = new ArrayList<>();
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            entries.add("  \"" + entry.getKey() + "\": " + toJsonValue(entry.getValue()));
        }
        sb.append(String.join(",\n", entries));
        sb.append("\n}");
        return sb.toString();
    }

    private static String toJsonValue(Object value) {
        if (value instanceof String) {
            return "\"" + value.toString() + "\"";
        } else if (value instanceof Number || value instanceof Boolean) {
            return value.toString();
        } else if (value instanceof List) {
            List<?> list = (List<?>) value;
            List<String> items = new ArrayList<>();
            for (Object item : list) {
                items.add(toJsonValue(item));
            }
            return "[" + String.join(", ", items) + "]";
        } else if (value instanceof Map) {
            return toJson((Map<String, Object>) value);
        } else {
            return "\"" + (value != null ? value.toString() : "null") + "\"";
        }
    }
}
