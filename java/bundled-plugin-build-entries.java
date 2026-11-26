// abstraction-provenance: {"artifact_sha256": "6672091a2d0e33b70a5f52d30b3450e44a9e9417dbd25f32ee10abe5e21355fa", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "java"}
// bundled-plugin-build-entries.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.*;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

public class BundledPluginBuildEntries {
    private static final Set<String> TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS = 
        Set.of(".ts", ".js", ".mts", ".cts", ".mjs", ".cjs");
    
    private static final Set<String> NON_PACKAGED_BUNDLED_PLUGIN_DIRS = 
        Set.of("qa-channel", "qa-lab");
    
    private static final String BUNDLED_PLUGIN_ROOT_DIR = "plugins"; // Adjust as needed
    private static final ObjectMapper objectMapper = new ObjectMapper();

    public static class PluginEntry {
        public final String id;
        public final boolean hasManifest;
        public final boolean hasPackageJson;
        public final JsonNode packageJson;
        public final List<String> sourceEntries;

        public PluginEntry(String id, boolean hasManifest, boolean hasPackageJson, 
                          JsonNode packageJson, List<String> sourceEntries) {
            this.id = id;
            this.hasManifest = hasManifest;
            this.hasPackageJson = hasPackageJson;
            this.packageJson = packageJson;
            this.sourceEntries = sourceEntries;
        }
    }

    private static String toPosixPath(String value) {
        return value.replace("\\", "/");
    }

    private static JsonNode readBundledPluginPackageJson(String packageJsonPath) {
        Path path = Paths.get(packageJsonPath);
        if (!Files.exists(path)) {
            return null;
        }
        try {
            return objectMapper.readTree(path.toFile());
        } catch (Exception e) {
            return null;
        }
    }

    private static boolean isManifestlessBundledRuntimeSupportPackage(
            String dirName, JsonNode packageJson, List<String> topLevelPublicSurfaceEntries) {
        String packageName = (packageJson != null && packageJson.has("name")) ? 
            packageJson.get("name").asText("") : "";
        if (!packageName.equals("@openclaw/" + dirName)) {
            return false;
        }
        return !topLevelPublicSurfaceEntries.isEmpty();
    }

    private static List<String> collectPluginSourceEntries(JsonNode packageJson) {
        List<String> packageEntries = new ArrayList<>();
        
        if (packageJson != null && packageJson.has("openclaw")) {
            JsonNode openclaw = packageJson.get("openclaw");
            if (openclaw.has("extensions")) {
                JsonNode extensions = openclaw.get("extensions");
                if (extensions.isArray()) {
                    for (JsonNode entry : extensions) {
                        if (entry.isTextual() && !entry.asText().trim().isEmpty()) {
                            packageEntries.add(entry.asText());
                        }
                    }
                }
            }
        }
        
        String setupEntry = null;
        if (packageJson != null && packageJson.has("openclaw")) {
            JsonNode openclaw = packageJson.get("openclaw");
            if (openclaw.has("setupEntry") && openclaw.get("setupEntry").isTextual()) {
                String entry = openclaw.get("setupEntry").asText("");
                if (!entry.trim().isEmpty()) {
                    setupEntry = entry;
                }
            }
        }
        
        if (setupEntry != null) {
            Set<String> uniqueEntries = new LinkedHashSet<>(packageEntries);
            uniqueEntries.add(setupEntry);
            packageEntries = new ArrayList<>(uniqueEntries);
        }
        
        return packageEntries.isEmpty() ? Arrays.asList("./index.ts") : packageEntries;
    }

    private static boolean shouldStageBundledPluginRuntimeDependencies(JsonNode packageJson) {
        return packageJson != null && 
               packageJson.has("openclaw") &&
               packageJson.get("openclaw").has("bundle") &&
               packageJson.get("openclaw").get("bundle").has("stageRuntimeDependencies") &&
               packageJson.get("openclaw").get("bundle").get("stageRuntimeDependencies").asBoolean(false);
    }

    private static List<String> collectTopLevelPublicSurfaceEntries(String pluginDir) {
        Path dirPath = Paths.get(pluginDir);
        if (!Files.exists(dirPath) || !Files.isDirectory(dirPath)) {
            return new ArrayList<>();
        }

        try {
            return Files.list(dirPath)
                .filter(Files::isRegularFile)
                .map(path -> {
                    String fileName = path.getFileName().toString();
                    String ext = getFileExtension(fileName);
                    
                    if (!TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS.contains(ext)) {
                        return null;
                    }

                    String normalizedName = fileName.toLowerCase();
                    if (normalizedName.endsWith(".d.ts") ||
                        normalizedName.matches("^config-api\\.(?:[cm]?[jt]s)$") ||
                        normalizedName.contains(".test.") ||
                        normalizedName.contains(".spec.") ||
                        normalizedName.contains(".fixture.") ||
                        normalizedName.contains(".snap")) {
                        return null;
                    }

                    return "./" + fileName;
                })
                .filter(Objects::nonNull)
                .sorted()
                .collect(Collectors.toList());
        } catch (IOException e) {
            return new ArrayList<>();
        }
    }

    private static String getFileExtension(String fileName) {
        int lastDotIndex = fileName.lastIndexOf('.');
        return lastDotIndex > 0 ? fileName.substring(lastDotIndex) : "";
    }

    public static List<PluginEntry> collectBundledPluginBuildEntries(Map<String, Object> params) {
        String cwd = params != null && params.containsKey("cwd") ? 
            (String) params.get("cwd") : System.getProperty("user.dir");
        Map<String, String> env = params != null && params.containsKey("env") ? 
            (Map<String, String>) params.get("env") : System.getenv();
        
        String extensionsRoot = Paths.get(cwd, BUNDLED_PLUGIN_ROOT_DIR).toString();
        List<PluginEntry> entries = new ArrayList<>();

        File rootDir = new File(extensionsRoot);
        if (!rootDir.exists() || !rootDir.isDirectory()) {
            return entries;
        }

        File[] directories = rootDir.listFiles(File::isDirectory);
        if (directories == null) {
            return entries;
        }

        for (File dir : directories) {
            String pluginDir = dir.getAbsolutePath();
            String manifestPath = Paths.get(pluginDir, "openclaw.plugin.json").toString();
            boolean hasManifest = Files.exists(Paths.get(manifestPath));
            
            String packageJsonPath = Paths.get(pluginDir, "package.json").toString();
            JsonNode packageJson = readBundledPluginPackageJson(packageJsonPath);
            
            List<String> topLevelPublicSurfaceEntries = collectTopLevelPublicSurfaceEntries(pluginDir);
            
            if (!hasManifest && !isManifestlessBundledRuntimeSupportPackage(
                    dir.getName(), packageJson, topLevelPublicSurfaceEntries)) {
                continue;
            }
            
            // Note: shouldBuildBundledCluster needs to be implemented based on your logic
            if (!shouldBuildBundledCluster(dir.getName(), env, packageJson)) {
                continue;
            }

            List<String> sourceEntries = new ArrayList<>();
            if (hasManifest) {
                sourceEntries.addAll(collectPluginSourceEntries(packageJson));
            }
            sourceEntries.addAll(topLevelPublicSurfaceEntries);
            
            // Remove duplicates while preserving order
            sourceEntries = new ArrayList<>(new LinkedHashSet<>(sourceEntries));

            entries.add(new PluginEntry(
                dir.getName(),
                hasManifest,
                packageJson != null,
                packageJson,
                sourceEntries
            ));
        }

        return entries;
    }

    public static Map<String, String> listBundledPluginBuildEntries(Map<String, Object> params) {
        List<PluginEntry> entries = collectBundledPluginBuildEntries(params);
        Map<String, String> result = new LinkedHashMap<>();

        for (PluginEntry entry : entries) {
            for (String sourceEntry : entry.sourceEntries) {
                String normalizedEntry = sourceEntry.replaceFirst("^\\./", "");
                String baseName = removeFileExtension(normalizedEntry);
                String entryKey = bundledPluginFile(entry.id, baseName);
                String filePath = toPosixPath(Paths.get(BUNDLED_PLUGIN_ROOT_DIR, entry.id, normalizedEntry).toString());
                result.put(entryKey, filePath);
            }
        }

        return result;
    }

    public static List<String> listBundledPluginPackArtifacts(Map<String, Object> params) {
        List<PluginEntry> allEntries = collectBundledPluginBuildEntries(params);
        List<PluginEntry> entries = allEntries.stream()
            .filter(e -> !NON_PACKAGED_BUNDLED_PLUGIN_DIRS.contains(e.id))
            .collect(Collectors.toList());

        Set<String> artifacts = new TreeSet<>();

        for (PluginEntry entry : entries) {
            if (entry.hasManifest) {
                artifacts.add(bundledDistPluginFile(entry.id, "openclaw.plugin.json"));
            }
            if (entry.hasPackageJson) {
                artifacts.add(bundledDistPluginFile(entry.id, "package.json"));
            }
            for (String sourceEntry : entry.sourceEntries) {
                String normalizedEntry = sourceEntry.replaceFirst("^\\./", "");
                String baseName = removeFileExtension(normalizedEntry);
                artifacts.add(bundledDistPluginFile(entry.id, baseName + ".js"));
            }
        }

        return new ArrayList<>(artifacts);
    }

    public static List<String> listBundledPluginRuntimeDependencies(Map<String, Object> params) {
        Set<String> runtimeDependencies = new TreeSet<>();

        List<PluginEntry> entries = collectBundledPluginBuildEntries(params);
        for (PluginEntry entry : entries) {
            if (!shouldStageBundledPluginRuntimeDependencies(entry.packageJson)) {
                continue;
            }

            if (entry.packageJson != null && entry.packageJson.has("dependencies")) {
                JsonNode dependencies = entry.packageJson.get("dependencies");
                Iterator<Map.Entry<String, JsonNode>> fields = dependencies.fields();
                while (fields.hasNext()) {
                    runtimeDependencies.add(fields.next().getKey());
                }
            }

            if (entry.packageJson != null && entry.packageJson.has("optionalDependencies")) {
                JsonNode optionalDependencies = entry.packageJson.get("optionalDependencies");
                Iterator<Map.Entry<String, JsonNode>> fields = optionalDependencies.fields();
                while (fields.hasNext()) {
                    runtimeDependencies.add(fields.next().getKey());
                }
            }
        }

        return new ArrayList<>(runtimeDependencies);
    }

    // Helper methods - these need to be implemented based on your specific requirements
    private static String bundledPluginFile(String id, String fileName) {
        // Implement based on your bundled-plugin-paths.mjs logic
        return id + "/" + fileName;
    }

    private static String bundledDistPluginFile(String id, String fileName) {
        // Implement based on your bundled-plugin-paths.mjs logic
        return "dist/" + id + "/" + fileName;
    }

    private static String removeFileExtension(String fileName) {
        int lastDotIndex = fileName.lastIndexOf('.');
        return lastDotIndex > 0 ? fileName.substring(0, lastDotIndex) : fileName;
    }

    private static boolean shouldBuildBundledCluster(String name, Map<String, String> env, JsonNode packageJson) {
        // Implement based on your optional-bundled-clusters.mjs logic
        return true;
    }
}
