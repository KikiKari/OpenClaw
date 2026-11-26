// abstraction-provenance: {"artifact_sha256": "88e05640ebbc35bacd447f9f6ae3f6d9bc5b2db12035f402a744925ff29fe1e9", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "java"}
// bundled-plugin-source-utils.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;

public class BundledPluginSourceUtils {

    /**
     * Reads the content of a file if it exists, otherwise returns null.
     *
     * @param filePath The path to the file to read.
     * @return The content of the file as a String, or null if the file does not exist or an error occurs.
     */
    public static String readIfExists(String filePath) {
        try {
            return Files.readString(Paths.get(filePath));
        } catch (IOException e) {
            return null;
        }
    }

    /**
     * Collects information about bundled plugin sources.
     *
     * @param params A map containing parameters such as repoRoot and requirePackageJson.
     * @return A sorted list of maps containing plugin information.
     */
    public static List<Map<String, Object>> collectBundledPluginSources(Map<String, Object> params) {
        if (params == null) {
            params = new HashMap<>();
        }

        String repoRoot = (String) params.getOrDefault("repoRoot", System.getProperty("user.dir"));
        Path extensionsRoot = Paths.get(repoRoot).resolve("extensions");

        if (!Files.exists(extensionsRoot)) {
            return new ArrayList<>();
        }

        boolean requirePackageJson = Boolean.TRUE.equals(params.get("requirePackageJson"));
        List<Map<String, Object>> entries = new ArrayList<>();

        try (var stream = Files.list(extensionsRoot)) {
            List<Path> directories = stream
                    .filter(Files::isDirectory)
                    .collect(Collectors.toList());

            for (Path pluginDir : directories) {
                Path manifestPath = pluginDir.resolve("openclaw.plugin.json");
                Path packageJsonPath = pluginDir.resolve("package.json");

                if (!Files.exists(manifestPath)) {
                    continue;
                }

                if (requirePackageJson && !Files.exists(packageJsonPath)) {
                    continue;
                }

                Map<String, Object> entry = new HashMap<>();
                entry.put("dirName", pluginDir.getFileName().toString());
                entry.put("pluginDir", pluginDir.toString());
                entry.put("manifestPath", manifestPath.toString());

                try {
                    String manifestContent = Files.readString(manifestPath);
                    entry.put("manifest", new com.google.gson.Gson().fromJson(manifestContent, Map.class));
                } catch (IOException e) {
                    // Handle exception silently as per original behavior
                }

                if (Files.exists(packageJsonPath)) {
                    entry.put("packageJsonPath", packageJsonPath.toString());
                    try {
                        String packageJsonContent = Files.readString(packageJsonPath);
                        entry.put("packageJson", new com.google.gson.Gson().fromJson(packageJsonContent, Map.class));
                    } catch (IOException e) {
                        // Handle exception silently as per original behavior
                    }
                }

                entries.add(entry);
            }
        } catch (IOException e) {
            // Handle exception silently as per original behavior
        }

        // Sort entries by dirName
        entries.sort(Comparator.comparing(entry -> (String) entry.get("dirName")));

        return entries;
    }

    // Example usage method
    public static void main(String[] args) {
        Map<String, Object> params = new HashMap<>();
        params.put("repoRoot", "/path/to/repo");
        params.put("requirePackageJson", true);

        List<Map<String, Object>> result = collectBundledPluginSources(params);
        System.out.println(result);
    }
}
