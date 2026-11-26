// abstraction-provenance: {"artifact_sha256": "1dd95f33a62c967e831bae90e03ced25f8fe420e8d154c65d4e58f19709acb07", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "java"}
// node_health.py — portiert nach java
// Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
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
    private static final Path WORKSPACE = Paths.get(System.getProperty("user.home"), ".openclaw", "workspace");
    private static final Path HEALTH_DB = WORKSPACE.resolve("db/health.db");
    private static final Path LOG_FILE = WORKSPACE.resolve("logs/node-health.log");

    // Node-Definitionen
    private static final Map<String, Map<String, Object>> NODES = new HashMap<>();

    static {
        Map<String, Object> node1 = new HashMap<>();
        node1.put("name", "Node 1");
        node1.put("host", "localhost");
        node1.put("user", "openclaw");
        node1.put("critical", true);
        NODES.put("node1", node1);

        Map<String, Object> node2 = new HashMap<>();
        node2.put("name", "Node 2");
        node2.put("host", "10.10.0.2");
        node2.put("user", "root");
        node2.put("ssh_key", "~/.ssh/id_rsa");
        node2.put("ssh_opts", "-o ConnectTimeout=10 -o BatchMode=yes");
        NODES.put("node2", node2);

        Map<String, Object> node3 = new HashMap<>();
        node3.put("name", "Node 3");
        node3.put("host", "localhost");
        node3.put("user", "root");
        node3.put("port", 18794);
        node3.put("ssh_opts", "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes");
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
            Process process = new ProcessBuilder("ping", "-c", "1", "-W", String.valueOf(timeout), host).start();
            return process.waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean checkSSH(Map<String, Object> nodeConfig) {
        String host = (String) nodeConfig.get("host");
        String user = (String) nodeConfig.getOrDefault("user", "root");
        String sshOpts = (String) nodeConfig.getOrDefault("ssh_opts", "");
        Integer port = (Integer) nodeConfig.get("port");

        List<String> cmd = new ArrayList<>();
        cmd.add("ssh");
        
        if (!sshOpts.isEmpty()) {
            cmd.addAll(Arrays.asList(sshOpts.split("\\s+")));
        }
        
        if (port != null) {
            cmd.add("-p");
            cmd.add(String.valueOf(port));
        }
        
        cmd.addAll(Arrays.asList("-o", "ConnectTimeout=10", "-o", "BatchMode=yes"));
        cmd.add(user + "@" + host);
        cmd.add("echo");
        cmd.add("\"OK\"");

        try {
            Process process = new ProcessBuilder(cmd).start();
            StringBuilder output = new StringBuilder();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line);
            }
            int exitCode = process.waitFor();
            return exitCode == 0 && output.toString().contains("OK");
        } catch (Exception e) {
            return false;
        }
    }

    public static Map<String, Object> getNodeMetrics(Map<String, Object> nodeConfig) {
        Map<String, Object> metrics = new HashMap<>();
        metrics.put("timestamp", LocalDateTime.now().toString());
        metrics.put("available", false);
        metrics.put("cpu", null);
        metrics.put("ram", null);
        metrics.put("disk", null);
        metrics.put("load", null);

        String host = (String) nodeConfig.get("host");
        String user = (String) nodeConfig.getOrDefault("user", "root");

        String cmd = String.format(
            "ssh -o ConnectTimeout=10 %s@%s 'echo \"CPU:$(top -bn1 | grep \"Cpu(s)\" | awk \"{print \\\\$$2}\" | cut -d\"%%\" -f1)\"; " +
            "echo \"RAM:$(free | grep Mem | awk \"{print (\\\\$$3/\\\\$$2) * 100.0}\")\"; " +
            "echo \"DISK:$(df -h / | tail -1 | awk \"{print \\\\$$5}\" | tr -d \"%%\")\"; " +
            "echo \"LOAD:$(uptime | awk -F\"load average:\" \"{print \\\\$$2}\" | awk \"{print \\\\$$1}\" | tr -d \",\")\"; " +
            "if command -v openclaw >/dev/null 2>&1; then systemctl is-active openclaw-gateway 2>/dev/null || echo \"GATEWAY:inactive\"; fi'",
            user, host
        );

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
                                try {
                                    metrics.put("cpu", Double.parseDouble(value));
                                } catch (NumberFormatException e) {
                                    // Ignore invalid values
                                }
                                break;
                            case "RAM":
                                try {
                                    metrics.put("ram", Double.parseDouble(value));
                                } catch (NumberFormatException e) {
                                    // Ignore invalid values
                                }
                                break;
                            case "DISK":
                                try {
                                    metrics.put("disk", Integer.parseInt(value));
                                } catch (NumberFormatException e) {
                                    // Ignore invalid values
                                }
                                break;
                            case "LOAD":
                                try {
                                    metrics.put("load", Double.parseDouble(value));
                                } catch (NumberFormatException e) {
                                    // Ignore invalid values
                                }
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

    public static List<Map<String, Object>> checkAlerts(String nodeId, Map<String, Object> nodeConfig, Map<String, Object> metrics) {
        List<Map<String, Object>> alerts = new ArrayList<>();

        Boolean available = (Boolean) metrics.get("available");
        if (available == null || !available) {
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
            Integer diskWarning = (Integer) nodeConfig.getOrDefault("disk_warning", 85);
            if (disk != null && disk > diskWarning) {
                String level = disk > 95 ? "CRITICAL" : "WARNING";
                Map<String, Object> alert = new HashMap<>();
                alert.put("level", level);
                alert.put("message", "Node " + nodeConfig.get("name") + ": Disk bei " + disk + "%");
                alerts.add(alert);
            }

            Boolean critical = (Boolean) nodeConfig.getOrDefault("critical", false);
            String gatewayStatus = (String) metrics.get("gateway_status");
            if (critical && "inactive".equals(gatewayStatus)) {
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
            Process process = new ProcessBuilder(
                "python3",
                scriptPath,
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
        String nodeArg = "all";
        String checkArg = "all";
        boolean alertFlag = false;

        // Simple argument parsing
        for (int i = 0; i < args.length; i++) {
            if ("--node".equals(args[i]) && i + 1 < args.length) {
                nodeArg = args[++i];
            } else if ("--check".equals(args[i]) && i + 1 < args.length) {
                checkArg = args[++i];
            } else if ("--alert".equals(args[i])) {
                alertFlag = true;
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
            log("Checking " + nodeConfig.get("name") + " (" + nodeId + ")");

            if ("ping".equals(checkArg) || "all".equals(checkArg)) {
                if (!"localhost".equals(nodeConfig.get("host"))) {
                    boolean pingOk = checkPing((String) nodeConfig.get("host"), 10);
                    log("  Ping: " + (pingOk ? "OK" : "FAILED"));
                }
            }

            if ("ssh".equals(checkArg) || "all".equals(checkArg)) {
                boolean sshOk = checkSSH(nodeConfig);
                log("  SSH: " + (sshOk ? "OK" : "FAILED"));
            }

            if ("metrics".equals(checkArg) || "all".equals(checkArg)) {
                Map<String, Object> metrics = getNodeMetrics(nodeConfig);
                Boolean available = (Boolean) metrics.get("available");

                if (available != null && available) {
                    Double cpu = (Double) metrics.get("cpu");
                    Double ram = (Double) metrics.get("ram");
                    Integer disk = (Integer) metrics.get("disk");
                    Double load = (Double) metrics.get("load");

                    log("  CPU: " + (cpu != null ? String.format("%.1f", cpu) + "%" : "N/A"));
                    log("  RAM: " + (ram != null ? String.format("%.1f", ram) + "%" : "N/A"));
                    log("  Disk: " + (disk != null ? disk + "%" : "N/A"));
                    log("  Load: " + (load != null ? load.toString() : "N/A"));
                } else {
                    log("  Metrics: UNAVAILABLE");
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
            log("\nAll nodes healthy!", "INFO");
        }
    }
}
