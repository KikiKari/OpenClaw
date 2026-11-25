// abstraction-provenance: {"artifact_sha256": "a690a8edf4f61a3c9288c9a32483671da79501925a9a4d10575555bba325c36c", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "java"}
// tiktok-common.test.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.regex.Pattern;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.URI;
import java.io.IOException;

public class TikTokCommonTest {

    // Mock environment variables map
    private Map<String, String> mockEnv = new HashMap<>();

    @Test
    public void testNormalizeUsername() {
        assertEquals("example_creator", normalizeUsername("@example_creator"));
        assertEquals("example_creator", normalizeUsername(" example_creator "));
        assertThrows(IllegalArgumentException.class, () -> normalizeUsername("example_creator;id"));
    }

    @Test
    public void testLiveHrefSelectors() {
        List<String> expected = Arrays.asList(
            "a[href=\"/example_creator/live\"]",
            "a[href^=\"/example_creator/live?\"]"
        );
        assertEquals(expected, liveHrefSelectors("example_creator"));
    }

    @Test
    public void testLoadState() {
        mockEnv.put("TIKTOK_TEST_LOAD_PER_CPU", "2");
        mockEnv.put("TIKTOK_MAX_LOAD_PER_CPU", "1.5");
        LoadStateResult result = loadState(mockEnv);
        assertTrue(result.overloaded);
    }

    @Test
    public void testIsAllowedStreamUrl() {
        assertTrue(isAllowedStreamUrl("https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x"));
        assertFalse(isAllowedStreamUrl("https://attacker.example/path/tiktokcdn/video.flv"));
        assertFalse(isAllowedStreamUrl("http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv"));
    }

    @Test
    public void testIsSuccessfulStreamResponse() {
        String allowedUrl = "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x";
        assertTrue(isSuccessfulStreamResponse(200, allowedUrl));
        assertTrue(isSuccessfulStreamResponse(206, allowedUrl));
        assertFalse(isSuccessfulStreamResponse(404, allowedUrl));
    }

    @Test
    public void testNormalizeExtractorResult() {
        ExtractorResult result1 = new ExtractorResult(false, "offline", null);
        ExtractorResult normalized1 = normalizeExtractorResult(result1, "streamlink", "example_creator");
        assertEquals("technical_error", normalized1.status);

        ExtractorResult result2 = new ExtractorResult(true, "live", null);
        ExtractorResult normalized2 = normalizeExtractorResult(result2, "streamlink", "example_creator");
        assertEquals("technical_error", normalized2.status);

        String allowedUrl = "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x";
        ExtractorResult result3 = new ExtractorResult(false, "offline", allowedUrl);
        ExtractorResult normalized3 = normalizeExtractorResult(result3, "streamlink", "example_creator");
        assertEquals("offline", normalized3.status);
        assertNull(normalized3.url);

        ExtractorResult result4 = new ExtractorResult(true, "live", allowedUrl);
        ExtractorResult normalized4 = normalizeExtractorResult(result4, "streamlink", "example_creator");
        assertEquals("live", normalized4.status);
    }

    @Test
    public void testClassifyFinalFailure() {
        List<ExtractorResult> results = Arrays.asList(
            new ExtractorResult(false, "offline", null),
            new ExtractorResult(false, "dependency_missing", null)
        );
        assertEquals("offline", classifyFinalFailure(results));
    }

    @Test
    public void testExitCodeForResult() {
        ExtractorResult result1 = new ExtractorResult(false, "restricted", null);
        assertEquals(1, exitCodeForResult(result1));

        ExtractorResult result2 = new ExtractorResult(false, "technical_error", null);
        assertEquals(2, exitCodeForResult(result2));
    }

    @Test
    public void testClassifyDirectLiveState() {
        LiveState state1 = new LiveState(
            "example_creator",
            "/example_creator/live",
            "Example (example_creator) is LIVE - TikTok LIVE",
            "Dieses LIVE enthält Themen, die unangenehm sein könnten.",
            false
        );
        assertEquals("restricted", classifyDirectLiveState(state1).status);

        LiveState state2 = new LiveState(
            "example_creator",
            "/example_creator/live",
            "Example (example_creator) is LIVE - TikTok LIVE",
            "LIVE has ended",
            false
        );
        assertEquals("offline", classifyDirectLiveState(state2).status);

        LiveState state3 = new LiveState(
            "example_creator",
            "/example_creator/live",
            "Example (example_creator) is LIVE - TikTok LIVE",
            "Suggested LIVE creators",
            true
        );
        assertEquals("live", classifyDirectLiveState(state3).status);
    }

    // Helper methods and classes to mimic JavaScript functionality

    static class ExtractorResult {
        boolean success;
        String status;
        String url;

        ExtractorResult(boolean success, String status, String url) {
            this.success = success;
            this.status = status;
            this.url = url;
        }
    }

    static class LoadStateResult {
        boolean overloaded;
        double loadPerCpu;
        double maxLoadPerCpu;

        LoadStateResult(boolean overloaded, double loadPerCpu, double maxLoadPerCpu) {
            this.overloaded = overloaded;
            this.loadPerCpu = loadPerCpu;
            this.maxLoadPerCpu = maxLoadPerCpu;
        }
    }

    static class LiveState {
        String username;
        String currentPath;
        String title;
        String bodyText;
        boolean successfulStreamResponse;

        LiveState(String username, String currentPath, String title, String bodyText, boolean successfulStreamResponse) {
            this.username = username;
            this.currentPath = currentPath;
            this.title = title;
            this.bodyText = bodyText;
            this.successfulStreamResponse = successfulStreamResponse;
        }
    }

    static class ClassificationResult {
        String status;
        String url;

        ClassificationResult(String status, String url) {
            this.status = status;
            this.url = url;
        }
    }

    private String normalizeUsername(String username) {
        if (username.contains(";")) {
            throw new IllegalArgumentException("Username contains invalid character ';'");
        }
        return username.trim().replaceFirst("^@", "");
    }

    private List<String> liveHrefSelectors(String username) {
        return Arrays.asList(
            "a[href=\"/" + username + "/live\"]",
            "a[href^=\"/" + username + "/live?\"]"
        );
    }

    private LoadStateResult loadState(Map<String, String> env) {
        double testLoad = Double.parseDouble(env.getOrDefault("TIKTOK_TEST_LOAD_PER_CPU", "0"));
        double maxLoad = Double.parseDouble(env.getOrDefault("TIKTOK_MAX_LOAD_PER_CPU", "0"));
        return new LoadStateResult(testLoad > maxLoad, testLoad, maxLoad);
    }

    private boolean isAllowedStreamUrl(String url) {
        return url.startsWith("https://") && 
               Pattern.compile(".*\\.tiktokcdn.*\\.com/").matcher(url).matches();
    }

    private boolean isSuccessfulStreamResponse(int statusCode, String url) {
        return (statusCode == 200 || statusCode == 206) && isAllowedStreamUrl(url);
    }

    private ExtractorResult normalizeExtractorResult(ExtractorResult result, String extractor, String username) {
        if ("true".equals(String.valueOf(result.success)) && "live".equals(result.status)) {
            return new ExtractorResult(false, "technical_error", null);
        }
        if (!result.success && "offline".equals(result.status)) {
            return new ExtractorResult(false, "offline", null);
        }
        if (result.success && "live".equals(result.status) && isAllowedStreamUrl(result.url)) {
            return result;
        }
        return new ExtractorResult(false, "technical_error", null);
    }

    private String classifyFinalFailure(List<ExtractorResult> results) {
        for (ExtractorResult result : results) {
            if ("offline".equals(result.status) || "dependency_missing".equals(result.status)) {
                return result.status;
            }
        }
        return "unknown";
    }

    private int exitCodeForResult(ExtractorResult result) {
        switch (result.status) {
            case "restricted": return 1;
            case "technical_error": return 2;
            default: return 0;
        }
    }

    private ClassificationResult classifyDirectLiveState(LiveState state) {
        if (state.currentPath.equals("/" + state.username + "/live")) {
            if (state.bodyText.contains("unangenehm") || state.bodyText.contains("inappropriate")) {
                return new ClassificationResult("restricted", null);
            }
            if (state.bodyText.contains("ended") || state.bodyText.contains("beendet")) {
                return new ClassificationResult("offline", null);
            }
            if (state.successfulStreamResponse) {
                return new ClassificationResult("live", null);
            }
        }
        return new ClassificationResult("unknown", null);
    }
}
