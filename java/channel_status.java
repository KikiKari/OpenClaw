// abstraction-provenance: {"artifact_sha256": "23af4188520fd8d0601dab85480b60db70d2cd05d43164614d7722a148644753", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "java"}
// channel_status.py — portiert nach java
// Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.TimeUnit;
import com.google.gson.*;

/**
 * Channel Status Agent - Automatische Status-Updates
 */
public class ChannelStatus {

    // Konfiguration
    private static final Path WORKSPACE = Paths.get(System.getProperty("user.home"), ".openclaw", "workspace");
    private static final Path LOGS_DB = WORKSPACE.resolve("db/logs.db");
    private static final Path CONFIG_FILE = WORKSPACE.resolve("config/channel-status.json");
    private static final Path LOG_FILE = WORKSPACE.resolve("logs/channel-status.log");

    private static final Map<String, Set<String>> NODE_NAMES = new HashMap<>();

    static {
        NODE_NAMES.put("node2", new HashSet<>(Arrays.asList("openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122")));
        NODE_NAMES.put("node3", new HashSet<>(Arrays.asList("openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125")));
        NODE_NAMES.put("node4", new HashSet<>(Arrays.asList("openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39")));
        NODE_NAMES.put("node5", new HashSet<>(Arrays.asList("openclaw-node5", "lenovo-node7", "lenovo-node7.taild25fea.ts.net", "100.103.140.35")));
    }

    public static void main(String[] args) {
        try {
            Files.createDirectories(LOG_FILE.getParent());
        } catch (IOException e) {
            System.err.println("Could not create log directory: " + e.getMessage());
        }

        // Argument parsing
        String type = null;
        String message = null;
        String channel = "-1002381931352";
        boolean dryRun = false;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--type":
                    if (i + 1 < args.length) type = args[++i];
                    break;
                case "--message":
                    if (i + 1 < args.length) message = args[++i];
                    break;
                case "--channel":
                    if (i + 1 < args.length) channel = args[++i];
                    break;
                case "--dry-run":
                    dryRun = true;
                    break;
            }
        }

        if (type == null) {
            System.err.println("Error: --type is required");
            System.exit(1);
            return;
        }

        log("Starting " + type + " status update");

        // Status sammeln
        JsonObject status = getSystemStatus();

        // Message formatieren
        String formattedMessage;
        switch (type) {
            case "daily":
                formattedMessage = formatDailyStatus(status);
                break;
            case "weekly":
                formattedMessage = formatWeeklyStatus(status);
                break;
            case "alert":
                formattedMessage = "🚨 **ALERT**\n" + (message != null ? message : "Manual alert");
                break;
            default:
                System.err.println("Unknown type: " + type);
                System.exit(1);
                return;
        }

        // Senden oder Dry-Run
        if (dryRun) {
            System.out.println("\n--- DRY RUN ---");
            System.out.println(formattedMessage);
            System.out.println("--- END ---");
        } else {
            sendToChannel(formattedMessage, "telegram", channel);
        }

        log("Status update completed");
    }

    private static void log(String message) {
        log(message, "INFO");
    }

    private static void log(String message, String level) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        String entry = "[" + timestamp + "] [" + level + "] " + message;
        System.out.println(entry);
        try (PrintWriter writer = new PrintWriter(new FileWriter(LOG_FILE.toFile(), true))) {
            writer.println(entry);
        } catch (IOException e) {
            System.err.println("Failed to write to log: " + e.getMessage());
        }
    }

    private static Map<String, Boolean> fetchNodeStatus() {
        try {
            ProcessBuilder pb = new ProcessBuilder("openclaw", "nodes", "status", "--json");
            Process process = pb.start();
            process.waitFor(10, TimeUnit.SECONDS);

            if (process.exitValue() != 0) {
                return null;
            }

            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line);
                }
            }

            JsonElement element = JsonParser.parseString(output.toString());
            if (!element.isJsonObject()) {
                return null;
            }

            JsonObject root = element.getAsJsonObject();
            if (!root.has("nodes") || !root.get("nodes").isJsonArray()) {
                return null;
            }

            Map<String, Boolean> states = new HashMap<>();
            for (String node : NODE_NAMES.keySet()) {
                states.put(node, false);
            }

            JsonArray nodesArray = root.getAsJsonArray("nodes");
            for (JsonElement itemElement : nodesArray) {
                if (!itemElement.isJsonObject()) {
                    continue;
                }
                JsonObject item = itemElement.getAsJsonObject();
                Set<String> names = new HashSet<>();
                if (item.has("displayName")) names.add(item.get("displayName").getAsString().toLowerCase());
                if (item.has("nodeId")) names.add(item.get("nodeId").getAsString().toLowerCase());
                if (item.has("remoteIp")) names.add(item.get("remoteIp").getAsString().toLowerCase());

                for (Map.Entry<String, Set<String>> entry : NODE_NAMES.entrySet()) {
                    String node = entry.getKey();
                    Set<String> aliases = entry.getValue();
                    if (!Collections.disjoint(names, aliases) && item.has("connected") && item.get("connected").getAsBoolean()) {
                        states.put(node, true);
                    }
                }
            }
            states.put("node1", true); // successful Gateway status request
            return states;
        } catch (Exception e) {
            return null;
        }
    }

    private static JsonObject getSystemStatus() {
        JsonObject status = new JsonObject();
        status.addProperty("timestamp", LocalDateTime.now().toString());

        JsonObject nodesObj = new JsonObject();
        Map<String, Boolean> states = fetchNodeStatus();
        Map<String, String> names = new HashMap<>();
        names.put("node1", "Gateway");
        names.put("node2", "Node2");
        names.put("node3", "Node3");
        names.put("node4", "Redmi");
        names.put("node5", "Lenovo");

        for (Map.Entry<String, String> entry : names.entrySet()) {
            String node = entry.getKey();
            String nodeName = entry.getValue();
            JsonObject nodeInfo = new JsonObject();
            nodeInfo.addProperty("name", nodeName);
            if (states == null) {
                nodeInfo.addProperty("status", "unknown");
            } else {
                nodeInfo.addProperty("status", states.getOrDefault(node, false) ? "online" : "offline");
            }
            nodesObj.add(node, nodeInfo);
        }
        status.add("nodes", nodesObj);

        JsonObject agentsObj = new JsonObject();
        try {
            ProcessBuilder pb = new ProcessBuilder("crontab", "-l");
            Process process = pb.start();
            process.waitFor();

            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }

            long count = output.toString().lines().filter(line -> !line.trim().startsWith("#")).count();
            agentsObj.addProperty("active_crons", count);
        } catch (Exception e) {
            agentsObj.addProperty("active_crons", "unknown");
        }
        status.add("agents", agentsObj);

        JsonObject systemObj = new JsonObject();
        try {
            ProcessBuilder pb = new ProcessBuilder("df", "-h", "/");
            Process process = pb.start();
            process.waitFor();

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("/") && line.contains("%")) {
                        String[] parts = line.trim().split("\\s+");
                        if (parts.length >= 5) {
                            systemObj.addProperty("disk_used", parts[4]);
                            break;
                        }
                    }
                }
            }

            pb = new ProcessBuilder("free", "-h");
            process = pb.start();
            process.waitFor();

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("Mem:")) {
                        String[] parts = line.trim().split("\\s+");
                        if (parts.length >= 3) {
                            systemObj.addProperty("ram_total", parts[1]);
                            systemObj.addProperty("ram_used", parts[2]);
                        }
                        break;
                    }
                }
            }
        } catch (Exception e) {
            // Ignore errors
        }
        status.add("system", systemObj);

        return status;
    }

    private static String formatDailyStatus(JsonObject status) {
        JsonObject nodes = status.getAsJsonObject("nodes");
        int online = 0;
        for (String key : nodes.keySet()) {
            JsonObject node = nodes.getAsJsonObject(key);
            if ("online".equals(node.get("status").getAsString())) {
                online++;
            }
        }

        StringBuilder message = new StringBuilder();
        message.append("📊 **Täglicher Status-Report**\n");
        message.append("🗓️ ").append(LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"))).append("\n\n");
        message.append("**🖥️ Nodes (").append(online).append("/").append(nodes.size()).append(" online):**\n");

        Map<String, String> nodeOrder = new LinkedHashMap<>();
        nodeOrder.put("node1", "Gateway");
        nodeOrder.put("node2", "Node2");
        nodeOrder.put("node3", "Node3");
        nodeOrder.put("node4", "Redmi");
        nodeOrder.put("node5", "Lenovo");

        for (Map.Entry<String, String> entry : nodeOrder.entrySet()) {
            String nodeId = entry.getKey();
            String nodeName = entry.getValue();
            if (nodes.has(nodeId)) {
                JsonObject info = nodes.getAsJsonObject(nodeId);
                String nodeStatus = info.get("status").getAsString();
                String emoji = "🟢";
                if ("offline".equals(nodeStatus)) {
                    emoji = "🔴";
                } else if ("unknown".equals(nodeStatus)) {
                    emoji = "🟡";
                }
                message.append(emoji).append(" ").append(nodeName).append(": ").append(nodeStatus).append("\n");
            }
        }

        message.append("\n**🤖 Agents:**\n");
        JsonObject agents = status.getAsJsonObject("agents");
        message.append("Aktive Cron-Jobs: ").append(agents.get("active_crons").getAsString()).append("\n");

        if (status.getAsJsonObject("system").has("disk_used")) {
            JsonObject system = status.getAsJsonObject("system");
            message.append("\n**💾 System:**\n");
            message.append("Disk: ").append(system.get("disk_used").getAsString()).append(" belegt\n");
            message.append("RAM: ").append(system.get("ram_used").getAsString()).append(" / ").append(system.get("ram_total").getAsString()).append("\n");
        }

        return message.toString();
    }

    private static String formatWeeklyStatus(JsonObject status) {
        List<String> lines = new ArrayList<>();
        lines.add("📈 **Wöchentlicher Report**");
        lines.add("📅 Woche " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("ww")) + " - " + Year.now().getValue());
        lines.add("");
        lines.add("**Nodes:**");

        JsonObject nodes = status.getAsJsonObject("nodes");
        Map<String, String> nodeOrder = new LinkedHashMap<>();
        nodeOrder.put("node1", "Gateway");
        nodeOrder.put("node2", "Node2");
        nodeOrder.put("node3", "Node3");
        nodeOrder.put("node4", "Redmi");
        nodeOrder.put("node5", "Lenovo");

        for (Map.Entry<String, String> entry : nodeOrder.entrySet()) {
            String nodeId = entry.getKey();
            String nodeName = entry.getValue();
            if (nodes.has(nodeId)) {
                JsonObject info = nodes.getAsJsonObject(nodeId);
                lines.add("- " + nodeName + ": " + info.get("status").getAsString());
            }
        }

        return String.join("\n", lines) + "\n";
    }

    private static boolean sendToChannel(String message, String channelType, String channelId) {
        List<String> cmd;
        if ("telegram".equals(channelType)) {
            cmd = Arrays.asList("openclaw", "message", "send", "--target", channelId, "--message", message);
        } else {
            log("Channel type " + channelType + " not implemented", "WARN");
            return false;
        }

        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            Process process = pb.start();
            int exitCode = process.waitFor();

            if (exitCode == 0) {
                log("Message sent to " + channelType + " " + channelId);
                return true;
            } else {
                StringBuilder errorOutput = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        errorOutput.append(line).append("\n");
                    }
                }
                log("Failed to send: " + errorOutput.toString(), "ERROR");
                return false;
            }
        } catch (Exception e) {
            log("Send error: " + e.getMessage(), "ERROR");
            return false;
        }
    }
}
