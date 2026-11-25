// abstraction-provenance: {"artifact_sha256": "230e4c08a986dfeb7d014c648a16bcd344f2e0e09c6dd4c374a8453f54193504", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "java"}
// translation-worker-node5.ps1 — portiert nach java
// Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;

public class TranslationWorkerNode5 {
    private static final String ACTION_PREPARE = "prepare";
    private static final String ACTION_RUN = "run";
    private static final String EXPECTED_HASH = "9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b";
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: TranslationWorkerNode5 <prepare|run>");
            System.exit(1);
        }
        
        String action = args[0];
        if (!ACTION_PREPARE.equals(action) && !ACTION_RUN.equals(action)) {
            System.err.println("Action must be either 'prepare' or 'run'");
            System.exit(1);
        }
        
        try {
            // Windows does not use chmod. The Python worker and Python 3 must already be
            // installed locally; no credentials are copied or placed on a command line.
            Path userHome = Paths.get(System.getProperty("user.home"));
            Path worker = userHome.resolve(".openclaw/workers/translation_worker.py");
            
            // Check if worker exists
            if (!Files.exists(worker) || !Files.isRegularFile(worker)) {
                throw new RuntimeException("Worker missing: " + worker.toString());
            }
            
            // Check if it's a symbolic link (reparse point equivalent)
            if (Files.isSymbolicLink(worker)) {
                throw new RuntimeException("Worker link rejected");
            }
            
            // Verify checksum
            String fileHash = getFileHash(worker);
            if (!EXPECTED_HASH.equals(fileHash)) {
                throw new RuntimeException("Worker checksum mismatch");
            }
            
            // Find python executable
            String pythonPath = findPythonExecutable();
            
            if (ACTION_PREPARE.equals(action)) {
                System.out.println("Worker verified: " + worker.toString());
                System.exit(0);
            }
            
            // Run the worker
            ProcessBuilder processBuilder = new ProcessBuilder(pythonPath, worker.toString());
            processBuilder.inheritIO();
            Process process = processBuilder.start();
            int exitCode = process.waitFor();
            System.exit(exitCode);
            
        } catch (Exception e) {
            System.err.println(e.getMessage());
            System.exit(1);
        }
    }
    
    private static String getFileHash(Path filePath) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream fis = Files.newInputStream(filePath)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                digest.update(buffer, 0, bytesRead);
            }
        }
        byte[] hashBytes = digest.digest();
        StringBuilder sb = new StringBuilder();
        for (byte b : hashBytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString().toLowerCase();
    }
    
    private static String findPythonExecutable() {
        // Try common python executable names
        String[] pythonCommands = {"python.exe", "python3.exe", "python"};
        
        // Check PATH environment variable
        String pathEnv = System.getenv("PATH");
        if (pathEnv != null) {
            String[] paths = pathEnv.split(File.pathSeparator);
            for (String pythonCmd : pythonCommands) {
                for (String path : paths) {
                    Path pythonPath = Paths.get(path, pythonCmd);
                    if (Files.exists(pythonPath) && Files.isExecutable(pythonPath)) {
                        return pythonPath.toString();
                    }
                }
            }
        }
        
        // Also check some common installation locations on Windows
        String[] commonPaths = {
            "C:\\Python39\\python.exe",
            "C:\\Python38\\python.exe",
            "C:\\Python37\\python.exe",
            "C:\\Users\\" + System.getProperty("user.name") + "\\AppData\\Local\\Programs\\Python\\Python39\\python.exe",
            "C:\\Users\\" + System.getProperty("user.name") + "\\AppData\\Local\\Programs\\Python\\Python38\\python.exe"
        };
        
        for (String path : commonPaths) {
            Path pythonPath = Paths.get(path);
            if (Files.exists(pythonPath) && Files.isExecutable(pythonPath)) {
                return pythonPath.toString();
            }
        }
        
        throw new RuntimeException("Could not find python executable");
    }
}
