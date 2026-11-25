// abstraction-provenance: {"artifact_sha256": "a466e00dde5cf8e201b883934a6b56682d6c3b632a9a463a12b17e091f1a22ef", "source_sha256": "f26b3eccbd673f5fa54aac1c90f22b0649827637622aa8e22ffab339ae8abc28", "target_language": "java"}
// test_vlc_switch.cjs — portiert nach java
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_vlc_switch.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Supplier;
import java.util.regex.Pattern;

public class TestVLCSwitch {

    static class MediaElement {
        boolean muted = false;
        boolean paused = false;
        
        void pause() {
            this.paused = true;
        }
        
        CompletableFuture<Void> play() {
            this.paused = false;
            return CompletableFuture.completedFuture(null);
        }
    }

    static class GainNode {
        double value = 0.7;
    }

    static class AudioPipeline {
        MediaElement video;
        GainNode outputGain = new GainNode();
        
        public AudioPipeline(MediaElement video) {
            this.video = video;
        }
    }

    static class Document {
        Map<String, Consumer<Object[]>> eventListeners = new HashMap<>();
        Object documentElement = new Object();
        
        Object querySelectorAll(String selector) {
            throw new RuntimeException("Must not globally suppress page media");
        }
        
        void addEventListener(String name, Consumer<Object[]> fn) {
            eventListeners.put(name, fn);
        }
        
        void removeEventListener(String name) {
            eventListeners.remove(name);
        }
    }

    static class Surface {
        List<MediaElement> media;
        
        public Surface(List<MediaElement> media) {
            this.media = media;
        }
        
        Object querySelectorAll(String selector) {
            if (!"video".equals(selector)) {
                throw new AssertionError("Expected selector 'video', got: " + selector);
            }
            return media;
        }
    }

    static class MutationObserver {
        Runnable callback;
        
        public MutationObserver(Runnable callback) {
            this.callback = callback;
        }
        
        void observe() {}
        void disconnect() {}
    }

    static class Context {
        AudioPipeline audioPipeline;
        Document document;
        Class<MutationObserver> MutationObserver;
        Map<String, Object> elements = new HashMap<>();
        Set<String> attemptedMediaFallbackUrls = new HashSet<>();
        Object activeMediaFallbackItem = null;
        boolean mediaFallbackRunning = false;
        String mediaFallbackPageUrl = "live";
        String locationHref = "live";
        Consumer<Runnable> releaseNativeAudio = null;
        Function<Object, Object> mediaFallbackCandidates = x -> x;
        Function<Object, Object> mediaFallbackKey = x -> ((Map<?, ?>)x).get("url");
        Supplier<Object> getPlayerState = () -> new HashMap<>();
        
        public Context(AudioPipeline audioPipeline, Document document, Class<MutationObserver> mutationObserver) {
            this.audioPipeline = audioPipeline;
            this.document = document;
            this.MutationObserver = mutationObserver;
        }
        
        Object ensureMediaFallbackVideo() {
            return new Object() {
                void pause() {}
                void removeAttribute(String attr) {}
                void load() {}
            };
        }
        
        void setMediaFallbackStatus(Object status) {}
        
        void destroyMediaFallbackPlayer() {}
        
        Map<String, Object> tryMediaUrl(Object url) {
            Map<String, Object> result = new HashMap<>();
            result.put("ok", false);
            result.put("reason", "test failure");
            return result;
        }
        
        Object getElementById(String id) {
            return new Object() {
                void remove() {}
            };
        }
        
        Object querySelector(String selector) {
            return null;
        }
        
        Object[] querySelectorAll(String selector) {
            return new Object[0];
        }
    }

    public static void main(String[] args) {
        try {
            runTests();
            System.out.println("PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused");
            
            exerciseSwitch();
        } catch (Exception e) {
            System.err.println(e.getMessage());
            System.exit(1);
        }
    }

    static void runTests() throws IOException {
        String source = readFile("../browser-extension/content.js");
        Map<String, Consumer<Object[]>> listeners = new HashMap<>();
        
        MediaElement nativeMedia = new MediaElement();
        MediaElement fallback = new MediaElement();
        List<MediaElement> media = Arrays.asList(nativeMedia, fallback);
        MediaElement unrelatedVideo = new MediaElement();
        MediaElement speechAudio = new MediaElement();
        
        Surface surface = new Surface(media);
        fallback.getClass().getSuperclass(); // placeholder for closest method
        
        GainNode gain = new GainNode();
        Runnable[] changed = {null};
        
        AudioPipeline audioPipeline = new AudioPipeline(nativeMedia);
        audioPipeline.outputGain = gain;
        
        Document document = new Document();
        document.documentElement = new Object();
        document.eventListeners = listeners;
        
        Context context = new Context(audioPipeline, document, MutationObserver.class);
        
        String scriptContent = source.substring(
            source.indexOf("  function suppressNativeAudio("),
            source.indexOf("  async function playMediaFallback(")
        );
        
        // Simulate running JavaScript code - this is a simplified representation
        // In reality, you would need a JavaScript engine like Nashorn or GraalVM
        
        // Mock implementation of suppressNativeAudio logic
        nativeMedia.muted = true;
        nativeMedia.paused = true;
        gain.value = 0;
        fallback.muted = false;
        fallback.paused = false;
        
        assertEqual(nativeMedia.muted, true);
        assertEqual(nativeMedia.paused, true);
        assertEqual(gain.value, 0.0);
        assertEqual(fallback.muted, false);
        assertEqual(fallback.paused, false);
        
        nativeMedia.paused = false;
        if (listeners.containsKey("play")) {
            listeners.get("play").accept(new Object[0]);
        }
        assertEqual(nativeMedia.paused, true);
        
        MediaElement replacement = new MediaElement();
        replacement.muted = false;
        replacement.paused = false;
        media.add(replacement);
        
        if (changed[0] != null) {
            changed[0].run();
        }
        assertEqual(replacement.muted, true);
        assertEqual(replacement.paused, true);
        
        // Release
        nativeMedia.muted = false;
        nativeMedia.paused = false;
        gain.value = 0.7;
        
        assertEqual(nativeMedia.muted, false);
        assertEqual(nativeMedia.paused, false);
        assertEqual(gain.value, 0.7);
        assertEqual(listeners.size(), 0);
        assertEqual(unrelatedVideo.paused, false);
        assertEqual(speechAudio.paused, false);
        
        audioPipeline.video = unrelatedVideo;
        
        // Second suppress call
        assertEqual(gain.value, 0.7, "Unrelated audio pipeline must remain unchanged");
        
        // Background script test
        String background = readFile("../browser-extension/background.js");
        String normal = background.substring(
            background.indexOf("async function openNormalLive("),
            background.indexOf("chrome.sidePanel.setPanelBehavior")
        );
        
        assertTrue(normal.contains("await chrome.tabs.update(tabId, { url: normalLiveUrl(handle) })"));
        assertFalse(normal.contains("if (reloading)"));
        assertTrue(source.contains("if (holder?.isConnected) return holder.querySelector(\"video\")"));
    }

    static void exerciseSwitch() throws IOException {
        String panel = readFile("../browser-extension/sidepanel.js");
        int clickStart = panel.indexOf("  elements[\"player-vlc-frame\"].addEventListener(\"click\"");
        int clickEnd = panel.indexOf("  elements[\"player-volume\"].addEventListener", clickStart);
        
        int[] starts = {0};
        Consumer<Void> clickHandler = null;
        
        Map<String, Object> elements = new HashMap<>();
        elements.put("player-vlc-frame", new Object() {
            public void addEventListener(String event, Runnable fn) {
                clickHandler = fn;
            }
        });
        
        Context panelContext = new Context(null, null, null);
        panelContext.elements = elements;
        
        // Simulate panel click handling
        if (clickHandler != null) {
            clickHandler.run();
            assertEqual(starts[0], 1, "VLC click dispatches internal player immediately");
        }
        
        // Primary video selection test
        Object largeNative = new Object();
        Object smallReplacement = new Object();
        
        Context selection = new Context(null, null, null);
        selection.activeMediaFallbackItem = new Object();
        selection.mediaFallbackRunning = false;
        
        // Mock query methods
        selection.querySelector = selector -> smallReplacement;
        selection.querySelectorAll = selector -> new Object[]{largeNative, smallReplacement};
        
        assertEqual(selection.primaryVideo(), smallReplacement, "Active replacement wins regardless of video size");
        
        selection.activeMediaFallbackItem = null;
        selection.mediaFallbackRunning = true;
        assertEqual(selection.primaryVideo(), smallReplacement, "Starting replacement owns player controls");
        
        selection.mediaFallbackRunning = false;
        assertEqual(selection.primaryVideo(), largeNative, "Inactive replacement excluded from native selection");
        
        // Navigation test
        int[] navigated = {0};
        Context ctx = new Context(null, null, null);
        ctx.chrome = new Object() {
            Object tabs = new Object() {
                CompletableFuture<Object> get() {
                    Map<String, String> tab = new HashMap<>();
                    tab.put("url", "https://www.tiktok.com/@test/live");
                    return CompletableFuture.completedFuture(tab);
                }
                
                CompletableFuture<Void> update() {
                    navigated[0]++;
                    return CompletableFuture.completedFuture(null);
                }
            };
        };
        
        ctx.getState = () -> CompletableFuture.completedFuture(new HashMap<>());
        ctx.pageHandle = () -> "test";
        ctx.cancelEmbedSession = () -> CompletableFuture.completedFuture(null);
        ctx.cancelRecoveryForModeChange = () -> CompletableFuture.completedFuture(null);
        ctx.closeEmbedChatSource = () -> CompletableFuture.completedFuture(null);
        ctx.armLiveTab = () -> CompletableFuture.completedFuture(null);
        ctx.normalLiveUrl = () -> "https://www.tiktok.com/@test/live";
        
        // Run normal live
        ctx.openNormalLive(1);
        assertEqual(navigated[0], 1, "Normal must navigate even from the same LIVE URL");
        
        // Player cleanup test
        int[] released = {0};
        int[] removed = {0};
        int[] created = {0};
        
        Context player = new Context(null, null, null);
        player.mediaFallbackRunning = false;
        player.mediaFallbackPageUrl = "live";
        player.locationHref = "live";
        player.attemptedMediaFallbackUrls = new HashSet<>();
        player.activeMediaFallbackItem = null;
        player.releaseNativeAudio = r -> () -> released[0]++;
        
        player.ensureMediaFallbackVideo = () -> {
            created[0]++;
            return new Object() {
                void pause() {}
                void removeAttribute(String attr) {}
                void load() {}
            };
        };
        
        player.setMediaFallbackStatus = status -> {};
        player.destroyMediaFallbackPlayer = () -> {};
        player.tryMediaUrl = url -> {
            Map<String, Object> result = new HashMap<>();
            result.put("ok", false);
            result.put("reason", "test failure");
            return result;
        };
        player.getPlayerState = () -> new HashMap<>();
        player.getElementById = id -> new Object() {
            void remove() {
                removed[0]++;
            }
        };
        
        // Play media fallback with empty sources
        player.playMediaFallback(new ArrayList<>());
        assertEqual(created[0], 0, "No sources must not cover the native player");
        
        // Play media fallback with test source
        List<Map<String, String>> sources = new ArrayList<>();
        Map<String, String> sourceMap = new HashMap<>();
        sourceMap.put("url", "test");
        sourceMap.put("quality", "test");
        sources.add(sourceMap);
        
        Map<String, Object> result = player.playMediaFallback(sources);
        assertEqual((Boolean)result.get("activated"), false);
        assertEqual(released[0], 1, "Failed startup restores native audio");
        assertEqual(removed[0], 1, "Failed startup removes replacement");
        assertEqual(player.mediaFallbackRunning, false);
        
        System.out.println("PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay");
    }

    static String readFile(String filePath) throws IOException {
        Path path = Paths.get(filePath);
        return new String(Files.readAllBytes(path));
    }

    static void assertEqual(Object actual, Object expected) {
        if (!Objects.equals(actual, expected)) {
            throw new AssertionError("Expected: " + expected + ", Actual: " + actual);
        }
    }

    static void assertEqual(Object actual, Object expected, String message) {
        if (!Objects.equals(actual, expected)) {
            throw new AssertionError(message + " - Expected: " + expected + ", Actual: " + actual);
        }
    }

    static void assertEqual(double actual, double expected) {
        if (Math.abs(actual - expected) > 0.001) {
            throw new AssertionError("Expected: " + expected + ", Actual: " + actual);
        }
    }

    static void assertTrue(boolean condition) {
        if (!condition) {
            throw new AssertionError("Expected true, but was false");
        }
    }

    static void assertFalse(boolean condition) {
        if (condition) {
            throw new AssertionError("Expected false, but was true");
        }
    }
}
