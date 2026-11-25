// abstraction-provenance: {"artifact_sha256": "d7208a151f464c08af5273d16bcd32946d395697445178f0d1c3c9db714958a9", "source_sha256": "982245244dd1863414e9d3aaedaf8afbfb270bbbc18cd490fbb288290b7667d3", "target_language": "java"}
// test_sidepanel_player_guard.cjs — portiert nach java
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.function.Consumer;
import java.util.regex.Pattern;

import javax.script.ScriptEngine;
import javax.script.ScriptEngineManager;
import javax.script.ScriptException;

public class TestSidePanelPlayerGuard {

    private static final String SCRIPT_FILE_PATH = "../browser-extension/sidepanel.js";

    public static void main(String[] args) {
        try {
            runTest();
            System.out.println("PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered");
        } catch (Exception e) {
            System.err.println(e.getMessage());
            System.exit(1);
        }
    }

    private static void runTest() throws IOException, ScriptException, InterruptedException, ExecutionException {
        String source = readFileToString(Paths.get(SCRIPT_FILE_PATH));
        int start = source.indexOf("  async function refreshPlayer()");
        int end = source.indexOf("  function setButtonBusy", start);

        if (start < 0 || end <= start) {
            throw new AssertionError("Function boundaries not found in source");
        }

        int[] calls = {0};
        List<Object> rendered = new ArrayList<>();
        CompletableFuture<Void> pending = null;

        ScriptEngine engine = new ScriptEngineManager().getEngineByName("javascript");

        // Setup mock functions and variables in JavaScript context
        engine.put("activeTabId", 1);
        engine.put("activeIsTikTok", true);
        engine.put("playerContextGeneration", 0);
        engine.put("send", (java.util.function.Supplier<CompletableFuture<Object>>) () -> {
            calls[0]++;
            CompletableFuture<Object> future = new CompletableFuture<>();
            pending = future.thenAccept(result -> {});
            return future;
        });
        engine.put("renderPlayer", (Consumer<Object>) rendered::add);

        // Execute the relevant portion of the script
        String scriptToRun = source.substring(start, end);
        engine.eval(scriptToRun);

        // Simulate first call to refreshPlayer()
        Object refreshPlayerFunc = engine.get("refreshPlayer");
        if (refreshPlayerFunc == null) {
            throw new AssertionError("refreshPlayer function is not defined");
        }

        // Call refreshPlayer and simulate reply with different tab id
        CompletableFuture<?> future1 = (CompletableFuture<?>) ((javax.script.Invocable) engine).invokeFunction("refreshPlayer");
        engine.put("activeTabId", 2); // Change tab before resolving promise

        // Resolve the previous call's promise
        CompletableFuture<?> finalPending = pending;
        ((javax.script.Invocable) engine).invokeMethod(engine.get("send"), "resolve", 
                java.util.Map.of("response", java.util.Map.of("playerState", java.util.Map.of("playing", true))));

        future1.get(); // Wait for completion

        if (rendered.size() != 0) {
            throw new AssertionError("Old tab response must be ignored");
        }

        // Set activeIsTikTok to false and call refreshPlayer again
        engine.put("activeIsTikTok", false);
        ((javax.script.Invocable) engine).invokeFunction("refreshPlayer");

        if (calls[0] != 1) {
            throw new AssertionError("Non-TikTok tabs must not be polled");
        }

        // Reset activeIsTikTok and call refreshPlayer again
        engine.put("activeIsTikTok", true);
        CompletableFuture<?> future2 = (CompletableFuture<?>) ((javax.script.Invocable) engine).invokeFunction("refreshPlayer");

        // Resolve the promise
        ((javax.script.Invocable) engine).invokeMethod(engine.get("send"), "resolve",
                java.util.Map.of("response", java.util.Map.of("playerState", java.util.Map.of("playing", true))));

        future2.get();

        if (rendered.size() != 1) {
            throw new AssertionError("Current tab response must render");
        }

        // Another call to refreshPlayer with context changes
        CompletableFuture<?> future3 = (CompletableFuture<?>) ((javax.script.Invocable) engine).invokeFunction("refreshPlayer");
        engine.put("activeTabId", 3);
        engine.eval("playerContextGeneration++;");
        engine.put("activeTabId", 2);
        engine.eval("playerContextGeneration++;");

        // Resolve the promise
        ((javax.script.Invocable) engine).invokeMethod(engine.get("send"), "resolve",
                java.util.Map.of("response", java.util.Map.of("playerState", java.util.Map.of("playing", false))));

        future3.get();

        if (rendered.size() != 1) {
            throw new AssertionError("Returning to the same tab must not revive an old response");
        }

        // Check that context invalidation precedes asynchronous tab lookup
        if (!Pattern.compile("async function refresh\\(\\)\\s*\\{\\s*playerContextGeneration\\+\\+;").matcher(source).find()) {
            throw new AssertionError("Context invalidation must precede asynchronous tab lookup");
        }
    }

    private static String readFileToString(Path path) throws IOException {
        return new String(Files.readAllBytes(path));
    }
}
