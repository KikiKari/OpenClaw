// abstraction-provenance: {"artifact_sha256": "0ccf8e12e2fdf825e4ac87b440fae2b6af127d0c5079b61743e07ef72632f805", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "java"}
// bundled-plugin-root-runtime-mirrors.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.*;
import java.util.regex.*;
import java.util.stream.Collectors;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

public class BundledPluginRootRuntimeMirrors {

    private static final Set<String> JS_EXTENSIONS = new HashSet<>(Arrays.asList(".cjs", ".js", ".mjs"));
    private static final ObjectMapper objectMapper = new ObjectMapper();

    public static Map<String, String> collectRuntimeDependencySpecs(JsonNode packageJson) {
        Map<String, String> specs = new HashMap<>();
        
        if (packageJson != null) {
            JsonNode dependencies = packageJson.get("dependencies");
            if (dependencies != null) {
                Iterator<Map.Entry<String, JsonNode>> fields = dependencies.fields();
                while (fields.hasNext()) {
                    Map.Entry<String, JsonNode> entry = fields.next();
                    if (entry.getValue().isTextual() && !entry.getValue().asText().isEmpty()) {
                        specs.put(entry.getKey(), entry.getValue().asText());
                    }
                }
            }
            
            JsonNode optionalDependencies = packageJson.get("optionalDependencies");
            if (optionalDependencies != null) {
                Iterator<Map.Entry<String, JsonNode>> fields = optionalDependencies.fields();
                while (fields.hasNext()) {
                    Map.Entry<String, JsonNode> entry = fields.next();
                    if (entry.getValue().isTextual() && !entry.getValue().asText().isEmpty()) {
                        specs.put(entry.getKey(), entry.getValue().asText());
                    }
                }
            }
        }
        
        return specs;
    }

    public static String packageNameFromSpecifier(String specifier) {
        if (specifier == null || 
            specifier.startsWith(".") || 
            specifier.startsWith("/") || 
            specifier.startsWith("node:") || 
            specifier.startsWith("#")) {
            return null;
        }
        
        String[] parts = specifier.split("/");
        if (parts.length == 0) {
            return null;
        }
        
        if (parts[0].startsWith("@") && parts.length > 1) {
            return parts[0] + "/" + parts[1];
        }
        return parts[0];
    }

    private static JsonNode readJson(Path filePath) throws IOException {
        return objectMapper.readTree(Files.readAllBytes(filePath));
    }

    private static List<Path> collectPackageJsonPaths(Path rootDir) throws IOException {
        List<Path> paths = new ArrayList<>();
        if (!Files.exists(rootDir)) {
            return paths;
        }
        
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(rootDir)) {
            for (Path entry : stream) {
                if (Files.isDirectory(entry)) {
                    Path packageJsonPath = entry.resolve("package.json");
                    if (Files.exists(packageJsonPath)) {
                        paths.add(packageJsonPath);
                    }
                }
            }
        }
        
        Collections.sort(paths);
        return paths;
    }

    public static class BundledSpecRecord {
        public List<String> conflicts = new ArrayList<>();
        public List<String> pluginIds = new ArrayList<>();
        public String spec;
        
        public BundledSpecRecord(List<String> conflicts, List<String> pluginIds, String spec) {
            this.conflicts.addAll(conflicts);
            this.pluginIds.addAll(pluginIds);
            this.spec = spec;
        }
    }

    public static Map<String, BundledSpecRecord> collectBundledPluginRuntimeDependencySpecs(Path bundledPluginsDir) throws IOException {
        Map<String, BundledSpecRecord> specs = new HashMap<>();
        
        for (Path packageJsonPath : collectPackageJsonPaths(bundledPluginsDir)) {
            JsonNode packageJson = readJson(packageJsonPath);
            String pluginId = packageJsonPath.getParent().getFileName().toString();
            
            for (Map.Entry<String, String> entry : collectRuntimeDependencySpecs(packageJson).entrySet()) {
                String name = entry.getKey();
                String spec = entry.getValue();
                
                BundledSpecRecord existing = specs.get(name);
                if (existing != null) {
                    if (!existing.spec.equals(spec)) {
                        existing.conflicts.add(pluginId + ": " + spec);
                    } else if (!existing.pluginIds.contains(pluginId)) {
                        existing.pluginIds.add(pluginId);
                    }
                    continue;
                }
                
                specs.put(name, new BundledSpecRecord(new ArrayList<>(), new ArrayList<>(Arrays.asList(pluginId)), spec));
            }
        }
        
        return specs;
    }

    private static List<Path> walkJavaScriptFiles(Path rootDir) throws IOException {
        List<Path> files = new ArrayList<>();
        if (!Files.exists(rootDir)) {
            return files;
        }
        
        Files.walkFileTree(rootDir, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
                if (dir.toString().contains("extensions")) {
                    return FileVisitResult.SKIP_SUBTREE;
                }
                return FileVisitResult.CONTINUE;
            }
            
            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                String fileName = file.getFileName().toString();
                int dotIndex = fileName.lastIndexOf('.');
                if (dotIndex > 0) {
                    String extension = fileName.substring(dotIndex);
                    if (JS_EXTENSIONS.contains(extension)) {
                        files.add(file);
                    }
                }
                return FileVisitResult.CONTINUE;
            }
        });
        
        Collections.sort(files);
        return files;
    }

    private static Set<String> extractModuleSpecifiers(String source) {
        Set<String> specifiers = new HashSet<>();
        Pattern[] patterns = {
            Pattern.compile("\\bfrom\\s*[\"']([^\"']*)[\"']"),
            Pattern.compile("\\bimport\\s*[\"']([^\"']*)[\"']"),
            Pattern.compile("\\bimport\\s*\\(\\s*[\"']([^\"']*)[\"']\\s*\\)"),
            Pattern.compile("\\brequire\\s*\\(\\s*[\"']([^\"']*)[\"']\\s*\\)")
        };
        
        for (Pattern pattern : patterns) {
            Matcher matcher = pattern.matcher(source);
            while (matcher.find()) {
                if (matcher.groupCount() > 0 && matcher.group(1) != null) {
                    specifiers.add(matcher.group(1));
                }
            }
        }
        
        return specifiers;
    }

    public static class MirrorRecord {
        public Set<String> importers = new HashSet<>();
        public List<String> pluginIds = new ArrayList<>();
        public String spec;
        
        public MirrorRecord(Set<String> importers, List<String> pluginIds, String spec) {
            this.importers.addAll(importers);
            this.pluginIds.addAll(pluginIds);
            this.spec = spec;
        }
    }

    public static Map<String, MirrorRecord> collectRootDistBundledRuntimeMirrors(
            Path distDir, 
            Map<String, BundledSpecRecord> bundledSpecs) throws IOException {
        
        Map<String, MirrorRecord> mirrors = new HashMap<>();
        
        for (Path filePath : walkJavaScriptFiles(distDir)) {
            String source = new String(Files.readAllBytes(filePath));
            String relativePath = distDir.relativize(filePath).toString().replace("\\", "/");
            
            for (String specifier : extractModuleSpecifiers(source)) {
                String dependencyName = packageNameFromSpecifier(specifier);
                if (dependencyName == null || !bundledSpecs.containsKey(dependencyName)) {
                    continue;
                }
                
                BundledSpecRecord bundledSpec = bundledSpecs.get(dependencyName);
                MirrorRecord existing = mirrors.get(dependencyName);
                if (existing != null) {
                    existing.importers.add(relativePath);
                    continue;
                }
                
                mirrors.put(dependencyName, new MirrorRecord(
                    new HashSet<>(Arrays.asList(relativePath)),
                    bundledSpec.pluginIds,
                    bundledSpec.spec
                ));
            }
        }
        
        return mirrors;
    }

    public static List<String> collectBundledPluginRootRuntimeMirrorErrors(
            JsonNode rootPackageJson,
            Map<String, BundledSpecRecord> bundledRuntimeDependencySpecs,
            Map<String, MirrorRecord> requiredRootMirrors) {
        
        Map<String, String> rootRuntimeDeps = collectRuntimeDependencySpecs(rootPackageJson);
        List<String> errors = new ArrayList<>();
        
        for (Map.Entry<String, BundledSpecRecord> entry : bundledRuntimeDependencySpecs.entrySet()) {
            String dependencyName = entry.getKey();
            BundledSpecRecord record = entry.getValue();
            
            for (String conflict : record.conflicts) {
                errors.add(String.format(
                    "bundled runtime dependency '%s' has conflicting plugin specs: %s use '%s', %s.",
                    dependencyName,
                    String.join(", ", record.pluginIds),
                    record.spec,
                    conflict
                ));
            }
        }
        
        for (Map.Entry<String, MirrorRecord> entry : requiredRootMirrors.entrySet()) {
            String dependencyName = entry.getKey();
            MirrorRecord mirror = entry.getValue();
            
            List<String> sortedImporters = new ArrayList<>(mirror.importers);
            Collections.sort(sortedImporters);
            String importerLabel = String.join(", ", sortedImporters);
            
            List<String> sortedPluginIds = new ArrayList<>(mirror.pluginIds);
            Collections.sort(sortedPluginIds);
            String pluginLabel = String.join(", ", sortedPluginIds);
            
            String rootSpec = rootRuntimeDeps.get(dependencyName);
            if (rootSpec == null || rootSpec.isEmpty()) {
                errors.add(String.format(
                    "root dist imports bundled plugin runtime dependency '%s' from %s; mirror '%s: %s' in root package.json (declared by %s).",
                    dependencyName,
                    importerLabel,
                    dependencyName,
                    mirror.spec,
                    pluginLabel
                ));
                continue;
            }
            
            if (!rootSpec.equals(mirror.spec)) {
                errors.add(String.format(
                    "root dist imports bundled plugin runtime dependency '%s' from %s; root package.json has '%s' but plugin manifest declares '%s' (%s).",
                    dependencyName,
                    importerLabel,
                    rootSpec,
                    mirror.spec,
                    pluginLabel
                ));
            }
        }
        
        return errors;
    }
}
