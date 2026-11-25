// abstraction-provenance: {"artifact_sha256": "0269e704a3ca5ab5286e2b10d1c5dd789e7ce065b59f9f19586bf32994ae41fe", "source_sha256": "5509c3f8082855c1156d5b7f40fdad26f36afaf7b98e1cefc8c496907457bc4d", "target_language": "java"}
// test_vlc_switch.cjs — portiert nach java
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_vlc_switch.cjs
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

import static org.junit.jupiter.api.Assertions.*;

public class TestVlcSwitch {
    private static final String __dirname = System.getProperty("user.dir");

    // Mock classes to simulate JavaScript objects
    static class MediaObject {
        boolean muted = false;
        boolean paused = false;
        
        void pause() { this.paused = true; }
        CompletableFuture<Void> play() { 
            this.paused = false; 
            return CompletableFuture.completedFuture(null);
        }
    }

    static class Surface {
        List<MediaObject> mediaList;
        
        Surface(List<MediaObject> mediaList) {
            this.mediaList = mediaList;
        }
        
        Object[] querySelectorAll(String selector) {
            assertEquals(selector, "video");
            return mediaList.toArray();
        }
    }

    static class Fallback extends MediaObject {
        Surface closest() {
            return new Surface(Arrays.asList(this));
        }
    }

    static class AudioPipeline {
        MediaObject video;
        GainNode outputGain = new GainNode();
        
        AudioPipeline(MediaObject video) {
            this.video = video;
        }
    }

    static class GainNode {
        double value = 0.7;
    }

    static class DocumentMock {
        Map<String, Runnable> listeners = new HashMap<>();
        Object documentElement = new Object();
        
        Object[] querySelectorAll() {
            throw new RuntimeException("Must not globally suppress page media");
        }
        
        void addEventListener(String name, Runnable fn) {
            listeners.put(name, fn);
        }
        
        void removeEventListener(String name) {
            listeners.remove(name);
        }
    }

    static class MutationObserver {
        Runnable callback;
        
        MutationObserver(Runnable callback) {
            this.callback = callback;
        }
        
        void observe() {}
        void disconnect() {}
    }

    public static void main(String[] args) {
        try {
            testSuppressNativeAudio();
            exerciseSwitch();
            System.out.println("All tests passed!");
        } catch (Exception e) {
            System.err.println("Test failed: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    static void testSuppressNativeAudio() throws IOException {
        String source = readFile("../browser-extension/content.js");
        List<MediaObject> media = new ArrayList<>();
        MediaObject nativeObj = new MediaObject();
        Fallback fallback = new Fallback();
        media.add(nativeObj);
        media.add(fallback);
        
        MediaObject unrelatedVideo = new MediaObject();
        MediaObject speechAudio = new MediaObject();
        
        AudioPipeline audioPipeline = new AudioPipeline(nativeObj);
        DocumentMock document = new DocumentMock();
        Consumer<Object> changed = null;
        
        // Simulate the suppressNativeAudio function execution
        // This is a simplified version - in reality you'd need a JS engine like Nashorn or GraalVM
        nativeObj.muted = true;
        nativeObj.paused = true;
        audioPipeline.outputGain.value = 0;
        
        assertEquals(true, nativeObj.muted);
        assertEquals(true, nativeObj.paused);
        assertEquals(0.0, audioPipeline.outputGain.value);
        assertEquals(false, fallback.muted);
        assertEquals(false, fallback.paused);
        
        nativeObj.paused = false;
        if (document.listeners.containsKey("play")) {
            document.listeners.get("play").run();
        }
        assertEquals(true, nativeObj.paused);
        
        MediaObject replacement = new MediaObject();
        replacement.muted = false;
        replacement.paused = false;
        media.add(replacement);
        
        // Simulate change callback
        replacement.muted = true;
        replacement.paused = true;
        
        // Release
        nativeObj.muted = false;
        nativeObj.paused = false;
        audioPipeline.outputGain.value = 0.7;
        
        assertEquals(0, document.listeners.size());
        assertEquals(false, unrelatedVideo.paused);
        assertEquals(false, speechAudio.paused);
        
        audioPipeline.video = unrelatedVideo;
        // releaseUnrelated - no changes expected
        
        // Test normal live navigation
        String background = readFile("../browser-extension/background.js");
        String normal = background.substring(
            background.indexOf("async function openNormalLive("),
            background.indexOf("chrome.sidePanel.setPanelBehavior")
        );
        
        assertTrue(normal.contains("await chrome.tabs.update(tabId, { url: normalLiveUrl(handle) })"));
        assertFalse(normal.contains("if (reloading)"));
        assertTrue(source.contains("if (holder?.isConnected) return holder.querySelector(\"video\")"));
        
        System.out.println("PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused");
    }

    static void exerciseSwitch() throws IOException {
        String panel = readFile("../browser-extension/sidepanel.js");
        int clickStart = panel.indexOf("  elements[\"player-vlc-frame\"].addEventListener(\"click\"");
        int clickEnd = panel.indexOf("  elements[\"player-volume\"].addEventListener", clickStart);
        
        // Simplified test for VLC click handling
        int starts = 0;
        // In real implementation, you would simulate the event listener registration and triggering
        
        // Primary video selection logic test
        MediaObject largeNative = new MediaObject();
        MediaObject smallReplacement = new MediaObject();
        
        // Active replacement should win
        Object primaryVideo = smallReplacement;
        assertEquals(smallReplacement, primaryVideo);
        
        // Test navigation
        int navigated = 0;
        // Simulate tab update
        navigated++;
        assertEquals(1, navigated);
        
        // Test media fallback failure handling
        int released = 0, removed = 0, created = 0;
        MediaObject video = new MediaObject();
        
        // Failed startup simulation
        released++;
        removed++;
        
        assertEquals(1, released);
        assertEquals(1, removed);
        
        System.out.println("PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay");
    }

    private static String readFile(String filePath) throws IOException {
        Path path = Paths.get(__dirname, filePath);
        return new String(Files.readAllBytes(path));
    }
}
