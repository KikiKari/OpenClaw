// abstraction-provenance: {"artifact_sha256": "d25da985b70d78b0a4fec54f91023eb0af34a7580b332e259d66eb7b5984e96c", "source_sha256": "fe4ef822110d5a3d05561b87f0634182183de94f1130dc41ba19fd74bdff1653", "target_language": "java"}
// test-extension-batch.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension-batch.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class TestExtensionBatch {

    private static void printUsage() {
        System.err.println("Usage: pnpm test:extensions:batch <extension[,extension...]> [vitest args...]");
        System.err.println("       node scripts/test-extension-batch.mjs <extension[,extension...]> [vitest args...]");
    }

    private static class ParsedArgs {
        List<String> extensionIds;
        List<String> passthroughArgs;

        ParsedArgs(List<String> extensionIds, List<String> passthroughArgs) {
            this.extensionIds = extensionIds;
            this.passthroughArgs = passthroughArgs;
        }
    }

    private static ParsedArgs parseExtensionIds(List<String> rawArgs) {
        List<String> args = new ArrayList<>(rawArgs);
        List<String> extensionIds = new ArrayList<>();

        while (!args.isEmpty() && !args.get(0).startsWith("-")) {
            String[] parts = args.remove(0).split(",");
            for (String part : parts) {
                String trimmed = part.trim();
                if (!trimmed.isEmpty()) {
                    extensionIds.add(trimmed);
                }
            }
        }

        return new ParsedArgs(extensionIds, args);
    }

    private static class BatchPlanGroup {
        String config;
        List<String> extensionIds;
        List<String> roots;
        int testFileCount;

        BatchPlanGroup(String config, List<String> extensionIds, List<String> roots, int testFileCount) {
            this.config = config;
            this.extensionIds = extensionIds;
            this.roots = roots;
            this.testFileCount = testFileCount;
        }
    }

    private static class BatchPlan {
        boolean hasTests;
        int testFileCount;
        int extensionCount;
        List<BatchPlanGroup> planGroups;

        BatchPlan(boolean hasTests, int testFileCount, int extensionCount, List<BatchPlanGroup> planGroups) {
            this.hasTests = hasTests;
            this.testFileCount = testFileCount;
            this.extensionCount = extensionCount;
            this.planGroups = planGroups;
        }
    }

    private static BatchPlan resolveExtensionBatchPlan(Path cwd, List<String> extensionIds) {
        // Dies ist eine vereinfachte Implementierung
        // In einer echten Anwendung würden Sie hier die Logik aus der JavaScript-Version implementieren
        List<BatchPlanGroup> groups = new ArrayList<>();
        groups.add(new BatchPlanGroup(
            "vitest.config.ts",
            extensionIds,
            extensionIds.stream().map(id -> "./extensions/" + id).collect(Collectors.toList()),
            extensionIds.size()
        ));
        
        return new BatchPlan(
            !extensionIds.isEmpty(),
            extensionIds.size(),
            extensionIds.size(),
            groups
        );
    }

    private static int runVitestBatch(List<String> args, String config, Map<String, String> env, List<String> targets) throws IOException, InterruptedException {
        List<String> command = new ArrayList<>();
        command.add("npx");
        command.add("vitest");
        command.addAll(args);
        command.add("--config");
        command.add(config);
        command.addAll(targets);

        ProcessBuilder pb = new ProcessBuilder(command);
        pb.environment().putAll(env);
        
        Process process = pb.start();
        
        // Leite Ausgabe weiter
        BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
        String line;
        while ((line = reader.readLine()) != null) {
            System.out.println(line);
        }
        
        return process.waitFor();
    }

    private static boolean isDirectScriptRun(String mainClassName) {
        return "TestExtensionBatch".equals(mainClassName);
    }

    public static void main(String[] args) throws IOException, InterruptedException {
        if (isDirectScriptRun(TestExtensionBatch.class.getSimpleName())) {
            run(Arrays.asList(args));
        }
    }

    private static void run(List<String> rawArgs) throws IOException, InterruptedException {
        if (rawArgs.contains("--help") || rawArgs.contains("-h")) {
            printUsage();
            return;
        }

        List<String> passthroughArgs = rawArgs.stream()
            .filter(arg -> !"--".equals(arg))
            .collect(Collectors.toList());

        ParsedArgs parsed = parseExtensionIds(passthroughArgs);
        List<String> extensionIds = parsed.extensionIds;
        List<String> vitestArgs = parsed.passthroughArgs;

        if (extensionIds.isEmpty()) {
            printUsage();
            System.exit(1);
        }

        Path cwd = Paths.get("").toAbsolutePath();
        BatchPlan batchPlan = resolveExtensionBatchPlan(cwd, extensionIds);

        if (!batchPlan.hasTests) {
            System.out.println("[test-extension-batch] No tests found for the requested extensions. Skipping.");
            return;
        }

        System.out.println(
            String.format("[test-extension-batch] Running %d test files across %d extensions",
                batchPlan.testFileCount,
                batchPlan.extensionCount)
        );

        Map<String, String> env = System.getenv();

        for (BatchPlanGroup group : batchPlan.planGroups) {
            System.out.println(
                String.format("[test-extension-batch] %s: %s (%d files)",
                    group.config,
                    String.join(", ", group.extensionIds),
                    group.testFileCount)
            );
            
            int exitCode = runVitestBatch(vitestArgs, group.config, env, group.roots);
            if (exitCode != 0) {
                System.exit(exitCode);
            }
        }
    }
}
