// abstraction-provenance: {"artifact_sha256": "5c1a6594cb30c0b672daf8a6f7c6febf1c10130b79466c259cafd593a38cef91", "source_sha256": "23879e22856f8bcfb0ddda7c9b1d7b0d7f3af474cea8620c1f7c10511ef03ed5", "target_language": "java"}
// tiktok-common.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.net.URL;
import java.util.regex.Pattern;
import java.util.Set;
import java.util.HashSet;
import java.util.List;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Map;
import java.util.HashMap;
import java.lang.management.ManagementFactory;
import com.sun.management.OperatingSystemMXBean;

/**
 * Shared TikTok LIVE safety contract: handle normalization, per-CPU load
 * preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
 * validation, and normalized extractor statuses.
 */
public class TikTokCommon {

    private static final double DEFAULT_MAX_LOAD_PER_CPU = 1.5;
    private static final Pattern USERNAME_PATTERN = Pattern.compile("^[A-Za-z0-9._]{1,24}$");
    private static final Set<String> FAILURE_STATUSES = new HashSet<>(Arrays.asList(
        "offline",
        "restricted",
        "overloaded",
        "dependency_missing",
        "technical_error"
    ));

    public static String normalizeUsername(Object raw) throws Exception {
        String username = (raw != null ? raw.toString() : "").trim().replaceAll("^@+", "");
        if (!USERNAME_PATTERN.matcher(username).matches()) {
            throw new Exception("Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores");
        }
        return username;
    }

    public static LoadState loadState(Map<String, String> env) {
        int cpuCount = Math.max(1, Runtime.getRuntime().availableProcessors());
        OperatingSystemMXBean osBean = ManagementFactory.getPlatformMXBean(OperatingSystemMXBean.class);
        
        double observed;
        if (env.containsKey("TIKTOK_TEST_LOAD_PER_CPU")) {
            observed = Double.parseDouble(env.get("TIKTOK_TEST_LOAD_PER_CPU"));
        } else {
            observed = osBean.getSystemLoadAverage() / cpuCount;
        }
        
        double maximum = env.containsKey("TIKTOK_MAX_LOAD_PER_CPU") 
            ? Double.parseDouble(env.get("TIKTOK_MAX_LOAD_PER_CPU"))
            : DEFAULT_MAX_LOAD_PER_CPU;
            
        if (!Double.isFinite(observed) || !Double.isFinite(maximum) || maximum <= 0) {
            throw new RuntimeException("Invalid TikTok load configuration");
        }
        
        boolean overloaded = observed > maximum;
        return new LoadState(overloaded, observed, maximum);
    }

    public static LoadState loadState() {
        return loadState(System.getenv());
    }

    public static void enforceLoadLimit(String method) {
        LoadState state = loadState();
        if (!state.overloaded) return;
        
        System.err.println(String.format(
            "{\"status\":\"overloaded\",\"method\":\"%s\",\"loadPerCpu\":%.3f,\"maximum\":%.1f,\"message\":\"Host is overloaded; retry on another node or later\"}",
            method,
            state.loadPerCpu,
            state.maximum
        ));
        System.exit(75);
    }

    public static List<String> liveHrefSelectors(String username) {
        String href = "/@" + username + "/live";
        return Arrays.asList("a[href=\"" + href + "\"]", "a[href^=\"" + href + "?\"]");
    }

    public static boolean isAllowedStreamUrl(String value) {
        try {
            URL url = new URL(value);
            String hostname = url.getHost().toLowerCase();
            return "https".equals(url.getProtocol()) &&
                url.getPath().toLowerCase().contains(".flv") &&
                Pattern.matches("(^|\\.)tiktokcdn(-[a-z0-9-]+)?\\.com$", hostname);
        } catch (Exception error) {
            return false;
        }
    }

    public static boolean isSuccessfulStreamResponse(int status, String value) {
        return status >= 200 &&
            status < 300 &&
            isAllowedStreamUrl(value);
    }

    // Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
    private static final Pattern QUALITY_URL_PATTERN = Pattern.compile("_(uhd_60|hd_60|origin|hd|sd|ld|ao)\\.(?:flv|m3u8)");

    public static String qualityKeyFromUrl(String value) {
        try {
            URL url = new URL(value);
            String path = url.getPath().toLowerCase();
            java.util.regex.Matcher matcher = QUALITY_URL_PATTERN.matcher(path);
            if (matcher.find()) {
                return matcher.group(1);
            }
            return null;
        } catch (Exception error) {
            return null;
        }
    }

    public static Map<String, Object> normalizeExtractorResult(Object input, String method, String username) {
        Map<String, Object> technicalError = new HashMap<>();
        technicalError.put("success", false);
        technicalError.put("status", "technical_error");
        technicalError.put("method", method);
        technicalError.put("username", username);
        technicalError.put("message", "invalid extractor result");

        if (input == null || !(input instanceof Map)) {
            return technicalError;
        }

        @SuppressWarnings("unchecked")
        Map<String, Object> value = (Map<String, Object>) input;

        if (Boolean.TRUE.equals(value.get("success"))) {
            if (!"live".equals(value.get("status")) || !isAllowedStreamUrl((String) value.get("url"))) {
                return technicalError;
            }
            Map<String, Object> result = new HashMap<>(value);
            result.put("success", true);
            result.put("status", "live");
            return result;
        }

        if (!Boolean.FALSE.equals(value.get("success"))) {
            return technicalError;
        }

        Map<String, Object> result = new HashMap<>(value);
        result.put("success", false);
        result.put("status", FAILURE_STATUSES.contains(value.get("status")) 
            ? value.get("status") 
            : "technical_error");
        result.put("method", value.get("method") instanceof String 
            ? value.get("method") 
            : method);
        result.put("username", value.get("username") instanceof String 
            ? value.get("username") 
            : username);
            
        result.remove("url");
        result.remove("streams");
        result.remove("allUrls");
        
        return result;
    }

    public static String classifyFinalFailure(List<Map<String, Object>> results) {
        Set<String> statuses = new HashSet<>();
        for (Map<String, Object> result : results) {
            if (result != null && result.containsKey("status")) {
                String status = (String) result.get("status");
                if (FAILURE_STATUSES.contains(status)) {
                    statuses.add(status);
                }
            }
        }
        
        if (statuses.contains("overloaded")) return "overloaded";
        if (statuses.contains("restricted")) return "restricted";
        if (statuses.contains("technical_error")) return "technical_error";
        if (statuses.contains("offline")) return "offline";
        if (statuses.contains("dependency_missing")) return "dependency_missing";
        return "technical_error";
    }

    public static int exitCodeForResult(Map<String, Object> result) {
        if (result != null && Boolean.TRUE.equals(result.get("success")) && "live".equals(result.get("status"))) 
            return 0;
        if (result != null && "overloaded".equals(result.get("status"))) 
            return 75;
        if (result != null && ("offline".equals(result.get("status")) || "restricted".equals(result.get("status")))) 
            return 1;
        return 2;
    }

    public static Map<String, Object> classifyDirectLiveState(Map<String, Object> params) {
        String username = (String) params.get("username");
        String currentPath = (String) params.get("currentPath");
        String title = (String) params.get("title");
        String bodyText = (String) params.get("bodyText");
        Boolean successfulStreamResponse = (Boolean) params.get("successfulStreamResponse");

        String expectedPath = "/@" + username + "/live";
        if (!expectedPath.equals(currentPath)) {
            Map<String, Object> offline = new HashMap<>();
            offline.put("status", "offline");
            offline.put("reason", "target live page redirected");
            return offline;
        }
        
        if (Boolean.TRUE.equals(successfulStreamResponse)) {
            Map<String, Object> live = new HashMap<>();
            live.put("status", "live");
            live.put("reason", "successful TikTok CDN stream response");
            return live;
        }

        String normalizedBody = (bodyText != null ? bodyText : "").replaceAll("\\s+", " ").toLowerCase();
        String normalizedTitle = (title != null ? title : "").toLowerCase();
        boolean accountLiveTitle = normalizedTitle.contains("(@" + username.toLowerCase() + ") is live");

        List<String> endedMarkers = Arrays.asList(
            "live has ended",
            "das live ist beendet",
            "live wurde beendet",
            "dieses live ist beendet",
            "stream has ended"
        );
        
        for (String marker : endedMarkers) {
            if (normalizedBody.contains(marker)) {
                Map<String, Object> offline = new HashMap<>();
                offline.put("status", "offline");
                offline.put("reason", "target live page reports ended stream");
                return offline;
            }
        }

        List<String> restrictionMarkers = Arrays.asList(
            "dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten",
            "melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen",
            "bei tiktok anmelden",
            "melde dich an für das volle live-erlebnis",
            "melde dich an für das vollständige erlebnis",
            "this live may contain content that could be uncomfortable",
            "log in to tiktok",
            "log in for the full live experience",
            "mature content",
            "age-restricted",
            "viewer discretion"
        );
        
        if (accountLiveTitle) {
            for (String marker : restrictionMarkers) {
                if (normalizedBody.contains(marker)) {
                    Map<String, Object> restricted = new HashMap<>();
                    restricted.put("status", "restricted");
                    restricted.put("reason", "target live page requires authentication");
                    return restricted;
                }
            }
            
            Map<String, Object> restricted = new HashMap<>();
            restricted.put("status", "restricted");
            restricted.put("reason", "target is live but no accessible media response was available");
            return restricted;
        }
        
        Map<String, Object> offline = new HashMap<>();
        offline.put("status", "offline");
        offline.put("reason", "no account-specific live signal");
        return offline;
    }

    public static boolean forcedOffline(String method, String username) {
        if (!"1".equals(System.getenv("TIKTOK_TEST_OFFLINE"))) return false;
        
        System.err.println(String.format(
            "{\"success\":false,\"status\":\"offline\",\"method\":\"%s\",\"username\":\"%s\",\"message\":\"forced offline test mode\"}",
            method,
            username
        ));
        return true;
    }

    public static class LoadState {
        public final boolean overloaded;
        public final double loadPerCpu;
        public final double maximum;

        public LoadState(boolean overloaded, double loadPerCpu, double maximum) {
            this.overloaded = overloaded;
            this.loadPerCpu = loadPerCpu;
            this.maximum = maximum;
        }
    }
}
