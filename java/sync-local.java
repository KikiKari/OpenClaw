// abstraction-provenance: {"artifact_sha256": "5a8f07dda42def7543a24afe819ddc8f0e74ce903df918f6effcdf8934ae4ed3", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "java"}
// sync-local.ps1 — portiert nach java
// Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class SyncLocal {
    private static final String DEFAULT_BRANCH = "claude/onboarding-persistent-sandbox-vjfmcx";
    private static final int DEFAULT_INTERVAL_SECONDS = 20;
    private static final String COMPOSE_FILE = "docker-compose.dev.yml";
    
    private final String branch;
    private final int intervalSeconds;
    private final boolean once;
    private final Path repoRoot;
    
    public SyncLocal(String branch, int intervalSeconds, boolean once) throws IOException {
        this.branch = branch;
        this.intervalSeconds = intervalSeconds;
        this.once = once;
        this.repoRoot = Paths.get("").toAbsolutePath();
    }
    
    private void log(String msg) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("HH:mm:ss"));
        System.out.println("[" + timestamp + "] " + msg);
    }
    
    private ProcessResult runCommand(String... command) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(command);
        pb.directory(repoRoot.toFile());
        Process process = pb.start();
        
        StringBuilder output = new StringBuilder();
        StringBuilder error = new StringBuilder();
        
        try (BufferedReader outReader = new BufferedReader(new InputStreamReader(process.getInputStream()));
             BufferedReader errReader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
            
            String line;
            while ((line = outReader.readLine()) != null) {
                output.append(line).append("\n");
            }
            while ((line = errReader.readLine()) != null) {
                error.append(line).append("\n");
            }
        }
        
        int exitCode = process.waitFor();
        return new ProcessResult(exitCode, output.toString().trim(), error.toString().trim());
    }
    
    private void invokeCompose(String... composeArgs) {
        try {
            List<String> command = new ArrayList<>();
            command.add("docker");
            command.add("compose");
            command.add("-f");
            command.add(COMPOSE_FILE);
            Collections.addAll(command, composeArgs);
            
            ProcessResult result = runCommand(command.toArray(new String[0]));
            if (result.exitCode != 0) {
                log("WARNUNG: docker compose " + String.join(" ", composeArgs) + " fehlgeschlagen (Exit " + result.exitCode + ")");
            }
        } catch (Exception e) {
            log("WARNUNG: docker compose Befehl fehlgeschlagen: " + e.getMessage());
        }
    }
    
    public void run() throws IOException, InterruptedException {
        // Sicherstellen, dass der Ziel-Branch ausgecheckt ist
        ProcessResult currentResult = runCommand("git", "rev-parse", "--abbrev-ref", "HEAD");
        String current = currentResult.output.trim();
        
        if (!current.equals(branch)) {
            log("Wechsle von '" + current + "' auf '" + branch + "' …");
            runCommand("git", "fetch", "origin", branch);
            
            ProcessResult switchResult = runCommand("git", "switch", branch);
            if (switchResult.exitCode != 0) {
                ProcessResult trackResult = runCommand("git", "switch", "-c", branch, "--track", "origin/" + branch);
                if (trackResult.exitCode != 0) {
                    throw new RuntimeException("Branch '" + branch + "' konnte nicht ausgecheckt werden.");
                }
            }
        }
        
        log("Sync aktiv: origin/" + branch + " -> " + repoRoot + " (Intervall " + intervalSeconds + "s, Compose: " + COMPOSE_FILE + ")");
        
        while (true) {
            ProcessResult fetchResult = runCommand("git", "fetch", "origin", branch, "--quiet");
            if (fetchResult.exitCode != 0) {
                log("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in " + intervalSeconds + "s");
            } else {
                ProcessResult localResult = runCommand("git", "rev-parse", "HEAD");
                ProcessResult remoteResult = runCommand("git", "rev-parse", "origin/" + branch);
                
                String local = localResult.output.trim();
                String remote = remoteResult.output.trim();
                
                if (!local.equals(remote)) {
                    ProcessResult ancestorResult = runCommand("git", "merge-base", "--is-ancestor", local, remote);
                    
                    if (ancestorResult.exitCode != 0) {
                        log("ACHTUNG: Lokaler Stand ist von origin/" + branch + " abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.");
                    } else {
                        ProcessResult diffResult = runCommand("git", "diff", "--name-only", local + ".." + remote);
                        String[] changedFiles = diffResult.output.isEmpty() ? new String[0] : diffResult.output.split("\n");
                        
                        runCommand("git", "merge", "--ff-only", remote, "--quiet");
                        log("Aktualisiert " + local.substring(0, Math.min(7, local.length())) + 
                            " -> " + remote.substring(0, Math.min(7, remote.length())) + 
                            " (" + changedFiles.length + " Datei(en))");
                        
                        boolean frontendDepsChanged = false;
                        boolean backendImageChanged = false;
                        boolean composeChanged = false;
                        
                        for (String file : changedFiles) {
                            if (file.equals("package.json") || file.equals("package-lock.json")) {
                                frontendDepsChanged = true;
                            }
                            if (file.matches("^backend/(Dockerfile|requirements.*\\.txt)$")) {
                                backendImageChanged = true;
                            }
                            if (file.equals(COMPOSE_FILE)) {
                                composeChanged = true;
                            }
                        }
                        
                        if (composeChanged) {
                            log("Compose-Datei geändert — erzeuge Dev-Stack neu …");
                            invokeCompose("up", "-d");
                        }
                        if (backendImageChanged) {
                            log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …");
                            invokeCompose("up", "-d", "--build", "backend");
                        }
                        if (frontendDepsChanged) {
                            log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …");
                            invokeCompose("restart", "frontend");
                        }
                        if (!(composeChanged || backendImageChanged || frontendDepsChanged)) {
                            log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.");
                        }
                    }
                }
            }
            
            if (once) break;
            
            try {
                Thread.sleep(intervalSeconds * 1000L);
            } catch (InterruptedException e) {
                break;
            }
        }
    }
    
    private static class ProcessResult {
        final int exitCode;
        final String output;
        final String error;
        
        ProcessResult(int exitCode, String output, String error) {
            this.exitCode = exitCode;
            this.output = output;
            this.error = error;
        }
    }
    
    public static void main(String[] args) {
        String branch = DEFAULT_BRANCH;
        int intervalSeconds = DEFAULT_INTERVAL_SECONDS;
        boolean once = false;
        
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "-Branch":
                    if (i + 1 < args.length) {
                        branch = args[++i];
                    }
                    break;
                case "-IntervalSeconds":
                    if (i + 1 < args.length) {
                        intervalSeconds = Integer.parseInt(args[++i]);
                    }
                    break;
                case "-Once":
                    once = true;
                    break;
            }
        }
        
        try {
            new SyncLocal(branch, intervalSeconds, once).run();
        } catch (Exception e) {
            System.err.println("Fehler: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}
