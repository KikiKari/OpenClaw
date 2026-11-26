// abstraction-provenance: {"artifact_sha256": "4ef6383de1f6805097a7299fd4d7fb5a30a7ef6c627a767fc27cd668b0cf65dd", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "java"}
// bundle-a2ui.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.stream.Collectors;

public class BundleA2UI {

    private static final Path rootDir = Paths.get("").toAbsolutePath().getParent();
    private static final Path hashFile = rootDir.resolve("src/canvas-host/a2ui/.bundle.hash");
    private static final Path outputFile = rootDir.resolve("src/canvas-host/a2ui/a2ui.bundle.js");
    private static final Path a2uiRendererDir = rootDir.resolve("vendor/a2ui/renderers/lit");
    private static final Path a2uiAppDir = rootDir.resolve("apps/shared/OpenClawKit/Tools/CanvasA2UI");
    
    private static final List<Path> inputPaths = Arrays.asList(
        rootDir.resolve("package.json"),
        rootDir.resolve("pnpm-lock.yaml"),
        a2uiRendererDir,
        a2uiAppDir
    );
    
    private static final List<String> ignoredBundleHashInputPrefixes = Arrays.asList(
        "vendor/a2ui/renderers/lit/dist"
    );

    public static void main(String[] args) {
        try {
            new BundleA2UI().run();
        } catch (Exception e) {
            System.err.println(e.getMessage());
            System.err.println("A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle");
            System.err.println("If this persists, verify pnpm deps and try again.");
            System.exit(1);
        }
    }

    private void run() throws Exception {
        boolean hasRendererDir = Files.exists(a2uiRendererDir);
        boolean hasAppDir = Files.exists(a2uiAppDir);
        boolean hasOutputFile = Files.exists(outputFile);

        if (!hasRendererDir || !hasAppDir) {
            if (hasOutputFile) {
                System.out.println("A2UI sources missing; keeping prebuilt bundle.");
                return;
            }
            if ("1".equals(System.getenv("OPENCLAW_A2UI_SKIP_MISSING")) || 
                System.getenv("OPENCLAW_SPARSE_PROFILE") != null) {
                System.err.println(
                    "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set."
                );
                return;
            }
            throw new RuntimeException("A2UI sources missing and no prebuilt bundle found at: " + outputFile);
        }

        String currentHash = computeHash();
        if (Files.exists(hashFile)) {
            String previousHash = Files.readString(hashFile).trim();
            if (previousHash.equals(currentHash) && hasOutputFile) {
                System.out.println("A2UI bundle up to date; skipping.");
                return;
            }
        }

        runPnpm(new String[]{"-s", "exec", "tsc", "-p", a2uiRendererDir.resolve("tsconfig.json").toString()});

        Path localRolldownCli = findLocalRolldownCli();
        if (localRolldownCli != null) {
            runCommand(new String[]{System.getProperty("java.home") + "/bin/java", 
                                   localRolldownCli.toString(), 
                                   "-c", 
                                   a2uiAppDir.resolve("rolldown.config.mjs").toString()});
        } else {
            runPnpm(new String[]{"-s", "exec", "rolldown", "-c", a2uiAppDir.resolve("rolldown.config.mjs").toString()});
        }

        Files.writeString(hashFile, currentHash + "\n");
    }

    private Path findLocalRolldownCli() {
        List<Path> candidates = Arrays.asList(
            rootDir.resolve("node_modules/rolldown/bin/cli.mjs"),
            rootDir.resolve("node_modules/.pnpm/node_modules/rolldown/bin/cli.mjs"),
            rootDir.resolve("node_modules/.pnpm/rolldown@1.0.0-rc.12/node_modules/rolldown/bin/cli.mjs")
        );

        return candidates.stream()
            .filter(Files::exists)
            .findFirst()
            .orElse(null);
    }

    private List<String> listTrackedInputFiles() {
        try {
            ProcessBuilder pb = new ProcessBuilder("git", "ls-files", "--");
            inputPaths.forEach(p -> pb.command().add(rootDir.relativize(p).toString()));
            pb.directory(rootDir.toFile());
            pb.redirectError(ProcessBuilder.Redirect.INHERIT);
            
            Process process = pb.start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            List<String> files = new ArrayList<>();
            String line;
            while ((line = reader.readLine()) != null) {
                if (!line.isEmpty()) {
                    Path filePath = rootDir.resolve(line);
                    if (isBundleHashInputPath(filePath)) {
                        files.add(filePath.toString());
                    }
                }
            }
            
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                return null;
            }
            
            return files;
        } catch (Exception e) {
            return null;
        }
    }

    private String computeHash() throws Exception {
        List<String> files = listTrackedInputFiles();
        if (files == null) {
            files = new ArrayList<>();
            for (Path inputPath : inputPaths) {
                walkFiles(inputPath, files);
            }
        }

        files.sort(String.CASE_INSENSITIVE_ORDER);

        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        for (String filePathStr : files) {
            Path filePath = Paths.get(filePathStr);
            String relativePath = rootDir.relativize(filePath).toString().replace("\\", "/");
            digest.update(relativePath.getBytes());
            digest.update("\0".getBytes());
            digest.update(Files.readAllBytes(filePath));
            digest.update("\0".getBytes());
        }

        StringBuilder hexString = new StringBuilder();
        for (byte b : digest.digest()) {
            String hex = Integer.toHexString(0xff & b);
            if (hex.length() == 1) hexString.append('0');
            hexString.append(hex);
        }
        return hexString.toString();
    }

    private void walkFiles(Path entryPath, List<String> files) throws IOException {
        if (!isBundleHashInputPath(entryPath)) {
            return;
        }
        
        if (!Files.isDirectory(entryPath)) {
            files.add(entryPath.toString());
            return;
        }
        
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(entryPath)) {
            for (Path entry : stream) {
                walkFiles(entry, files);
            }
        }
    }

    private boolean isBundleHashInputPath(Path filePath) {
        String relativePath = rootDir.relativize(filePath).toString().replace("\\", "/");
        return ignoredBundleHashInputPrefixes.stream()
            .noneMatch(ignoredPath -> 
                relativePath.equals(ignoredPath) || 
                relativePath.startsWith(ignoredPath + "/"));
    }

    private void runPnpm(String[] pnpmArgs) throws Exception {
        List<String> command = new ArrayList<>();
        command.add("pnpm");
        Collections.addAll(command, pnpmArgs);
        runCommand(command.toArray(new String[0]));
    }

    private void runCommand(String[] command) throws Exception {
        ProcessBuilder pb = new ProcessBuilder(command);
        pb.directory(rootDir.toFile());
        pb.inheritIO();
        
        Process process = pb.start();
        int exitCode = process.waitFor();
        if (exitCode != 0) {
            System.exit(exitCode);
        }
    }
}
