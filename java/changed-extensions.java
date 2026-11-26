// abstraction-provenance: {"artifact_sha256": "647f09afbd22138490a467f56dbbc18b5b51ee5da1b1f84f524a20646696d1f2", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "java"}
// changed-extensions.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ChangedExtensions {
    private static final String REPO_ROOT = Paths.get("").toAbsolutePath().getParent().getParent().toString();
    private static final String BUNDLED_PLUGIN_ROOT_DIR = "plugins"; // Adjust as needed
    private static final String BUNDLED_PLUGIN_PATH_PREFIX = BUNDLED_PLUGIN_ROOT_DIR + "/";

    private static String runGit(String[] args) throws IOException, InterruptedException {
        List<String> command = new ArrayList<>();
        command.add("git");
        Collections.addAll(command, args);

        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.directory(new File(REPO_ROOT));
        processBuilder.redirectInput(ProcessBuilder.Redirect.INHERIT);
        processBuilder.redirectError(ProcessBuilder.Redirect.INHERIT);

        Process process = processBuilder.start();
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }

        int exitCode = process.waitFor();
        if (exitCode != 0) {
            throw new RuntimeException("Git command failed with exit code " + exitCode);
        }

        return output.toString().trim();
    }

    private static String normalizeRelative(String inputPath) {
        return inputPath.replace(File.separator, "/");
    }

    private static boolean hasGitCommit(String ref) {
        if (ref == null || ref.matches("^0+$")) {
            return false;
        }

        try {
            runGit(new String[]{"rev-parse", "--verify", ref + "^{commit}"});
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static String resolveChangedPathsBase(String base, String head, String fallbackBaseRef) {
        if (hasGitCommit(base)) {
            return base;
        }

        if (fallbackBaseRef != null && !fallbackBaseRef.isEmpty()) {
            String remoteBaseRef = fallbackBaseRef.startsWith("origin/") ? fallbackBaseRef : "origin/" + fallbackBaseRef;
            if (hasGitCommit(remoteBaseRef)) {
                try {
                    String mergeBase = runGit(new String[]{"merge-base", remoteBaseRef, head}).trim();
                    if (hasGitCommit(mergeBase)) {
                        return mergeBase;
                    }
                } catch (Exception e) {
                    // Ignore and continue
                }
            }
        }

        if (base == null || base.isEmpty()) {
            throw new RuntimeException("A git base revision is required to list changed extensions.");
        }

        throw new RuntimeException("Git base revision is unavailable locally: " + base);
    }

    private static List<String> listChangedPaths(String base, String head) {
        if (base == null || base.isEmpty()) {
            throw new RuntimeException("A git base revision is required to list changed extensions.");
        }

        try {
            String output = runGit(new String[]{"diff", "--name-only", base, head});
            String[] lines = output.split("\n");
            List<String> result = new ArrayList<>();
            for (String line : lines) {
                line = line.trim();
                if (!line.isEmpty()) {
                    result.add(line);
                }
            }
            return result;
        } catch (Exception e) {
            throw new RuntimeException("Failed to list changed paths", e);
        }
    }

    private static boolean hasExtensionPackage(String extensionId) {
        Path packageJsonPath = Paths.get(REPO_ROOT, BUNDLED_PLUGIN_ROOT_DIR, extensionId, "package.json");
        return Files.exists(packageJsonPath);
    }

    public static List<String> listAvailableExtensionIds() {
        Path extensionsDir = Paths.get(REPO_ROOT, BUNDLED_PLUGIN_ROOT_DIR);
        if (!Files.exists(extensionsDir)) {
            return new ArrayList<>();
        }

        List<String> extensionIds = new ArrayList<>();
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(extensionsDir)) {
            for (Path entry : stream) {
                if (Files.isDirectory(entry) && hasExtensionPackage(entry.getFileName().toString())) {
                    extensionIds.add(entry.getFileName().toString());
                }
            }
        } catch (IOException e) {
            throw new RuntimeException("Failed to list available extension IDs", e);
        }

        Collections.sort(extensionIds);
        return extensionIds;
    }

    public static List<String> detectChangedExtensionIds(List<String> changedPaths) {
        Set<String> extensionIds = new HashSet<>();
        Pattern extensionPattern = Pattern.compile("^" + BUNDLED_PLUGIN_PATH_PREFIX.replace("/", "\\/") + "([^/]+)(?:/|$)");
        Pattern pairedCorePattern = Pattern.compile("^src\\/([^/]+)(?:\\/|$)");

        for (String rawPath : changedPaths) {
            String relativePath = normalizeRelative(rawPath.trim());
            if (relativePath.isEmpty()) {
                continue;
            }

            Matcher extensionMatcher = extensionPattern.matcher(relativePath);
            if (extensionMatcher.find()) {
                String extensionId = extensionMatcher.group(1);
                if (hasExtensionPackage(extensionId)) {
                    extensionIds.add(extensionId);
                }
                continue;
            }

            Matcher pairedCoreMatcher = pairedCorePattern.matcher(relativePath);
            if (pairedCoreMatcher.find()) {
                String extensionId = pairedCoreMatcher.group(1);
                if (hasExtensionPackage(extensionId)) {
                    extensionIds.add(extensionId);
                }
            }
        }

        List<String> sortedExtensionIds = new ArrayList<>(extensionIds);
        Collections.sort(sortedExtensionIds);
        return sortedExtensionIds;
    }

    public static List<String> listChangedExtensionIds(String base, String head, String fallbackBaseRef, String unavailableBaseBehavior) {
        head = (head != null) ? head : "HEAD";
        unavailableBaseBehavior = (unavailableBaseBehavior != null) ? unavailableBaseBehavior : "error";

        try {
            String resolvedBase = resolveChangedPathsBase(base, head, fallbackBaseRef);
            List<String> changedPaths = listChangedPaths(resolvedBase, head);
            return detectChangedExtensionIds(changedPaths);
        } catch (Exception error) {
            if ("all".equals(unavailableBaseBehavior)) {
                return listAvailableExtensionIds();
            }
            if ("empty".equals(unavailableBaseBehavior)) {
                return new ArrayList<>();
            }
            throw error;
        }
    }

    // Convenience method with default parameters
    public static List<String> listChangedExtensionIds() {
        return listChangedExtensionIds(null, null, null, null);
    }
}
