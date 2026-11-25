// abstraction-provenance: {"artifact_sha256": "1dbcfdd8052b59c0bddb06c4ae624b9c775cd0ae0e76ce90497a96239f71c182", "source_sha256": "936c6e8c471f328a11317781bf628366871738b72e1e4ece900691507231dd15", "target_language": "java"}
// tiktok-get-stream.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.time.*;
import java.time.format.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;
import org.openqa.selenium.*;
import org.openqa.selenium.chrome.*;
import org.openqa.selenium.devtools.*;
import org.openqa.selenium.devtools.v120.network.*;
import org.openqa.selenium.devtools.v120.network.model.*;
import org.openqa.selenium.support.ui.*;
import com.google.gson.*;

public class TikTokGetStream {
    private static final int MAX_COLLECTED_URLS = 100;
    private static final Gson gson = new Gson();
    
    public static void main(String[] args) {
        boolean jsonOutput = Arrays.asList(args).contains("--json");
        String username;
        
        try {
            username = normalizeUsername(args.length > 0 ? args[0] : null);
        } catch (Exception error) {
            System.err.println("Usage: java TikTokGetStream <username>");
            System.err.println(error.getMessage());
            System.exit(64);
            return;
        }
        
        enforceLoadLimit("playwright_network_basic");
        
        if (forcedOffline("playwright_network_basic", username)) {
            System.exit(1);
            return;
        }
        
        int exitCode = getStreamUrl(username, jsonOutput);
        System.exit(exitCode);
    }
    
    private static String normalizeUsername(String input) throws Exception {
        if (input == null || input.trim().isEmpty()) {
            throw new Exception("Username required");
        }
        String normalized = input.trim().toLowerCase();
        if (!normalized.matches("^[a-z0-9._-]+$")) {
            throw new Exception("Invalid username format");
        }
        return normalized;
    }
    
    private static void enforceLoadLimit(String method) {
        // Placeholder implementation - adjust based on actual requirements
        String envVar = System.getenv("TIKTOK_LOAD_LIMIT_" + method.toUpperCase());
        if (envVar != null && !envVar.isEmpty()) {
            try {
                int limit = Integer.parseInt(envVar);
                if (limit <= 0) {
                    System.err.println(gson.toJson(createErrorObject(
                        "preflight_overload", 
                        method, 
                        "Load limit exceeded: " + limit,
                        true
                    )));
                    System.exit(75);
                }
            } catch (NumberFormatException e) {
                // Ignore invalid limits
            }
        }
    }
    
    private static boolean forcedOffline(String method, String username) {
        String offlineUsers = System.getenv("TIKTOK_OFFLINE_USERS");
        if (offlineUsers != null) {
            return Arrays.asList(offlineUsers.split(",")).contains(username);
        }
        return false;
    }
    
    private static boolean isSuccessfulStreamResponse(int status, String url) {
        return status >= 200 && status < 300 && url.contains(".flv");
    }
    
    private static String qualityKeyFromUrl(String url) {
        Pattern pattern = Pattern.compile("(\\d+)p");
        Matcher matcher = pattern.matcher(url);
        if (matcher.find()) {
            return matcher.group(1) + "p";
        }
        return "unknown";
    }
    
    private static Map<String, Object> createErrorObject(String status, String method, String message, boolean error) {
        Map<String, Object> errorObj = new HashMap<>();
        errorObj.put("error", error);
        errorObj.put("status", status);
        errorObj.put("method", method);
        errorObj.put("message", message);
        errorObj.put("timestamp", Instant.now().toString());
        return errorObj;
    }
    
    private static int getStreamUrl(String username, boolean jsonOutput) {
        // Check if ChromeDriver is available
        try {
            WebDriverManager.chromedriver().setup();
        } catch (Exception e) {
            System.err.println(gson.toJson(createErrorObject(
                "dependency_missing",
                "playwright_network_basic",
                "ChromeDriver unavailable: " + e.getMessage(),
                true
            )));
            return 2;
        }
        
        ChromeOptions options = new ChromeOptions();
        options.addArguments("--headless=new");
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");
        options.addArguments("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
        
        List<Map<String, Object>> flvUrls = new ArrayList<>();
        
        try (ChromeDriver driver = new ChromeDriver(options)) {
            DevTools devTools = driver.getDevTools();
            devTools.createSession();
            devTools.send(Network.enable(Optional.empty(), Optional.empty(), Optional.empty()));
            
            devTools.addListener(Network.responseReceived(), entry -> {
                Response response = entry.getResponse();
                String url = response.getUrl();
                if (flvUrls.size() < MAX_COLLECTED_URLS && 
                    isSuccessfulStreamResponse(response.getStatus().intValue(), url)) {
                    
                    Map<String, Object> urlEntry = new HashMap<>();
                    urlEntry.put("url", url);
                    urlEntry.put("status", response.getStatus().intValue());
                    urlEntry.put("timestamp", Instant.now().toString());
                    flvUrls.add(urlEntry);
                }
            });
            
            // Navigate to live page
            driver.get("https://www.tiktok.com/@" + username + "/live");
            
            // Wait for potential cookie dialogs
            Thread.sleep(3000);
            
            // Accept cookies if present
            try {
                WebElement acceptButton = driver.findElement(By.cssSelector("button[data-e2e='cookie-banner-accept']"));
                acceptButton.click();
                Thread.sleep(1000);
            } catch (NoSuchElementException e) {
                // No cookie banner found, continue
            }
            
            // Wait for stream to load
            Thread.sleep(8000);
            
            // Try to trigger video play if needed
            try {
                WebElement video = driver.findElement(By.tagName("video"));
                ((JavascriptExecutor) driver).executeScript("arguments[0].play()", video);
                Thread.sleep(3000);
            } catch (NoSuchElementException e) {
                // No video element found
            }
            
            if (!flvUrls.isEmpty()) {
                // Deduplicate URLs
                Map<String, Map<String, Object>> uniqueMap = new LinkedHashMap<>();
                for (Map<String, Object> item : flvUrls) {
                    uniqueMap.put((String) item.get("url"), item);
                }
                List<Map<String, Object>> uniqueUrls = new ArrayList<>(uniqueMap.values());
                
                // Sort by quality indicator
                uniqueUrls.sort((a, b) -> {
                    Pattern pattern = Pattern.compile("(\\d+)p");
                    java.util.function.Function<String, Integer> getQuality = url -> {
                        Matcher matcher = pattern.matcher(url);
                        return matcher.find() ? Integer.parseInt(matcher.group(1)) : 0;
                    };
                    return getQuality.apply((String) b.get("url")) - getQuality.apply((String) a.get("url"));
                });
                
                // Create result object
                Map<String, Object> result = new HashMap<>();
                result.put("success", true);
                result.put("status", "live");
                result.put("method", "playwright");
                result.put("username", username);
                result.put("isLive", true);
                result.put("streamCount", uniqueUrls.size());
                
                List<Map<String, Object>> streams = new ArrayList<>();
                int count = 0;
                for (Map<String, Object> item : uniqueUrls) {
                    if (count++ >= 10) break;
                    
                    Map<String, Object> streamItem = new HashMap<>(item);
                    streamItem.put("quality", qualityKeyFromUrl((String) item.get("url")));
                    streams.add(streamItem);
                }
                result.put("streams", streams);
                result.put("url", uniqueUrls.get(0).get("url"));
                result.put("timestamp", Instant.now().toString());
                
                if (jsonOutput) {
                    System.out.println(gson.toJson(result));
                } else {
                    System.out.println(result.get("url"));
                }
                return 0;
            } else {
                Map<String, Object> errorResult = new HashMap<>();
                errorResult.put("success", false);
                errorResult.put("status", "offline");
                errorResult.put("method", "playwright");
                errorResult.put("username", username);
                errorResult.put("isLive", false);
                errorResult.put("error", "No stream URLs found - user may not be live");
                errorResult.put("timestamp", Instant.now().toString());
                
                System.err.println(gson.toJson(errorResult));
                return 1;
            }
            
        } catch (Exception e) {
            Map<String, Object> errorResult = new HashMap<>();
            errorResult.put("error", true);
            errorResult.put("status", "technical_error");
            errorResult.put("method", "playwright");
            errorResult.put("message", e.getMessage());
            errorResult.put("timestamp", Instant.now().toString());
            
            System.err.println(gson.toJson(errorResult));
            return 2;
        }
    }
}
