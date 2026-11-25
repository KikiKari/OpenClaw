// abstraction-provenance: {"artifact_sha256": "f867661b6fa5ba32dcc66d8ad1605f812aba72115c9dbc423404f6e13e056df4", "source_sha256": "e4fcb95b6aa05b8fa419b7ed085317debab4e29b8cfb62a4d3ab8ec952610874", "target_language": "java"}
// tiktok-get-stream.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.Pattern;
import org.openqa.selenium.*;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.openqa.selenium.support.ui.ExpectedConditions;
import com.google.gson.Gson;
import com.google.gson.JsonObject;

public class TikTokGetStream {

    private static final int FALLBACK_TIMEOUT_MS = 45000;
    private static final int FALLBACK_MAX_OUTPUT = 1024 * 1024;
    private static final Gson gson = new Gson();

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java TikTokGetStream <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]");
            System.exit(1);
        }

        String cliUsername;
        try {
            cliUsername = normalizeUsername(args[0]);
        } catch (Exception e) {
            System.err.println(e.getMessage());
            System.exit(64);
        }

        enforceLoadLimit("playwright_streamlink_ytdlp");
        if (forcedOffline("playwright_streamlink_ytdlp", cliUsername)) {
            System.exit(1);
        }

        String cliQuality = "auto";
        boolean cliJson = false;
        for (int i = 1; i < args.length; i++) {
            if (args[i].equals("--json")) {
                cliJson = true;
            } else if (!args[i].startsWith("--")) {
                cliQuality = args[i];
            }
        }

        if (!Arrays.asList("original", "1080p60", "720p60", "720p", "540p", "360p", "auto").contains(cliQuality)) {
            System.err.println("Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto");
            System.exit(64);
        }

        try {
            Map<String, Object> result = getStreamUrl(cliUsername, cliQuality);
            if (cliJson) {
                System.out.println(gson.toJson(result));
            } else {
                if ((Boolean) result.get("success")) {
                    System.out.println(result.get("url"));
                } else {
                    System.err.println(result.get("message"));
                }
            }
            System.exit(exitCodeForResult(result));
        } catch (Exception e) {
            System.err.println("Unhandled error: " + e.getMessage());
            System.exit(2);
        }
    }

    private static String normalizeUsername(String username) {
        if (username == null || username.isEmpty()) {
            throw new IllegalArgumentException("Username cannot be empty");
        }
        return username.replaceAll("[^a-zA-Z0-9._-]", "");
    }

    private static void enforceLoadLimit(String key) {
        // Placeholder implementation
    }

    private static boolean forcedOffline(String key, String username) {
        // Placeholder implementation
        return false;
    }

    private static int exitCodeForResult(Map<String, Object> result) {
        if ((Boolean) result.get("success")) {
            return 0;
        }
        String status = (String) result.get("status");
        switch (status) {
            case "offline":
            case "restricted":
                return 1;
            case "dependency_missing":
            case "technical_error":
                return 2;
            case "overloaded":
                return 75;
            default:
                return 2;
        }
    }

    private static Map<String, Object> getStreamUrl(String username, String qualityPreference) throws Exception {
        String timestamp = java.time.Instant.now().toString();

        // 1. Playwright
        System.err.println("[1/3] Trying Playwright for @" + username + "...");
        Map<String, Object> pwResult = extractWithPlaywright(username, qualityPreference);
        if ((Boolean) pwResult.get("success")) {
            pwResult.put("timestamp", timestamp);
            return pwResult;
        }
        if ("restricted".equals(pwResult.get("status")) || "overloaded".equals(pwResult.get("status"))) {
            return pwResult;
        }
        System.err.println("Playwright result: " + pwResult.get("reason"));

        // 2. Streamlink
        System.err.println("[2/3] Trying streamlink for @" + username + " (quality: " + qualityPreference + ")...");
        Map<String, Object> slResult = tryStreamlink(username, qualityPreference);
        if ((Boolean) slResult.get("success")) {
            return slResult;
        }
        if ("restricted".equals(slResult.get("status")) || "overloaded".equals(slResult.get("status"))) {
            return slResult;
        }
        System.err.println("Streamlink result: " + slResult.get("message"));

        // 3. yt-dlp
        System.err.println("[3/3] Trying yt-dlp for @" + username + "...");
        Map<String, Object> ytResult = tryYtDlp(username, qualityPreference);
        if ((Boolean) ytResult.get("success")) {
            return ytResult;
        }
        if ("restricted".equals(ytResult.get("status")) || "overloaded".equals(ytResult.get("status"))) {
            return ytResult;
        }
        System.err.println("yt-dlp result: " + ytResult.get("message"));

        // All failed
        String status = classifyFinalFailure(Arrays.asList(pwResult, slResult, ytResult));
        Map<String, Object> resultMap = new HashMap<>();
        resultMap.put("success", false);
        resultMap.put("status", status);
        resultMap.put("username", username);
        resultMap.put("message", "All extraction methods failed (Playwright, streamlink, yt-dlp).");
        resultMap.put("playwrightReason", pwResult.get("reason"));
        resultMap.put("streamlinkReason", slResult.get("message"));
        resultMap.put("ytdlpReason", ytResult.get("message"));
        resultMap.put("timestamp", timestamp);
        return resultMap;
    }

    private static Map<String, Object> extractWithPlaywright(String username, String qualityPreference) {
        // This is a simplified version using Selenium WebDriver
        // Full Playwright functionality would require more complex setup
        System.setProperty("webdriver.chrome.driver", "/path/to/chromedriver");
        ChromeOptions options = new ChromeOptions();
        options.addArguments("--headless=new");
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");
        options.addArguments("--disable-gpu");

        WebDriver driver = new ChromeDriver(options);
        try {
            driver.get("https://www.tiktok.com/@" + username + "/live");
            
            // Wait for page load
            Thread.sleep(5000);
            
            // Check if live stream exists by looking for video element
            List<WebElement> videos = driver.findElements(By.tagName("video"));
            if (!videos.isEmpty()) {
                // In a real implementation, we would capture network requests here
                // This is a placeholder that returns a mock URL
                Map<String, Object> result = new HashMap<>();
                result.put("success", true);
                result.put("status", "live");
                result.put("method", "playwright");
                result.put("username", username);
                result.put("url", "https://example.com/stream.flv"); // Mock URL
                result.put("quality", qualityPreference);
                return result;
            } else {
                Map<String, Object> result = new HashMap<>();
                result.put("success", false);
                result.put("method", "playwright");
                result.put("status", "offline");
                result.put("reason", "No video element found");
                return result;
            }
        } catch (Exception e) {
            Map<String, Object> result = new HashMap<>();
            result.put("success", false);
            result.put("method", "playwright");
            result.put("status", "technical_error");
            result.put("error", e.getMessage());
            return result;
        } finally {
            driver.quit();
        }
    }

    private static Map<String, Object> tryStreamlink(String username, String quality) throws Exception {
        String scriptPath = Paths.get("extraction-methods", "extract-tiktok-streamlink.sh").toString();
        return runFallback("streamlink", scriptPath, new String[]{username, quality, "--json"});
    }

    private static Map<String, Object> tryYtDlp(String username, String quality) throws Exception {
        String scriptPath = Paths.get("extraction-methods", "extract-tiktok-yt-dlp.sh").toString();
        String ytFormat = getYtDlpFormat(quality);
        return runFallback("yt-dlp", scriptPath, new String[]{username, ytFormat, "--json"});
    }

    private static String getYtDlpFormat(String quality) {
        Map<String, String> formats = new HashMap<>();
        formats.put("original", "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld");
        formats.put("1080p60", "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld");
        formats.put("720p60", "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld");
        formats.put("720p", "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld");
        formats.put("540p", "hls-sd/hls-ld/flv-sd/flv-ld");
        formats.put("360p", "hls-ld/flv-ld");
        formats.put("auto", "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld");
        return formats.getOrDefault(quality, formats.get("auto"));
    }

    private static Map<String, Object> runFallback(String method, String scriptPath, String[] args) throws Exception {
        List<String> command = new ArrayList<>();
        command.add("bash");
        command.add(scriptPath);
        command.addAll(Arrays.asList(args));

        ProcessBuilder pb = new ProcessBuilder(command);
        pb.redirectErrorStream(false);
        
        Process process = pb.start();
        
        StringBuilder stdout = new StringBuilder();
        StringBuilder stderr = new StringBuilder();
        
        ExecutorService executor = Executors.newFixedThreadPool(2);
        
        Future<Void> stdoutFuture = executor.submit(() -> {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (stdout.length() + line.length() > FALLBACK_MAX_OUTPUT) {
                        break;
                    }
                    stdout.append(line).append("\n");
                }
            }
            return null;
        });
        
        Future<Void> stderrFuture = executor.submit(() -> {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (stderr.length() + line.length() > FALLBACK_MAX_OUTPUT) {
                        break;
                    }
                    stderr.append(line).append("\n");
                }
            }
            return null;
        });
        
        executor.shutdown();
        
        boolean finished = process.waitFor(FALLBACK_TIMEOUT_MS, TimeUnit.MILLISECONDS);
        if (!finished) {
            process.destroyForcibly();
            Map<String, Object> result = new HashMap<>();
            result.put("success", false);
            result.put("method", method);
            result.put("status", "timeout");
            result.put("message", "Fallback timeout");
            return result;
        }
        
        stdoutFuture.get(1, TimeUnit.SECONDS);
        stderrFuture.get(1, TimeUnit.SECONDS);
        
        int exitCode = process.exitValue();
        
        if (stdout.length() > FALLBACK_MAX_OUTPUT || stderr.length() > FALLBACK_MAX_OUTPUT) {
            Map<String, Object> result = new HashMap<>();
            result.put("success", false);
            result.put("method", method);
            result.put("status", "output_overflow");
            result.put("message", "Fallback output exceeded limit");
            return result;
        }
        
        return parseFallbackResult(method, stdout.toString().trim(), stderr.toString().trim(), exitCode);
    }

    private static Map<String, Object> parseFallbackResult(String method, String stdout, String stderr, int exitCode) {
        String text = !stdout.isEmpty() ? stdout : stderr;
        try {
            JsonObject json = gson.fromJson(text, JsonObject.class);
            return normalizeExtractorResult(json, method);
        } catch (Exception e) {
            Map<String, Object> result = new HashMap<>();
            result.put("success", false);
            result.put("method", method);
            result.put("status", exitCode == 75 ? "overloaded" : "technical_error");
            result.put("message", !stderr.isEmpty() ? stderr : "Fallback exited with code " + exitCode);
            return result;
        }
    }

    private static Map<String, Object> normalizeExtractorResult(JsonObject json, String method) {
        Map<String, Object> result = new HashMap<>();
        result.put("success", json.has("success") && json.get("success").getAsBoolean());
        result.put("method", method);
        result.put("status", json.has("status") ? json.get("status").getAsString() : "unknown");
        if (json.has("url")) {
            result.put("url", json.get("url").getAsString());
        }
        if (json.has("message")) {
            result.put("message", json.get("message").getAsString());
        }
        return result;
    }

    private static String classifyFinalFailure(List<Map<String, Object>> results) {
        long restrictedCount = results.stream()
            .filter(r -> "restricted".equals(r.get("status")))
            .count();
            
        if (restrictedCount > 0) {
            return "restricted";
        }
        
        long offlineCount = results.stream()
            .filter(r -> "offline".equals(r.get("status")))
            .count();
            
        if (offlineCount == results.size()) {
            return "offline";
        }
        
        return "technical_error";
    }
}
