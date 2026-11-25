// abstraction-provenance: {"artifact_sha256": "139b7afa6c47aace999453e4c22d257dccf3f807c9a0926560119670d651f08f", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "java"}
// translation-worker-node.sh — portiert nach java
// Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public class TranslationWorkerNode {

    public static void main(String[] args) {
        // Run on the selected node after transferring its native worker. JSON stdin is
        // forwarded unchanged to the worker in run mode.
        
        if (args.length != 2) {
            System.err.println("Usage: translation-worker-node.sh node2|node3|node4|node6 prepare|health|run");
            System.exit(2);
            return;
        }
        
        String workerPath;
        String expectedChecksum;
        
        switch (args[0]) {
            case "node2":
                workerPath = "/home/node/.openclaw/workers/translation-worker";
                expectedChecksum = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286";
                break;
            case "node3":
                workerPath = "/home/openclaw/.openclaw/workers/translation-worker";
                expectedChecksum = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de";
                break;
            case "node4":
                workerPath = "/root/.openclaw/workers/translation-worker";
                expectedChecksum = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286";
                break;
            case "node6":
                workerPath = "/home/node/.openclaw/workers/translation-worker";
                expectedChecksum = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de";
                break;
            default:
                System.err.println("Unknown or non-POSIX node");
                System.exit(2);
                return;
        }
        
        switch (args[1]) {
            case "prepare":
            case "health":
            case "run":
                break;
            default:
                System.err.println("Unknown action");
                System.exit(2);
                return;
        }
        
        Path worker = Paths.get(workerPath);
        if (!Files.exists(worker) || Files.isSymbolicLink(worker)) {
            System.err.println("Missing worker or symlink rejected: " + workerPath);
            System.exit(1);
            return;
        }
        
        String actualChecksum;
        try {
            actualChecksum = calculateSHA256(worker);
        } catch (Exception e) {
            System.err.println("Failed to calculate checksum: " + e.getMessage());
            System.exit(1);
            return;
        }
        
        if (!actualChecksum.equals(expectedChecksum)) {
            System.err.println("Worker checksum mismatch: " + workerPath);
            System.exit(1);
            return;
        }
        
        try {
            Files.setPosixFilePermissions(worker, 
                java.nio.file.attribute.PosixFilePermissions.fromString("rwxr-xr-x"));
        } catch (Exception e) {
            System.err.println("Failed to set executable permissions: " + e.getMessage());
            System.exit(1);
            return;
        }
        
        switch (args[1]) {
            case "prepare":
                System.out.println("Worker verified and executable: " + workerPath);
                break;
            case "health":
                executeWorker(workerPath, "--health");
                break;
            case "run":
                executeWorker(workerPath);
                break;
        }
    }
    
    private static String calculateSHA256(Path file) throws IOException, NoSuchAlgorithmException {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream inputStream = Files.newInputStream(file)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                digest.update(buffer, 0, bytesRead);
            }
        }
        byte[] hashBytes = digest.digest();
        return HexFormat.of().formatHex(hashBytes);
    }
    
    private static void executeWorker(String workerPath, String... additionalArgs) {
        try {
            ProcessBuilder pb = new ProcessBuilder();
            String[] command = new String[1 + additionalArgs.length];
            command[0] = workerPath;
            System.arraycopy(additionalArgs, 0, command, 1, additionalArgs.length);
            pb.command(command);
            
            if ("run".equals(Thread.currentThread().getName())) {
                // Forward stdin for run mode
                pb.inheritIO();
            }
            
            Process process = pb.start();
            int exitCode = process.waitFor();
            System.exit(exitCode);
        } catch (Exception e) {
            System.err.println("Failed to execute worker: " + e.getMessage());
            System.exit(1);
        }
    }
}
