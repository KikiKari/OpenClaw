// abstraction-provenance: {"artifact_sha256": "fb39e2414677b80aa199b4127d35cb04e4a1ae5f7516cdb60c809b9fe3e39458", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "java"}
// node_health.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * Node Health Monitor - Multi-Node Gesundheitsüberwachung
 */
public class NodeHealthMonitor {
    
    // Konfiguration
    private static final Path WORKSPACE = Paths.get(System.getProperty("user.home"), ".openclaw/workspace");
    private static final Path HEALTH_DB = WORKSPACE.resolve("db/health.db");
    private static final Path LOG_FILE = WORKSPACE.resolve("logs/node-health.log");
    
    // Node-Definitionen
    private static final Map<String, Map<String, Object>> NODES = new HashMap<>();
    
    static {
        Map<String, Object> node1 = new HashMap<>();
        node1.put("name", "Gateway");
        node1.put("host", "localhost");
        node1.put("user", "openclaw");
        node1.put("critical", true);
        NODES.put("node1", node1);
        
        Map<String, Object> node2 = new HashMap<>();
        node2.put("name", "Worker");
        node2.put("host", "100.92.155.34");
        node2.put("user", "root");
        node2.put("ssh_key", "~/.ssh/id_rsa");
        NODES.put("node2", node2);
        
        Map<String, Object> node3 = new HashMap<>();
        node3.put("name", "Relay");
        node3.put("host", "185.242.xxx.xxx");
        node3.put("user", "root");
        node3.put("disk_warning", 85);
        NODES.put("node3", node3);
        
        Map<String, Object> node5 = new HashMap<>();
        node5.put("name", "Redmi");
        node5.put("host", "192.168.1.x");
        node5.put("user", "openclaw");
        node5.put("optional", true);
        NODES.put("node5", node5);
    }
    
    public static void log(String message, String level) {
        /** Logging */
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        String entry = String.format("[%s] [%s] %s", timestamp, level, message);
        System.out.println(entry);
        
        try {
            Files.createDirectories(LOG_FILE.getParent());
            Files.write(LOG_FILE, (entry + "\n").getBytes(), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException e) {
            System.err.println("Failed to write to log file: " + e.getMessage());
        }
    }
    
    public static boolean checkPing(String host, int timeout) {
        /** Prüft Erreichbarkeit */
        try {
            Process process = new ProcessBuilder("ping", "-c", "1", "-W", String.valueOf(timeout), host).start();
            return process.waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }
    
    public static boolean checkSSH(Map<String, Object> nodeConfig) {
        /** Prüft SSH-Verbindung */
        String host = (String) nodeConfig.get("host");
        String user = (String) nodeConfig.getOrDefault("user", "root");
        
        try {
            Process process = new ProcessBuilder("ssh", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes",
                    user + "@" + host, "echo \"OK\"").start();
            int result = process.waitFor();
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder output = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line);
            }
            
            return result == 0 && output.toString().contains("OK");
        } catch (Exception e) {
            return false;
        }
    }
    
    public static Map<String, Object> getNodeMetrics(Map<String, Object> nodeConfig) {
        /** Holt Metriken via SSH */
        String host = (String) nodeConfig.get("host");
        String user = (String) nodeConfig.getOrDefault("user", "root");
        
        Map<String, Object> metrics = new HashMap<>();
        metrics.put("timestamp", LocalDateTime.now().toString());
        metrics.put("available", false);
        metrics.put("cpu", null);
        metrics.put("ram", null);
        metrics.put("disk", null);
        metrics.put("load", null);
        
        String cmd = String.format("ssh -o ConnectTimeout=10 %s@%s '\n" +
                "# CPU\n" +
                "echo \"CPU:$(top -bn1 | grep \\\"Cpu(s)\\\" | awk \\\"{print \\\\$2}\\\" | cut -d\\\"%%\\\" -f1)\"\n" +
                "\n" +
                "# RAM\n" +
                "echo \"RAM:$(free | grep Mem | awk \\\"{print (\\\$3/\\\$2) * 100.0}\\\")\"\n" +
                "\n" +
                "# Disk\n" +
                "echo \"DISK:$(df -h / | tail -1 | awk \\\"{print \\\\$5}\\\" | tr -d \\\"%%%%\\\")\"\n" +
                "\n" +
                "# Load\n" +
                "echo \"LOAD:$(uptime | awk -F\\\"load average:\\\" \\\"{print \\\\$2}\\\" | awk \\\"{print \\\\$1}\\\" | tr -d \\\",\\\")\"\n" +
                "\n" +
                "# Gateway Status\n" +
                "if command -v openclaw >/dev/null 2>&1; then\n" +
                "    systemctl is-active openclaw-gateway 2>/dev/null || echo \"GATEWAY:inactive\"\n" +
                "fi\n" +
                "'", user, host);
        
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"/bin/sh", "-c", cmd});
            if (!process.waitFor(15, TimeUnit.SECONDS)) {
                process.destroyForcibly();
                log("SSH timeout for " + nodeConfig.get("name"), "WARN");
                return metrics;
            }
            
            if (process.exitValue() == 0) {
                metrics.put("available", true);
                
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains(":")) {
                        String[] parts = line.split(":", 2);
                        String key = parts[0];
                        String value = parts[1];
                        
                        switch (key) {
                            case "CPU":
                                metrics.put("cpu", Double.parseDouble(value));
                                break;
                            case "RAM":
                                metrics.put("ram", Double.parseDouble(value));
                                break;
                            case "DISK":
                                metrics.put("disk", Integer.parseInt(value));
                                break;
                            case "LOAD":
                                metrics.put("load", Double.parseDouble(value));
                                break;
                            case "GATEWAY":
                                metrics.put("gateway_status", value);
                                break;
                        }
                    }
                }
            }
        } catch (Exception e) {
            log("Error checking " + nodeConfig.get("name") + ": " + e.getMessage(), "ERROR");
        }
        
        return metrics;
    }
    
    public static List<Map<String, String>> checkAlerts(String nodeId, Map<String, Object> nodeConfig, Map<String, Object> metrics) {
        /** Prüft Schwellwerte und generiert Alerts */
        List<Map<String, String>> alerts = new ArrayList<>();
        
        // Verfügbarkeit
        if (!(Boolean) metrics.get("available")) {
            if (!(Boolean) nodeConfig.getOrDefault("optional", false)) {
                Map<String, String> alert = new HashMap<>();
                alert.put("level", "CRITICAL");
                alert.put("message", "Node " + nodeConfig.get("name") + " nicht erreichbar!");
                alerts.add(alert);
            }
        } else {
            // CPU
            if (metrics.get("cpu") != null && (Double) metrics.get("cpu") > 90) {
                Map<String, String> alert = new HashMap<>();
                alert.put("level", "WARNING");
                alert.put("message", "Node " + nodeConfig.get("name") + ": CPU bei " + String.format("%.1f", metrics.get("cpu")) + "%");
                alerts.add(alert);
            }
            
            // RAM
            if (metrics.get("ram") != null && (Double) metrics.get("ram") > 90) {
                Map<String, String> alert = new HashMap<>();
                alert.put("level", "WARNING");
                alert.put("message", "Node " + nodeConfig.get("name") + ": RAM bei " + String.format("%.1f", metrics.get("ram")) + "%");
                alerts.add(alert);
            }
            
            // Disk
            int diskThreshold = (Integer) nodeConfig.getOrDefault("disk_warning", 85);
            if (metrics.get("disk") != null && (Integer) metrics.get("disk") > diskThreshold) {
                String level = (Integer) metrics.get("disk") > 95 ? "CRITICAL" : "WARNING";
                Map<String, String> alert = new HashMap<>();
                alert.put("level", level);
                alert.put("message", "Node " + nodeConfig.get("name") + ": Disk bei " + metrics.get("disk") + "%");
                alerts.add(alert);
            }
            
            // Gateway
            if (Boolean.TRUE.equals(nodeConfig.get("critical")) && "inactive".equals(metrics.get("gateway_status"))) {
                Map<String, String> alert = new HashMap<>();
                alert.put("level", "CRITICAL");
                alert.put("message", "Node " + nodeConfig.get("name") + ": OpenClaw Gateway nicht aktiv!");
                alerts.add(alert);
            }
        }
        
        return alerts;
    }
    
    public static void sendAlert(Map<String, String> alert) {
        /** Sendet Alert via channel-status-agent */
        try {
            Process process = new ProcessBuilder(
                    "python3",
                    WORKSPACE.resolve("skills/channel-status-agent/scripts/channel_status.py").toString(),
                    "--type", "alert",
                    "--message", alert.get("level") + ": " + alert.get("message")
            ).start();
            process.waitFor();
            log("Alert sent: " + alert.get("message"), "INFO");
        } catch (Exception e) {
            log("Failed to send alert: " + e.getMessage(), "ERROR");
        }
    }
    
    public static void main(String[] args) {
        /** Hauptfunktion */
        String nodeArg = "all";
        String checkArg = "all";
        boolean alertFlag = false;
        
        // Argumente parsen (vereinfachte Version)
        for (int i = 0; i < args.length; i++) {
            if ("--node".equals(args[i]) && i + 1 < args.length) {
                nodeArg = args[++i];
            } else if ("--check".equals(args[i]) && i + 1 < args.length) {
                checkArg = args[++i];
            } else if ("--alert".equals(args[i])) {
                alertFlag = true;
            }
        }
        
        // Nodes bestimmen
        Set<Map.Entry<String, Map<String, Object>>> nodesToCheck;
        if ("all".equals(nodeArg)) {
            nodesToCheck = NODES.entrySet();
        } else {
            if (NODES.containsKey(nodeArg)) {
                nodesToCheck = Collections.singletonMap(nodeArg, NODES.get(nodeArg)).entrySet();
            } else {
                log("Unknown node: " + nodeArg, "ERROR");
                System.exit(1);
                return;
            }
        }
        
        // Health-Checks durchführen
        List<Map<String, String>> allAlerts = new ArrayList<>();
        
        for (Map.Entry<String, Map<String, Object>> entry : nodesToCheck) {
            String nodeId = entry.getKey();
            Map<String, Object> nodeConfig = entry.getValue();
            log("Checking " + nodeConfig.get("name") + " (" + nodeId + ")", "INFO");
            
            // Ping
            if ("ping".equals(checkArg) || "all".equals(checkArg)) {
                if (!"localhost".equals(nodeConfig.get("host"))) {
                    boolean pingOk = checkPing((String) nodeConfig.get("host"), 5);
                    log("  Ping: " + (pingOk ? "OK" : "FAILED"), "INFO");
                }
            }
            
            // SSH
            if ("ssh".equals(checkArg) || "all".equals(checkArg)) {
                boolean sshOk = checkSSH(nodeConfig);
                log("  SSH: " + (sshOk ? "OK" : "FAILED"), "INFO");
            }
            
            // Metriken
            if ("metrics".equals(checkArg) || "all".equals(checkArg)) {
                Map<String, Object> metrics = getNodeMetrics(nodeConfig);
                
                if ((Boolean) metrics.get("available")) {
                    log("  CPU: " + (metrics.get("cpu") != null ? String.format("%.1f", (Double) metrics.get("cpu")) + "%" : "N/A"), "INFO");
                    log("  RAM: " + (metrics.get("ram") != null ? String.format("%.1f", (Double) metrics.get("ram")) + "%" : "N/A"), "INFO");
                    log("  Disk: " + (metrics.get("disk") != null ? metrics.get("disk") + "%" : "N/A"), "INFO");
                    log("  Load: " + (metrics.get("load") != null ? metrics.get("load").toString() : "N/A"), "INFO");
                } else {
                    log("  Metrics: UNAVAILABLE", "INFO");
                }
                
                // Alerts prüfen
                List<Map<String, String>> alerts = checkAlerts(nodeId, nodeConfig, metrics);
                allAlerts.addAll(alerts);
            }
        }
        
        // Alerts senden
        if (alertFlag && !allAlerts.isEmpty()) {
            log("\nSending " + allAlerts.size() + " alerts...", "INFO");
            for (Map<String, String> alert : allAlerts) {
                sendAlert(alert);
            }
        } else if (!allAlerts.isEmpty()) {
            log("\n" + allAlerts.size() + " alerts found (use --alert to send)", "INFO");
        } else {
            log("\nAll nodes healthy!", "INFO");
        }
    }
}
