// abstraction-provenance: {"artifact_sha256": "b2de2c6c8563a5aca645262b2c93c9b3714b482558705d0e866bd30d5db014c9", "source_sha256": "86aad5ae0d9b77ebdb9a2aaecbf0c4875ad3a241571b573934c882ecd55df14e", "target_language": "java"}
// node_health.py — portiert nach java
// Quelle: python, workspace@local:git/skills/node-health-monitor/scripts/node_health.py
// auch in: workspace@local:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.*;

public class NodeHealthMonitor {
    // Konfiguration
    private static final Path WORKSPACE = Paths.get(System.getProperty("user.home"), ".openclaw", "workspace");
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
        node2.put("name", "Node2");
        node2.put("host", "100.82.198.122");
        node2.put("user", "root");
        node2.put("ssh_key", "/root/.ssh/id_ed25519_openclaw_admin");
        NODES.put("node2", node2);

        Map<String, Object> node3 = new HashMap<>();
        node3.put("name", "Node3");
        node3.put("host", "100.73.154.125");
        node3.put("user", "root");
        node3.put("disk_warning", 85);
        NODES.put("node3", node3);

        Map<String, Object> node4 = new HashMap<>();
        node4.put("name", "Redmi");
        node4.put("host", "100.94.134.39");
        node4.put("optional", true);
        node4.put("ssh_enabled", false);
        NODES.put("node4", node4);

        Map<String, Object> node5 = new HashMap<>();
        node5.put("name", "Lenovo");
        node5.put("host", "100.103.140.35");
        node5.put("optional", true);
        node5.put("ssh_enabled", false);
        NODES.put("node5", node5);
    }

    public static void log(String message, String level) {
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
        try {
            ProcessBuilder pb = new ProcessBuilder("ping", "-c", "1", "-W", String.valueOf(timeout), host);
            Process process = pb.start();
            return process.waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean checkSSH(Map<String, Object> nodeConfig) {
        if (!(Boolean) nodeConfig.getOrDefault("ssh_enabled", true)) {
            return false;
        }
        
        String host = (String) nodeConfig.get("host");
        String user = (String) nodeConfig.getOrDefault("user", "root");
        
        List<String> cmd = new ArrayList<>();
        cmd.add("ssh");
        cmd.add("-o");
        cmd.add("ConnectTimeout=10");
        cmd.add("-o");
        cmd.add("BatchMode=yes");
        
        if (nodeConfig.containsKey("ssh_key")) {
            String sshKey = (String) nodeConfig.get("ssh_key");
            cmd.add("-i");
            cmd.add(Paths.get(sshKey).toAbsolutePath().toString());
            cmd.add("-o");
            cmd.add("IdentitiesOnly=yes");
        }
        
        cmd.add(user + "@" + host);
        cmd.add("echo OK");
        
        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            Process process = pb.start();
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                StringBuilder output = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
                return output.toString().contains("OK");
            }
        } catch (Exception e) {
            return false;
        }
        
        return false;
    }

    public static Map<String, Object> getNodeMetrics(Map<String, Object> nodeConfig) {
        Map<String, Object> metrics = new HashMap<>();
        metrics.put("timestamp", LocalDateTime.now().toString());
        metrics.put("available", false);
        metrics.put("cpu", null);
        metrics.put("ram", null);
        metrics.put("disk", null);
        metrics.put("load", null);
        
        if (!(Boolean) nodeConfig.getOrDefault("ssh_enabled", true)) {
            return metrics;
        }
        
        String host = (String) nodeConfig.get("host");
        String user = (String) nodeConfig.getOrDefault("user", "root");
        
        String remoteCmd = String.join("\n",
            "# CPU",
            "echo \"CPU:$(top -bn1 | grep \\\"Cpu(s)\\\" | awk '{print $2}' | cut -d\\\"%\\\" -f1)\"",
            "",
            "# RAM",
            "echo \"RAM:$(free | grep Mem | awk '{print ($3/$2) * 100.0}')\"",
            "",
            "# Disk",
            "echo \"DISK:$(df -h / | tail -1 | awk '{print $5}' | tr -d \\\"%\\\")\"",
            "",
            "# Load",
            "echo \"LOAD:$(uptime | awk -F\\\"load average:\\\" \\\"{print $2}\\\" | awk '{print $1}' | tr -d \\\",\\\")\"",
            "",
            "# Gateway Status",
            "if command -v openclaw >/dev/null 2>&1; then",
            "    printf \\\"GATEWAY:%s\\\\n\\\" \\\"$(systemctl is-active openclaw-gateway 2>/dev/null || true)\\\"",
            "fi"
        );
        
        List<String> cmd = new ArrayList<>();
        cmd.add("ssh");
        cmd.add("-o");
        cmd.add("ConnectTimeout=10");
        cmd.add("-o");
        cmd.add("BatchMode=yes");
        
        if (nodeConfig.containsKey("ssh_key")) {
            String sshKey = (String) nodeConfig.get("ssh_key");
            cmd.add("-i");
            cmd.add(Paths.get(sshKey).toAbsolutePath().toString());
            cmd.add("-o");
            cmd.add("IdentitiesOnly=yes");
        }
        
        cmd.add(user + "@" + host);
        cmd.add(remoteCmd);
        
        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            Process process = pb.start();
            
            ExecutorService executor = Executors.newSingleThreadExecutor();
            Future<String> future = executor.submit(() -> {
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                StringBuilder output = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
                return output.toString();
            });
            
            String output = future.get(15, TimeUnit.SECONDS);
            process.waitFor();
            
            if (process.exitValue() == 0) {
                metrics.put("available", true);
                
                String[] lines = output.trim().split("\n");
                for (String line : lines) {
                    if (line.contains(":")) {
                        String[] parts = line.split(":", 2);
                        String key = parts[0];
                        String value = parts.length > 1 ? parts[1] : "";
                        
                        switch (key) {
                            case "CPU":
                                if (!value.isEmpty()) {
                                    metrics.put("cpu", Double.parseDouble(value));
                                }
                                break;
                            case "RAM":
                                if (!value.isEmpty()) {
                                    metrics.put("ram", Double.parseDouble(value));
                                }
                                break;
                            case "DISK":
                                if (!value.isEmpty()) {
                                    metrics.put("disk", Integer.parseInt(value));
                                }
                                break;
                            case "LOAD":
                                if (!value.isEmpty()) {
                                    metrics.put("load", Double.parseDouble(value));
                                }
                                break;
                            case "GATEWAY":
                                metrics.put("gateway_status", value);
                                break;
                        }
                    }
                }
            }
        } catch (TimeoutException e) {
            log("SSH timeout for " + nodeConfig.get("name"), "WARN");
        } catch (Exception e) {
            log("Error checking " + nodeConfig.get("name") + ": " + e.getMessage(), "ERROR");
        }
        
        return metrics;
    }

    public static List<Map<String, Object>> checkAlerts(String nodeId, Map<String, Object> nodeConfig, Map<String, Object> metrics) {
        List<Map<String, Object>> alerts = new ArrayList<>();
        
        Boolean available = (Boolean) metrics.get("available");
        if (available != null && !available) {
            Boolean optional = (Boolean) nodeConfig.getOrDefault("optional", false);
            if (!optional) {
                Map<String, Object> alert = new HashMap<>();
                alert.put("level", "CRITICAL");
                alert.put("message", "Node " + nodeConfig.get("name") + " nicht erreichbar!");
                alerts.add(alert);
            }
        } else {
            Double cpu = (Double) metrics.get("cpu");
            if (cpu != null && cpu > 90) {
                Map<String, Object> alert = new HashMap<>();
                alert.put("level", "WARNING");
                alert.put("message", "Node " + nodeConfig.get("name") + ": CPU bei " + String.format("%.1f", cpu) + "%");
                alerts.add(alert);
            }
            
            Double ram = (Double) metrics.get("ram");
            if (ram != null && ram > 90) {
                Map<String, Object> alert = new HashMap<>();
                alert.put("level", "WARNING");
                alert.put("message", "Node " + nodeConfig.get("name") + ": RAM bei " + String.format("%.1f", ram) + "%");
                alerts.add(alert);
            }
            
            Integer disk = (Integer) metrics.get("disk");
            if (disk != null) {
                int diskThreshold = (Integer) nodeConfig.getOrDefault("disk_warning", 85);
                if (disk > diskThreshold) {
                    String level = disk > 95 ? "CRITICAL" : "WARNING";
                    Map<String, Object> alert = new HashMap<>();
                    alert.put("level", level);
                    alert.put("message", "Node " + nodeConfig.get("name") + ": Disk bei " + disk + "%");
                    alerts.add(alert);
                }
            }
            
            Boolean critical = (Boolean) nodeConfig.get("critical");
            String gatewayStatus = (String) metrics.get("gateway_status");
            if (critical != null && critical && "inactive".equals(gatewayStatus)) {
                Map<String, Object> alert = new HashMap<>();
                alert.put("level", "CRITICAL");
                alert.put("message", "Node " + nodeConfig.get("name") + ": OpenClaw Gateway nicht aktiv!");
                alerts.add(alert);
            }
        }
        
        return alerts;
    }

    public static void sendAlert(Map<String, Object> alert) {
        try {
            String scriptPath = WORKSPACE.resolve("skills/channel-status-agent/scripts/channel_status.py").toString();
            String level = (String) alert.get("level");
            String message = (String) alert.get("message");
            
            ProcessBuilder pb = new ProcessBuilder(
                "python3",
                scriptPath,
                "--type", "alert",
                "--message", level + ": " + message
            );
            pb.start();
            log("Alert sent: " + message, "INFO");
        } catch (Exception e) {
            log("Failed to send alert: " + e.getMessage(), "ERROR");
        }
    }

    public static void main(String[] args) {
        String nodeArg = "all";
        String checkArg = "all";
        boolean alertFlag = false;
        
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--node":
                    if (i + 1 < args.length) {
                        nodeArg = args[++i];
                    }
                    break;
                case "--check":
                    if (i + 1 < args.length) {
                        checkArg = args[++i];
                    }
                    break;
                case "--alert":
                    alertFlag = true;
                    break;
            }
        }
        
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
        
        List<Map<String, Object>> allAlerts = new ArrayList<>();
        
        for (Map.Entry<String, Map<String, Object>> entry : nodesToCheck) {
            String nodeId = entry.getKey();
            Map<String, Object> nodeConfig = entry.getValue();
            String nodeName = (String) nodeConfig.get("name");
            
            log("Checking " + nodeName + " (" + nodeId + ")", "INFO");
            
            if (Arrays.asList("ping", "all").contains(checkArg)) {
                String host = (String) nodeConfig.get("host");
                if (!"localhost".equals(host)) {
                    boolean pingOk = checkPing(host, 5);
                    log("  Ping: " + (pingOk ? "OK" : "FAILED"), "INFO");
                }
            }
            
            if (Arrays.asList("ssh", "all").contains(checkArg)) {
                Boolean sshEnabled = (Boolean) nodeConfig.getOrDefault("ssh_enabled", true);
                if (!sshEnabled) {
                    log("  SSH: SKIPPED (nicht konfiguriert)", "INFO");
                } else {
                    boolean sshOk = checkSSH(nodeConfig);
                    log("  SSH: " + (sshOk ? "OK" : "FAILED"), "INFO");
                }
            }
            
            if (Arrays.asList("metrics", "all").contains(checkArg)) {
                Map<String, Object> metrics = getNodeMetrics(nodeConfig);
                Boolean available = (Boolean) metrics.get("available");
                
                if (available != null && available) {
                    Double cpu = (Double) metrics.get("cpu");
                    if (cpu != null) {
                        log("  CPU: " + String.format("%.1f", cpu) + "%", "INFO");
                    } else {
                        log("  CPU: N/A", "INFO");
                    }
                    
                    Double ram = (Double) metrics.get("ram");
                    if (ram != null) {
                        log("  RAM: " + String.format("%.1f", ram) + "%", "INFO");
                    } else {
                        log("  RAM: N/A", "INFO");
                    }
                    
                    Integer disk = (Integer) metrics.get("disk");
                    if (disk != null) {
                        log("  Disk: " + disk + "%", "INFO");
                    } else {
                        log("  Disk: N/A", "INFO");
                    }
                    
                    Double load = (Double) metrics.get("load");
                    if (load != null) {
                        log("  Load: " + load, "INFO");
                    } else {
                        log("  Load: N/A", "INFO");
                    }
                } else {
                    log("  Metrics: UNAVAILABLE", "INFO");
                }
                
                List<Map<String, Object>> alerts = checkAlerts(nodeId, nodeConfig, metrics);
                allAlerts.addAll(alerts);
            }
        }
        
        if (alertFlag && !allAlerts.isEmpty()) {
            log("\nSending " + allAlerts.size() + " alerts...", "INFO");
            for (Map<String, Object> alert : allAlerts) {
                sendAlert(alert);
            }
        } else if (!allAlerts.isEmpty()) {
            log("\n" + allAlerts.size() + " alerts found (use --alert to send)", "INFO");
        } else {
            log("\nPrüfung abgeschlossen; Details und nicht verfügbare Prüfungen siehe oben.", "INFO");
        }
    }
}
