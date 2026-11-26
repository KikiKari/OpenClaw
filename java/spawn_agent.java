// abstraction-provenance: {"artifact_sha256": "9c5fd0c42f2a2bc94e4d17eed27e109aa6658a2ecd338911dc6ac4dd0babbb12", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "java"}
// spawn_agent.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:git/skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Sub-Agent spawner - Einfache CLI für sessions_spawn
 */
public class SpawnAgent {
    
    private static final List<String> MODELS = loadModels();
    
    /**
     * Lädt die Modellkonfiguration aus der openclaw.json
     */
    private static List<String> loadModels() {
        String configPathStr = System.getenv().getOrDefault("OPENCLAW_CONFIG", "/home/openclaw/.openclaw/openclaw.json");
        Path configPath = Paths.get(configPathStr);
        
        try {
            String content = Files.readString(configPath);
            // Simple JSON parsing - in real application use a proper JSON library like Jackson or Gson
            Map<String, Object> config = parseJson(content);
            Map<String, Object> agents = (Map<String, Object>) config.get("agents");
            Map<String, Object> defaults = (Map<String, Object>) agents.get("defaults");
            Map<String, Object> modelConfig = (Map<String, Object>) defaults.get("model");
            
            String primary = (String) modelConfig.get("primary");
            List<String> fallbacks = (List<String>) modelConfig.get("fallbacks");
            
            List<String> candidates = new ArrayList<>();
            candidates.add(primary);
            candidates.addAll(fallbacks);
            
            List<String> models = candidates.stream()
                .filter(model -> model != null && !model.isEmpty() && !model.startsWith("anthropic/"))
                .distinct()
                .collect(Collectors.toList());
                
            if (models.isEmpty()) {
                throw new RuntimeException("Keine allgemein verfügbaren Modelle in " + configPath);
            }
            
            return models;
            
        } catch (Exception error) {
            throw new RuntimeException("Modellkonfiguration kann nicht geladen werden: " + configPath + ": " + error.getMessage(), error);
        }
    }
    
    // Simple JSON parser - replace with proper JSON library in production
    @SuppressWarnings("unchecked")
    private static Map<String, Object> parseJson(String json) {
        // This is a very basic implementation - use Jackson/Gson in real code
        Map<String, Object> result = new HashMap<>();
        json = json.trim();
        if (json.startsWith("{") && json.endsWith("}")) {
            json = json.substring(1, json.length() - 1);
            String[] pairs = json.split(",");
            for (String pair : pairs) {
                String[] keyValue = pair.split(":");
                if (keyValue.length == 2) {
                    String key = keyValue[0].trim().replaceAll("\"", "");
                    String value = keyValue[1].trim().replaceAll("\"", "");
                    result.put(key, value);
                }
            }
        }
        return result;
    }
    
    static class SubAgentSpawner {
        /**
         * Erstellt Konfiguration für sessions_spawn
         */
        public static Map<String, Object> getSpawnConfig(
            String task,
            String label,
            String model,
            String thinking,
            Integer timeout,
            boolean thread,
            String mode
        ) {
            Map<String, Object> config = new HashMap<>();
            config.put("task", task);
            
            if (label != null && !label.isEmpty()) {
                config.put("label", label);
            }
            if (model != null && MODELS.contains(model)) {
                config.put("model", model);
            }
            if (thinking != null && !thinking.isEmpty()) {
                config.put("thinking", thinking);
            }
            if (timeout != null && timeout > 0) {
                config.put("runTimeoutSeconds", timeout);
            }
            if (thread) {
                config.put("thread", true);
                if ("run".equals(mode)) {
                    config.put("mode", "session"); // thread requires session mode
                }
            } else {
                config.put("mode", mode);
            }
            
            return config;
        }
        
        /**
         * Gibt das equivalente Tool-Kommando aus
         */
        public static void printSpawnCommand(Map<String, Object> config) {
            System.out.println("\n🛠️  Tool-Aufruf:");
            System.out.println("=".repeat(50));
            System.out.println("sessions_spawn(");
            for (Map.Entry<String, Object> entry : config.entrySet()) {
                Object value = entry.getValue();
                if (value instanceof String) {
                    System.out.println("    " + entry.getKey() + "=\"" + value + "\"");
                } else {
                    System.out.println("    " + entry.getKey() + "=" + value);
                }
            }
            System.out.println(")");
            System.out.println("=".repeat(50));
        }
        
        /**
         * Gibt das equivalente Slash-Kommando aus
         */
        public static void printSlashCommand(Map<String, Object> config) {
            String task = (String) config.getOrDefault("task", "");
            String label = (String) config.getOrDefault("label", "agent");
            String model = (String) config.getOrDefault("model", "");
            
            String cmd = "/subagents spawn " + label + " \"" + task + "\"";
            if (model != null && !model.isEmpty()) {
                cmd += " --model " + model;
            }
            if (config.containsKey("thinking") && config.get("thinking") != null) {
                cmd += " --thinking " + config.get("thinking");
            }
            
            System.out.println("\n💬 Slash Command:");
            System.out.println("=".repeat(50));
            System.out.println(cmd);
            System.out.println("=".repeat(50));
        }
    }
    
    public static void main(String[] args) {
        if (args.length == 0) {
            printHelp();
            return;
        }
        
        // Simple argument parsing
        Map<String, String> arguments = parseArguments(args);
        
        if (arguments.containsKey("help")) {
            printHelp();
            return;
        }
        
        try {
            String task = arguments.get("task");
            if (task == null || task.isEmpty()) {
                System.err.println("Fehler: --task/-t ist erforderlich");
                System.exit(1);
                return;
            }
            
            String label = arguments.get("label");
            String model = arguments.get("model");
            String thinking = arguments.get("thinking");
            int timeout = parseInt(arguments.getOrDefault("timeout", "900"));
            boolean thread = "true".equals(arguments.get("thread"));
            String mode = arguments.getOrDefault("mode", "run");
            String output = arguments.getOrDefault("output", "tool");
            
            // Validate model choice
            if (model != null && !MODELS.contains(model)) {
                System.err.println("Fehler: Ungültiges Modell. Gültige Optionen: " + String.join(", ", MODELS));
                System.exit(1);
                return;
            }
            
            Map<String, Object> config = SubAgentSpawner.getSpawnConfig(
                task, label, model, thinking, timeout, thread, mode
            );
            
            System.out.println("✅ Sub-Agent Konfiguration:");
            System.out.println(toJson(config));
            
            switch (output) {
                case "tool":
                    SubAgentSpawner.printSpawnCommand(config);
                    break;
                case "slash":
                    SubAgentSpawner.printSlashCommand(config);
                    break;
                case "json":
                    System.out.println("\n📄 JSON:");
                    String jsonOutput = toJson(config);
                    System.out.println(jsonOutput);
                    
                    // Speichere als Datei
                    String fileName = "/tmp/subagent_" + config.getOrDefault("label", "spawn") + ".json";
                    Files.write(Paths.get(fileName), jsonOutput.getBytes());
                    System.out.println("💾 Gespeichert: " + fileName);
                    break;
            }
            
        } catch (Exception e) {
            System.err.println("Fehler: " + e.getMessage());
            System.exit(1);
        }
    }
    
    private static Map<String, String> parseArguments(String[] args) {
        Map<String, String> arguments = new HashMap<>();
        
        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            switch (arg) {
                case "--task":
                case "-t":
                    if (i + 1 < args.length) {
                        arguments.put("task", args[++i]);
                    }
                    break;
                case "--label":
                case "-l":
                    if (i + 1 < args.length) {
                        arguments.put("label", args[++i]);
                    }
                    break;
                case "--model":
                case "-m":
                    if (i + 1 < args.length) {
                        arguments.put("model", args[++i]);
                    }
                    break;
                case "--thinking":
                    if (i + 1 < args.length) {
                        arguments.put("thinking", args[++i]);
                    }
                    break;
                case "--timeout":
                    if (i + 1 < args.length) {
                        arguments.put("timeout", args[++i]);
                    }
                    break;
                case "--thread":
                    arguments.put("thread", "true");
                    break;
                case "--mode":
                    if (i + 1 < args.length) {
                        arguments.put("mode", args[++i]);
                    }
                    break;
                case "--output":
                case "-o":
                    if (i + 1 < args.length) {
                        arguments.put("output", args[++i]);
                    }
                    break;
                case "--help":
                case "-h":
                    arguments.put("help", "true");
                    break;
            }
        }
        
        return arguments;
    }
    
    private static int parseInt(String value) {
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException e) {
            return 0;
        }
    }
    
    private static String toJson(Map<String, Object> map) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\n");
        boolean first = true;
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            if (!first) {
                sb.append(",\n");
            }
            sb.append("  \"").append(entry.getKey()).append("\": ");
            Object value = entry.getValue();
            if (value instanceof String) {
                sb.append("\"").append(value).append("\"");
            } else {
                sb.append(value);
            }
            first = false;
        }
        sb.append("\n}");
        return sb.toString();
    }
    
    private static void printHelp() {
        System.out.println("Sub-Agent Spawn Helper");
        System.out.println("");
        System.out.println("Optionen:");
        System.out.println("  --task, -t <string>       Aufgabenbeschreibung (erforderlich)");
        System.out.println("  --label, -l <string>      Optionaler Label");
        System.out.println("  --model, -m <string>      KI-Modell");
        System.out.println("  --thinking <string>       Thinking Level (low, medium, high)");
        System.out.println("  --timeout <integer>       Timeout in Sekunden (default: 900)");
        System.out.println("  --thread                  Thread-Binding aktivieren");
        System.out.println("  --mode <string>           Run mode (run, session)");
        System.out.println("  --output, -o <string>     Output format (tool, slash, json)");
        System.out.println("  --help, -h                Diese Hilfe anzeigen");
        System.out.println("");
        System.out.println("Beispiele:");
        System.out.println("  spawn_agent --task \"Analyze logs\"");
        System.out.println("  spawn_agent --task \"Code review\" --model openai/gpt-5.6-sol --timeout 1800");
        System.out.println("  spawn_agent --task \"Batch process\" --label \"batch-worker\" --thread");
    }
}
