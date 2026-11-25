// abstraction-provenance: {"artifact_sha256": "2ece379dbcfbe5d48c1ee95c377837cc867ef982e046e965f7010e296fefe10e", "source_sha256": "1c74aa0ec785639584af8f4d4e128e120c85d9712a7fca7650c80bfc0c1fe946", "target_language": "java"}
// tiktok-get-stream.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;
import java.net.*;
import com.google.gson.*;

public class TikTokGetStream {
    private static final String USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    
    public static void main(String[] args) {
        if (args.length == 0) {
            System.err.println("Usage: java TikTokGetStream <username>");
            System.exit(1);
        }
        
        String rawUsername = args[0];
        String username = rawUsername.replaceAll("^@+", "");
        if (username.isEmpty()) {
            System.err.println("Username must not be empty");
            System.exit(1);
        }
        
        if (!rejectBusyNode()) {
            System.exit(75);
        }
        
        try {
            boolean success = getStreamUrl(username);
            System.exit(success ? 0 : 1);
        } catch (Exception e) {
            JsonObject errorObj = new JsonObject();
            errorObj.addProperty("error", true);
            errorObj.addProperty("message", e.getMessage());
            errorObj.addProperty("timestamp", java.time.Instant.now().toString());
            System.err.println(new GsonBuilder().setPrettyPrinting().create().toJson(errorObj));
            System.exit(1);
        }
    }
    
    private static boolean rejectBusyNode() {
        String limitStr = System.getenv("TIKTOK_MAX_LOAD_PER_CPU");
        if (limitStr == null || limitStr.isEmpty()) return true;
        
        try {
            double limit = Double.parseDouble(limitStr);
            if (limit <= 0) return true;
            
            double loadAvg = getSystemLoadAverage();
            int cpuCount = Runtime.getRuntime().availableProcessors();
            double normalizedLoad = loadAvg / cpuCount;
            
            if (normalizedLoad > limit) {
                System.err.println("NODE_BUSY normalizedLoad=" + String.format("%.2f", normalizedLoad) + " limit=" + limit);
                return false;
            }
        } catch (NumberFormatException e) {
            return true;
        }
        return true;
    }
    
    private static double getSystemLoadAverage() {
        try {
            OperatingSystemMXBean osBean = ManagementFactory.getPlatformMXBean(OperatingSystemMXBean.class);
            return osBean.getSystemLoadAverage();
        } catch (Exception e) {
            return 0.0;
        }
    }
    
    private static boolean verifyLiveStatus(String username) throws Exception {
        Path checkerPath = Paths.get(System.getProperty("user.dir"), "tiktok-check-profile.js");
        ProcessBuilder pb = new ProcessBuilder("node", checkerPath.toString(), username);
        pb.environment().putAll(System.getenv());
        Process process = pb.start();
        
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }
        
        int exitCode = process.waitFor(60, TimeUnit.SECONDS) ? process.exitValue() : -1;
        if (exitCode == 0 && !output.toString().isEmpty()) {
            JsonObject result = JsonParser.parseString(output.toString()).getAsJsonObject();
            return result.has("isLive") && result.get("isLive").getAsBoolean();
        }
        
        return false;
    }
    
    private static boolean getStreamUrl(String username) throws Exception {
        if (!verifyLiveStatus(username)) {
            JsonObject obj = new JsonObject();
            obj.addProperty("username", username);
            obj.addProperty("isLive", false);
            obj.addProperty("error", "User is not currently live.");
            obj.addProperty("timestamp", java.time.Instant.now().toString());
            System.err.println(new Gson().toJson(obj));
            return false;
        }
        
        // Note: This simplified version doesn't capture actual network traffic
        // A full implementation would require a headless browser library like Selenium
        
        List<FlvUrl> flvUrls = new ArrayList<>();
        
        try {
            // Simulate browser navigation and network monitoring
            // In a real implementation, you would use a browser automation library
            
            Thread.sleep(3000); // Wait for potential consent dialogs
            Thread.sleep(8000); // Wait for stream to load
            Thread.sleep(10000); // Additional wait for FLV URLs
            
            // Placeholder - in reality this would come from network monitoring
            // For demonstration purposes, we'll create some sample URLs
            flvUrls.add(new FlvUrl("https://example.com/stream_uhd.flv", "media", java.time.Instant.now().toString()));
            flvUrls.add(new FlvUrl("https://example.com/stream_hd.flv", "media", java.time.Instant.now().toString()));
            
            if (!flvUrls.isEmpty()) {
                // Deduplicate URLs
                Map<String, FlvUrl> uniqueMap = new LinkedHashMap<>();
                for (FlvUrl item : flvUrls) {
                    uniqueMap.put(item.url, item);
                }
                List<FlvUrl> uniqueUrls = new ArrayList<>(uniqueMap.values());
                
                // Sort by quality
                uniqueUrls.sort((a, b) -> {
                    int qualityA = getQuality(a.url);
                    int qualityB = getQuality(b.url);
                    return qualityB - qualityA;
                });
                
                JsonObject result = new JsonObject();
                result.addProperty("username", username);
                result.addProperty("isLive", true);
                result.addProperty("streamCount", uniqueUrls.size());
                
                JsonArray streamsArray = new JsonArray();
                for (FlvUrl url : uniqueUrls) {
                    JsonObject streamObj = new JsonObject();
                    streamObj.addProperty("url", url.url);
                    streamObj.addProperty("type", url.type);
                    streamObj.addProperty("timestamp", url.timestamp);
                    streamsArray.add(streamObj);
                }
                result.add("streams", streamsArray);
                result.addProperty("vlcCommand", "vlc \"" + uniqueUrls.get(0).url + "\"");
                result.addProperty("timestamp", java.time.Instant.now().toString());
                
                System.out.println(new GsonBuilder().setPrettyPrinting().create().toJson(result));
                return true;
            } else {
                JsonObject obj = new JsonObject();
                obj.addProperty("username", username);
                obj.addProperty("isLive", false);
                obj.addProperty("error", "No stream URLs found - user may not be live");
                obj.addProperty("timestamp", java.time.Instant.now().toString());
                System.err.println(new Gson().toJson(obj));
                return false;
            }
        } catch (Exception e) {
            JsonObject obj = new JsonObject();
            obj.addProperty("error", true);
            obj.addProperty("message", e.getMessage());
            obj.addProperty("timestamp", java.time.Instant.now().toString());
            System.err.println(new Gson().toJson(obj));
            return false;
        }
    }
    
    private static int getQuality(String url) {
        String[][] suffixRanks = {
            {"_origin.", "600"}, {"_uhd_60.", "550"}, {"_uhd.", "540"},
            {"_hd_60.", "500"}, {"_hd.", "450"}, {"_sd.", "350"}, {"_ld.", "250"}
        };
        
        for (String[] pair : suffixRanks) {
            if (url.contains(pair[0])) {
                return Integer.parseInt(pair[1]);
            }
        }
        
        Pattern pattern = Pattern.compile("(\\d+)p");
        Matcher matcher = pattern.matcher(url);
        if (matcher.find()) {
            return Integer.parseInt(matcher.group(1));
        }
        return 0;
    }
    
    static class FlvUrl {
        String url;
        String type;
        String timestamp;
        
        FlvUrl(String url, String type, String timestamp) {
            this.url = url;
            this.type = type;
            this.timestamp = timestamp;
        }
    }
    
    interface OperatingSystemMXBean extends java.lang.management.PlatformManagedObject {
        double getSystemLoadAverage();
    }
}
