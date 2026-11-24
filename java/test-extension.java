// abstraction-provenance: {"artifact_sha256": "c19ae3745981aac994b684ffbabbbaded71986026fe0aed0d04cbc21eb770510", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "java"}
// test-extension.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class TestExtension {

    private static void printUsage() {
        System.err.println("Usage: pnpm test:extension <extension-name|path> [vitest args...]");
        System.err.println("       node scripts/test-extension.mjs [extension-name|path] [vitest args...]");
    }

    private static void printNoTestsMessage(ExtensionTestPlan plan) {
        System.out.println("[test-extension] No tests found for " + plan.extensionDir + ". Skipping.");
    }

    private static boolean isDirectScriptRun(String scriptPath) {
        // In Java, we can't easily determine if this is a direct run like in Node.js
        // This is a simplified version - you might need to adjust based on your execution context
        return true;
    }

    public static void main(String[] args) throws IOException, InterruptedException, URISyntaxException {
        List<String> rawArgs = new ArrayList<>(Arrays.asList(args));
        
        if (rawArgs.contains("--help") || rawArgs.contains("-h")) {
            printUsage();
            return;
        }

        List<String> passthroughArgs = rawArgs.stream()
                .filter(arg -> !"--".equals(arg))
                .collect(Collectors.toList());

        String targetArg = null;
        if (!passthroughArgs.isEmpty() && !passthroughArgs.get(0).startsWith("-")) {
            targetArg = passthroughArgs.remove(0);
        }

        ExtensionTestPlan plan;
        try {
            plan = ExtensionTestPlan.resolveExtensionTestPlan(new File("").getAbsolutePath(), targetArg);
        } catch (Exception error) {
            printUsage();
            System.err.println(ErrorFormat.formatErrorMessage(error));
            System.exit(1);
            return;
        }

        if (!plan.hasTests) {
            printNoTestsMessage(plan);
            return;
        }

        System.out.println("[test-extension] Running " + plan.testFileCount + " test files for " + plan.extensionId);
        
        VitestBatchRunner.VitestBatchConfig config = new VitestBatchRunner.VitestBatchConfig(
                passthroughArgs,
                plan.config,
                System.getenv(),
                plan.roots
        );
        
        int exitCode = VitestBatchRunner.runVitestBatch(config);
        System.exit(exitCode);
    }
}
