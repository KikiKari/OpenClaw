// abstraction-provenance: {"artifact_sha256": "97833e28daa9e1e42903fa15e9d85b9bf1f02af9a4e162065b73712ce9b4ca37", "source_sha256": "994fedde2bf4a37dd0a1c17fabe831ffea24f9660e322a06d93e42b0e44a96a7", "target_language": "java"}
// test_scanner_limits.cjs — portiert nach java
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_scanner_limits.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_scanner_limits.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_scanner_limits.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_scanner_limits.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import javax.script.*;

public class TestScannerLimits {
    private static final String ROOT = Paths.get("").toAbsolutePath().getParent().toString();
    private static final Object[][] SOURCES = {
        {"browser-extension/content.js", "  function explicitCardSummary", true},
        {"mobile-shared/webview-bridge.js", "  function primaryVideo", false}
    };

    public static void main(String[] args) throws Exception {
        for (Object[] sourceInfo : SOURCES) {
            String file = (String) sourceInfo[0];
            String endMarker = (String) sourceInfo[1];
            boolean browser = (Boolean) sourceInfo[2];

            String source = readFile(Paths.get(ROOT, file).toString());
            int startIndex = source.indexOf("  async function scanRecommendations(run)");
            int endIndex = source.indexOf(endMarker, startIndex);
            String code = source.substring(startIndex, endIndex);

            if (code.length() <= 100) {
                throw new AssertionError("Code length too short");
            }

            for (int n : new int[]{1, 50, 51, 299, 300, 301}) {
                List<Object> updates = new ArrayList<>();
                List<Map<String, Object>> cards = new ArrayList<>();
                for (int i = 0; i < 301; i++) {
                    Map<String, Object> card = new HashMap<>();
                    card.put("handle", "creator" + i);
                    Map<String, Object> cardObj = new HashMap<>();
                    cardObj.put("scrollIntoView", (Runnable) () -> {});
                    cardObj.put("dispatchEvent", (Runnable) () -> {});
                    card.put("card", cardObj);
                    cards.add(card);
                }

                Map<String, Object> run = new HashMap<>();
                run.put("limit", Math.min(n, 300));
                run.put("sourceUrl", "https://www.tiktok.com/@creator/live");
                run.put("runId", "test");
                run.put("cancelled", false);

                ScriptEngine engine = new ScriptEngineManager().getEngineByName("javascript");
                Bindings bindings = engine.createBindings();

                // Setup context similar to VM context
                bindings.put("root", new HashMap<>());
                bindings.put("scrollX", 0);
                bindings.put("scrollY", 0);
                bindings.put("innerHeight", 800);
                bindings.put("location", Map.of("href", run.get("sourceUrl")));
                bindings.put("Date", Date.class);
                bindings.put("MouseEvent", MouseEvent.class);
                bindings.put("setTimeout", (ScriptFunction) fn -> {
                    try {
                        fn.call();
                        return 1;
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                });

                Map<String, Object> window = new HashMap<>();
                window.put("scrollX", 0);
                window.put("scrollY", 0);
                window.put("innerHeight", 800);
                window.put("scrollTo", (Runnable) () -> {});
                window.put("scrollBy", (Runnable) () -> {});
                bindings.put("window", window);

                bindings.put("scrollTo", (Runnable) () -> {});
                bindings.put("scrollBy", (Runnable) () -> {});
                bindings.put("activeRecommendationScan", run);
                bindings.put("RECOMMENDATION_SCAN_MAX_ROUNDS", 12);
                bindings.put("RECOMMENDATION_SCAN_MAX_MS", 45000);

                // Core module simulation
                bindings.put("core", loadCoreModule());

                bindings.put("recommendationCards", (ScriptFunction) () -> cards);
                bindings.put("recommendationItem", (ScriptFunction) (e, p) -> {
                    Map<String, Object> result = new HashMap<>();
                    result.put("handle", ((Map<?, ?>) e).get("handle"));
                    result.put("position", p);
                    result.put("title", "x".repeat(300));
                    return result;
                });
                bindings.put("text", String.class);

                bindings.put("emit", (ScriptFunction) (type, p) -> {
                    updates.add(cloneObject(p));
                    return null;
                });

                bindings.put("emitRecommendationProgress", (ScriptFunction) (r, status, items) -> {
                    Map<String, Object> obj = new HashMap<>();
                    obj.put("status", status);
                    obj.put("items", items);
                    updates.add(cloneObject(obj));
                    return null;
                });

                engine.setBindings(bindings, ScriptContext.GLOBAL_SCOPE);
                engine.eval(code);
                
                Object scanRecommendations = engine.get("scanRecommendations");
                if (scanRecommendations instanceof Invocable) {
                    ((Invocable) engine).invokeMethod(engine.eval("(function(){return this;})()"), "scanRecommendations", run);
                } else {
                    ((Invocable) engine).invokeFunction("scanRecommendations", run);
                }

                Map<?, ?> lastUpdate = (Map<?, ?>) updates.get(updates.size() - 1);
                if (!"complete".equals(lastUpdate.get("status"))) {
                    throw new AssertionError("Status is not complete");
                }

                List<?> items = (List<?>) lastUpdate.get("items");
                if (items.size() != Math.min(n, 300)) {
                    throw new AssertionError("Items length mismatch");
                }

                Map<?, ?> lastItem = (Map<?, ?>) items.get(items.size() - 1);
                if (!lastItem.get("position").equals(Math.min(n, 300))) {
                    throw new AssertionError("Last item position mismatch");
                }
            }

            System.out.println("PASS synthetic production scan loop: " + file + "; 1,50,51,299,300,301");
        }
    }

    private static String readFile(String path) throws IOException {
        return new String(Files.readAllBytes(Paths.get(path)));
    }

    private static Object cloneObject(Object obj) {
        // Simple deep clone implementation for maps and lists
        if (obj instanceof Map) {
            Map<?, ?> original = (Map<?, ?>) obj;
            Map<Object, Object> cloned = new HashMap<>();
            for (Map.Entry<?, ?> entry : original.entrySet()) {
                cloned.put(entry.getKey(), cloneObject(entry.getValue()));
            }
            return cloned;
        } else if (obj instanceof List) {
            List<?> original = (List<?>) obj;
            List<Object> cloned = new ArrayList<>();
            for (Object item : original) {
                cloned.add(cloneObject(item));
            }
            return cloned;
        } else {
            return obj; // For primitives and strings
        }
    }

    private static Object loadCoreModule() throws IOException {
        // Simulate loading the core module
        return new HashMap<>();
    }

    @FunctionalInterface
    interface ScriptFunction {
        Object call(Object... args) throws Exception;
    }

    static class MouseEvent {
        public MouseEvent() {}
    }
}
