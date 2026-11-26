// abstraction-provenance: {"artifact_sha256": "f5464a14eb8117856bd3e56aa0812dcd94e7daa0eeee3a50a3f408515302e684", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "java"}
// server-maintenance.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
// auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
// auch in: workspace@local:scripts/server-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Scanner;

public class ServerMaintenance {

    private static final String LOG_FILE = "/var/log/server-maintenance.log";
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    
    // Farben für Terminal (ANSI Escape Codes)
    private static final String RED = "\033[0;31m";
    private static final String GREEN = "\033[0;32m";
    private static final String YELLOW = "\033[1;33m";
    private static final String NC = "\033[0m";

    public static void main(String[] args) {
        String date = LocalDateTime.now().format(DATE_FORMAT);
        String host = System.getenv("HOSTNAME");
        if (host == null) {
            host = "unknown";
        }

        logMessage(date, "=== Server Maintenance Check ===");

        // 1. APT Update Check
        logMessage(date, "Checking for updates...");
        try {
            Process aptUpdate = Runtime.getRuntime().exec(new String[]{"apt", "update", "-qq"});
            BufferedReader reader = new BufferedReader(new InputStreamReader(aptUpdate.getErrorStream()));
            String line;
            int lines = 0;
            while ((line = reader.readLine()) != null && lines < 5) {
                logMessage(date, line);
                lines++;
            }
            aptUpdate.waitFor();
            
            Process aptList = Runtime.getRuntime().exec(new String[]{"apt", "list", "--upgradable"});
            Scanner scanner = new Scanner(new InputStreamReader(aptList.getInputStream()));
            int updates = 0;
            while (scanner.hasNextLine()) {
                scanner.nextLine();
                updates++;
            }
            scanner.close();
            aptList.waitFor();
            
            if (updates > 1) {
                logMessage(date, "⚠️ " + (updates - 1) + " packages can be upgraded");
            }
        } catch (Exception e) {
            logMessage(date, "Error checking updates: " + e.getMessage());
        }

        // 2. RAM Check (8GB total)
        logMessage(date, "Checking RAM usage...");
        try {
            Process freeProcess = Runtime.getRuntime().exec(new String[]{"free", "-m"});
            BufferedReader reader = new BufferedReader(new InputStreamReader(freeProcess.getInputStream()));
            String memLine = "";
            while ((line = reader.readLine()) != null) {
                if (line.startsWith("Mem:")) {
                    memLine = line;
                    break;
                }
            }
            freeProcess.waitFor();
            
            if (!memLine.isEmpty()) {
                String[] parts = memLine.trim().split("\\s+");
                int ramUsed = Integer.parseInt(parts[2]);
                int ramTotal = 8192; // 8GB in MB
                int ramPercent = (ramUsed * 100) / ramTotal;
                
                logMessage(date, "RAM: " + ramUsed + "MB / " + ramTotal + "MB (" + ramPercent + "%)");
                
                if (ramPercent > 90) {
                    logMessage(date, "🔴 WARNING: RAM usage > 90%!");
                } else if (ramPercent > 80) {
                    logMessage(date, "🟡 WARNING: RAM usage > 80%");
                }
            }
        } catch (Exception e) {
            logMessage(date, "Error checking RAM: " + e.getMessage());
        }

        // 3. Disk Space Check
        logMessage(date, "Checking disk space...");
        try {
            Process dfProcess = Runtime.getRuntime().exec(new String[]{"df", "-h", "/"});
            BufferedReader reader = new BufferedReader(new InputStreamReader(dfProcess.getInputStream()));
            String dfLine = "";
            while ((line = reader.readLine()) != null) {
                if (!line.startsWith("Filesystem")) {
                    dfLine = line;
                    break;
                }
            }
            dfProcess.waitFor();
            
            if (!dfLine.isEmpty()) {
                String[] parts = dfLine.trim().split("\\s+");
                String used = parts[2];
                String total = parts[1];
                String percent = parts[4];
                logMessage(date, "Disk: " + used + " / " + total + " (" + percent + " used)");
                
                int diskPercent = Integer.parseInt(percent.replace("%", ""));
                if (diskPercent > 90) {
                    logMessage(date, "🔴 WARNING: Disk > 90%!");
                } else if (diskPercent > 80) {
                    logMessage(date, "🟡 WARNING: Disk > 80%");
                }
            }
        } catch (Exception e) {
            logMessage(date, "Error checking disk space: " + e.getMessage());
        }

        // 4. NTP Check
        logMessage(date, "Checking NTP sync...");
        try {
            Process ntpProcess = Runtime.getRuntime().exec(new String[]{"timedatectl", "status"});
            BufferedReader reader = new BufferedReader(new InputStreamReader(ntpProcess.getInputStream()));
            boolean synced = false;
            while ((line = reader.readLine()) != null) {
                if (line.contains("NTP synchronized: yes")) {
                    synced = true;
                    break;
                }
            }
            ntpProcess.waitFor();
            
            if (synced) {
                logMessage(date, "✅ NTP synchronized");
            } else {
                logMessage(date, "⚠️ NTP not synchronized");
            }
        } catch (Exception e) {
            logMessage(date, "Error checking NTP: " + e.getMessage());
        }

        // 5. OpenClaw Gateway Status
        logMessage(date, "Checking OpenClaw Gateway...");
        try {
            Process statusProcess = Runtime.getRuntime().exec(new String[]{"systemctl", "is-active", "--quiet", "openclaw-gateway"});
            int exitCode = statusProcess.waitFor();
            
            if (exitCode == 0) {
                logMessage(date, "✅ OpenClaw Gateway running");
            } else {
                logMessage(date, "🔴 OpenClaw Gateway NOT running!");
                Process restartProcess = Runtime.getRuntime().exec(new String[]{"systemctl", "restart", "openclaw-gateway"});
                restartProcess.waitFor();
            }
        } catch (Exception e) {
            logMessage(date, "Error checking OpenClaw Gateway: " + e.getMessage());
        }

        // 6. Load Average
        try {
            Process uptimeProcess = Runtime.getRuntime().exec(new String[]{"uptime"});
            BufferedReader reader = new BufferedReader(new InputStreamReader(uptimeProcess.getInputStream()));
            String uptimeLine = reader.readLine();
            uptimeProcess.waitFor();
            
            if (uptimeLine != null) {
                String[] parts = uptimeLine.split("load average:");
                if (parts.length > 1) {
                    String loadPart = parts[1].trim().split(",")[0].replace(",", "");
                    logMessage(date, "Load Average: " + loadPart);
                }
            }
        } catch (Exception e) {
            logMessage(date, "Error getting load average: " + e.getMessage());
        }

        logMessage(date, "=== Maintenance Complete ===");
        logMessage(date, "");
    }

    private static void logMessage(String date, String message) {
        String logEntry = "[" + date + "] " + message;
        System.out.println(logEntry);
        
        try (PrintWriter writer = new PrintWriter(new FileWriter(LOG_FILE, true))) {
            writer.println(logEntry);
        } catch (IOException e) {
            System.err.println("Failed to write to log file: " + e.getMessage());
        }
    }
}
