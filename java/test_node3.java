// abstraction-provenance: {"artifact_sha256": "066af37dcca78af8d11d189d79a0968d5fcb78804e5293778953f9b784d5d83b", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "java"}
// test_node3.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
// auch in: OpenClaw@gateway2:scripts/test_node3.sh
// auch in: workspace@local:scripts/test_node3.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.concurrent.TimeUnit;

public class TestNode3 {
    public static void main(String[] args) {
        // Test Node 3 Connection
        System.setProperty("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", "1");
        System.out.println("Starting node connection test...");
        
        ProcessBuilder processBuilder = new ProcessBuilder();
        processBuilder.command("/usr/local/bin/openclaw", "node", "run", "--host", "152.53.145.65", "--port", "18789");
        
        try {
            Process process = processBuilder.start();
            
            // Create a thread to consume the process output
            Thread outputThread = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        System.out.println(line);
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });
            
            Thread errorThread = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        System.err.println(line);
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });
            
            outputThread.start();
            errorThread.start();
            
            // Wait for the process to complete or timeout after 15 seconds
            boolean finished = process.waitFor(15, TimeUnit.SECONDS);
            
            if (!finished) {
                process.destroyForcibly();
                System.out.println("Process timed out and was terminated");
            }
            
            // Wait for output threads to finish
            outputThread.join();
            errorThread.join();
            
            int exitCode = process.exitValue();
            System.out.println("Exit code: " + exitCode);
            
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}
