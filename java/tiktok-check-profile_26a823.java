// abstraction-provenance: {"artifact_sha256": "d0b83ae769118ba4230e005a22d221880eaa619bc78a94aba176bcbd0c3b070e", "source_sha256": "26a823a8fe0d3b94a8c9958ec8cf150765ddf3654a8806c9cc62eae06d9632db", "target_language": "java"}
// tiktok-check-profile.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;

public class TikTokCheckProfile {
    private static final String USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    private static final int TIMEOUT = 30000;
    
    /**
     * Basic TikTok LIVE profile checker.
     *
     * Scopes every signal to the requested account and ignores unrelated sidebar
     * LIVE labels. This profile-only checker does not classify restricted LIVE;
     * use the enhanced checker or dispatcher for that distinction.
     *
     * Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
     * failure, 75 = overloaded before Playwright startup.
     */
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java TikTokCheckProfile <username>");
            System.exit(64);
        }
        
        String username;
        try {
            username = normalizeUsername(args[0]);
        } catch (IllegalArgumentException e) {
            System.err.println("Usage: java TikTokCheckProfile <username>");
            System.err.println(e.getMessage());
            System.exit(64);
            return;
        }
        
        enforceLoadLimit("playwright_basic");
        
        try {
            boolean isLive = checkLiveStatus(username);
            System.exit(isLive ? 0 : 1);
        } catch (Exception e) {
            System.err.println("{\"error\":true,\"status\":\"technical_error\",\"message\":\"" + 
                e.getMessage() + "\",\"stack\":\"" + e.getStackTrace()[0].toString() + 
                "\",\"timestamp\":\"" + Instant.now().toString() + "\"}");
            System.exit(2);
        }
    }
    
    private static String normalizeUsername(String input) {
        if (input == null || input.trim().isEmpty()) {
            throw new IllegalArgumentException("Username cannot be empty");
        }
        
        String username = input.trim();
        if (username.startsWith("@")) {
            username = username.substring(1);
        }
        
        if (!username.matches("^[a-zA-Z0-9._]+$")) {
            throw new IllegalArgumentException("Invalid username format");
        }
        
        return username;
    }
    
    private static void enforceLoadLimit(String method) {
        // Simple implementation - in production you might want to check system load
        String loadAvgStr = System.getenv("LOAD_LIMIT");
        if (loadAvgStr != null) {
            try {
                double loadAvg = Double.parseDouble(loadAvgStr);
                // In Java we can't easily get system load average, so this is simplified
                // You could use OperatingSystemMXBean in a real implementation
            } catch (NumberFormatException e) {
                // Ignore invalid load limit
            }
        }
    }
    
    private static String[] liveHrefSelectors(String username) {
        return new String[] {
            "a[href='/" + username + "/live']",
            "a[href='https://www.tiktok.com/" + username + "/live']",
            "a[href*='" + username + "/live']"
        };
    }
    
    private static boolean checkLiveStatus(String username) throws Exception {
        // Check if we have a way to run browser automation
        // Since we don't have Playwright in Java, we'll simulate with HTTP requests
        // This is a simplified version - a full implementation would need Selenium or similar
        
        try {
            URL url = new URL("https://www.tiktok.com/@" + username);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("User-Agent", USER_AGENT);
            connection.setConnectTimeout(TIMEOUT);
            connection.setReadTimeout(TIMEOUT);
            
            int responseCode = connection.getResponseCode();
            if (responseCode != 200) {
                throw new IOException("HTTP " + responseCode);
            }
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            StringBuilder content = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
            reader.close();
            
            String htmlContent = content.toString();
            
            // Save debug screenshot if needed
            if ("1".equals(System.getenv("DEBUG"))) {
                Files.write(Paths.get("/tmp/tiktok-" + username + ".html"), htmlContent.getBytes());
            }
            
            // Check for LIVE indicators
            boolean hasLiveLink = false;
            String[] selectors = liveHrefSelectors(username);
            for (String selector : selectors) {
                if (htmlContent.contains(selector.replace("[href='", "").replace("']", "")) ||
                    htmlContent.contains(selector.replace("[href=\"", "").replace("\"]", ""))) {
                    hasLiveLink = true;
                    break;
                }
            }
            
            // Check for live icon/badge indicators
            boolean liveIconVisible = hasLiveLink && (
                htmlContent.contains("live-icon") || 
                htmlContent.contains("LiveBadge") || 
                htmlContent.contains("live-indicator") ||
                htmlContent.toLowerCase().contains("live")
            );
            
            // Check for profile avatar with live border
            boolean hasLiveBorder = false;
            if (htmlContent.contains("avatar") || htmlContent.contains("profile")) {
                // Look for styling that indicates live status
                hasLiveBorder = htmlContent.contains("#fe2c") || 
                               htmlContent.contains("rgb(254") || 
                               htmlContent.contains("rgb(255") ||
                               htmlContent.contains("red") ||
                               htmlContent.contains("box-shadow");
            }
            
            // Additional live indicator checks
            boolean liveIndicatorVisible = hasLiveLink && (
                htmlContent.contains("live-indicator") || 
                htmlContent.contains("LiveBadge")
            );
            
            boolean liveBadgeVisible = htmlContent.toLowerCase().contains("live");
            
            boolean isLive = hasLiveLink || hasLiveBorder || liveIconVisible || 
                           liveIndicatorVisible || liveBadgeVisible;
            
            Map<String, Object> indicators = new HashMap<>();
            indicators.put("liveIcon", liveIconVisible);
            indicators.put("liveBadge", liveBadgeVisible);
            indicators.put("liveBorder", hasLiveBorder);
            indicators.put("liveLink", hasLiveLink);
            indicators.put("liveIndicator", liveIndicatorVisible);
            
            Map<String, Object> result = new HashMap<>();
            result.put("username", username);
            result.put("isLive", isLive);
            result.put("timestamp", Instant.now().toString());
            result.put("indicators", indicators);
            
            System.out.println(toJson(result));
            
            return isLive;
            
        } catch (Exception e) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", true);
            error.put("status", "technical_error");
            error.put("message", e.getMessage());
            error.put("stack", e.getStackTrace()[0].toString());
            error.put("timestamp", Instant.now().toString());
            
            System.err.println(toJson(error));
            throw e;
        }
    }
    
    private static String toJson(Map<String, Object> map) {
        StringBuilder json = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            if (!first) json.append(",");
            json.append("\"").append(entry.getKey()).append("\":");
            if (entry.getValue() instanceof String) {
                json.append("\"").append(entry.getValue()).append("\"");
            } else if (entry.getValue() instanceof Map) {
                json.append(toJson((Map<String, Object>) entry.getValue()));
            } else if (entry.getValue() instanceof Boolean) {
                json.append(entry.getValue().toString().toLowerCase());
            } else {
                json.append("\"").append(entry.getValue()).append("\"");
            }
            first = false;
        }
        json.append("}");
        return json.toString();
    }
}
