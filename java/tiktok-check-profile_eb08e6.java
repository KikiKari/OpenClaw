// abstraction-provenance: {"artifact_sha256": "334cf6e6176d9aa9bf2b05fade93c98672fcec11939d179264ed192992dd7399", "source_sha256": "eb08e6ac444b7c9611c2c56d0b5b99c5f3d6c627dce5fb23dd375d732ee39a65", "target_language": "java"}
// tiktok-check-profile.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;
import org.openqa.selenium.*;
import org.openqa.selenium.chrome.*;
import org.openqa.selenium.support.ui.*;
import com.google.gson.*;

public class TikTokCheckProfile {
    
    private static final String[] COOKIE_SELECTORS = {
        "button:contains('Verstanden')",
        "[data-e2e='cookie-banner-accept']",
        "button:contains('Accept')",
        "button:contains('Akzeptieren')",
        "button:contains('Alle akzeptieren')",
        "button:contains('Allow all')",
        "button:contains('Accept all')",
        "button.TUXButton:contains('Accept')",
        "[data-testid='cookie-policy-banner-accept']"
    };
    
    private static final String[] LIVE_HREF_SELECTORS(String username) {
        return new String[]{
            String.format("a[href='/@%s/live']", username),
            String.format("a[href='https://www.tiktok.com/@%s/live']", username)
        };
    }
    
    private static void enforceLoadLimit(String method) {
        // Placeholder for load limit enforcement
    }
    
    private static boolean isSuccessfulStreamResponse(int statusCode, String url) {
        return statusCode == 200 && url.contains(".flv");
    }
    
    private static String normalizeUsername(String username) throws IllegalArgumentException {
        if (username == null || username.trim().isEmpty()) {
            throw new IllegalArgumentException("Username cannot be empty");
        }
        String normalized = username.trim().toLowerCase();
        if (!normalized.matches("[a-zA-Z0-9._-]+")) {
            throw new IllegalArgumentException("Invalid username format");
        }
        return normalized;
    }
    
    private static int humanDelay(int min, int max) {
        Random random = new Random();
        return random.nextInt(max - min + 1) + min;
    }
    
    private static boolean closeDSGVOBanner(WebDriver driver) {
        for (String selector : COOKIE_SELECTORS) {
            try {
                WebElement btn = driver.findElement(By.cssSelector(selector));
                if (btn != null) {
                    btn.click();
                    try {
                        Thread.sleep(humanDelay(1000, 2000));
                    } catch (InterruptedException e) {}
                    return true;
                }
            } catch (Exception e) {
                // Continue trying
            }
        }
        return false;
    }
    
    private static boolean waitForPageReady(WebDriver driver) {
        try {
            Thread.sleep(humanDelay(2000, 3000));
        } catch (InterruptedException e) {}
        
        boolean pageReady = false;
        WebDriverWait wait = new WebDriverWait(driver, 25);
        
        try {
            wait.until(ExpectedConditions.visibilityOfElementLocated(
                By.xpath("//*[text()='Erneute Veröffentlichungen']")));
            pageReady = true;
        } catch (Exception e1) {
            try {
                wait.until(ExpectedConditions.visibilityOfElementLocated(
                    By.xpath("//*[text()='Reposts']")));
                pageReady = true;
            } catch (Exception e2) {
                try {
                    wait.until(ExpectedConditions.jsReturnsValue("return document.readyState === 'complete'"));
                } catch (Exception e3) {
                    // Continue
                }
            }
        }
        
        try {
            Thread.sleep(humanDelay(2000, 3000));
        } catch (InterruptedException e) {}
        
        return pageReady;
    }
    
    private static class LiveDetectionResult {
        boolean isLive;
        String detectionMethod;
        Map<String, Boolean> indicators;
        
        LiveDetectionResult(boolean isLive, String detectionMethod, Map<String, Boolean> indicators) {
            this.isLive = isLive;
            this.detectionMethod = detectionMethod;
            this.indicators = indicators;
        }
    }
    
    private static LiveDetectionResult detectLiveStatus(WebDriver driver, String username) {
        Map<String, Boolean> indicators = new HashMap<>();
        indicators.put("liveIcon", false);
        indicators.put("liveBadge", false);
        indicators.put("liveBorder", false);
        indicators.put("liveLink", false);
        indicators.put("liveIndicator", false);
        String detectionMethod = "none";
        
        // Priority 1: LIVE-Icon within exact account LIVE link
        try {
            String[] selectors = LIVE_HREF_SELECTORS(username);
            WebElement liveLink = null;
            for (String selector : selectors) {
                try {
                    liveLink = driver.findElement(By.cssSelector(selector));
                    break;
                } catch (Exception e) {}
            }
            
            if (liveLink != null) {
                try {
                    WebElement icon = liveLink.findElement(By.cssSelector(
                        "[data-e2e='live-icon'], [class*='LiveBadge'], [class*='live-indicator']"));
                    if (icon.isDisplayed()) {
                        indicators.put("liveIcon", true);
                        return new LiveDetectionResult(true, "live-icon", indicators);
                    }
                } catch (Exception e) {}
            }
        } catch (Exception e) {}
        
        // Priority 2: Exact LIVE badge within same account link
        try {
            String[] selectors = LIVE_HREF_SELECTORS(username);
            WebElement liveLink = null;
            for (String selector : selectors) {
                try {
                    liveLink = driver.findElement(By.cssSelector(selector));
                    break;
                } catch (Exception e) {}
            }
            
            if (liveLink != null) {
                List<WebElement> badges = liveLink.findElements(By.xpath(".//*[text()[normalize-space()='LIVE']]"));
                if (!badges.isEmpty() && badges.get(0).isDisplayed()) {
                    indicators.put("liveBadge", true);
                    return new LiveDetectionResult(true, "live-badge", indicators);
                }
            }
        } catch (Exception e) {}
        
        // Priority 3: Live border at profile header/avatar
        try {
            String[] profileSelectors = {
                "[data-e2e='user-page'] img[data-e2e='avatar']",
                "[data-e2e='user-page'] div[data-e2e='profile-avatar'] img",
                "main header img[data-e2e='avatar']",
                "main header [class*='avatar'] img"
            };
            
            for (String selector : profileSelectors) {
                try {
                    WebElement profileImg = driver.findElement(By.cssSelector(selector));
                    // Check for red border/color would require JavaScript execution
                    // This is simplified due to complexity of CSS property checking
                    indicators.put("liveBorder", false); // Placeholder
                    break;
                } catch (Exception e) {}
            }
        } catch (Exception e) {}
        
        // Priority 4: Live indicator within exact account link
        try {
            String[] selectors = LIVE_HREF_SELECTORS(username);
            WebElement liveLink = null;
            for (String selector : selectors) {
                try {
                    liveLink = driver.findElement(By.cssSelector(selector));
                    break;
                } catch (Exception e) {}
            }
            
            if (liveLink != null) {
                try {
                    WebElement indicator = liveLink.findElement(By.cssSelector(
                        "[class*='live-indicator'], div[class*='LiveBadge']"));
                    if (indicator.isDisplayed()) {
                        indicators.put("liveIndicator", true);
                        return new LiveDetectionResult(true, "live-indicator", indicators);
                    }
                } catch (Exception e) {}
            }
        } catch (Exception e) {}
        
        // Priority 5: Visible exact /@username/live link
        try {
            String[] selectors = LIVE_HREF_SELECTORS(username);
            WebElement liveLink = null;
            for (String selector : selectors) {
                try {
                    liveLink = driver.findElement(By.cssSelector(selector));
                    if (liveLink.isDisplayed()) {
                        indicators.put("liveLink", true);
                        return new LiveDetectionResult(true, "live-link", indicators);
                    }
                    break;
                } catch (Exception e) {}
            }
        } catch (Exception e) {}
        
        return new LiveDetectionResult(false, detectionMethod, indicators);
    }
    
    private static class DirectLiveState {
        String status;
        String reason;
        
        DirectLiveState(String status, String reason) {
            this.status = status;
            this.reason = reason;
        }
    }
    
    private static DirectLiveState classifyDirectLiveState(Map<String, Object> data) {
        String currentPath = (String) data.get("currentPath");
        String title = (String) data.get("title");
        String bodyText = (String) data.get("bodyText");
        boolean successfulStreamResponse = (Boolean) data.get("successfulStreamResponse");
        
        if (currentPath.contains("/login")) {
            return new DirectLiveState("restricted", "login_required");
        }
        
        if (title.contains("Access Denied") || bodyText.contains("Access Denied")) {
            return new DirectLiveState("restricted", "access_denied");
        }
        
        if (title.contains("Not Found") || bodyText.contains("Not Found")) {
            return new DirectLiveState("offline", "not_found");
        }
        
        if (successfulStreamResponse) {
            return new DirectLiveState("live", "stream_available");
        }
        
        return new DirectLiveState("offline", "no_stream");
    }
    
    private static DirectLiveState inspectDirectLiveState(WebDriver driver, String username) {
        final boolean[] successfulStreamResponse = {false};
        
        EventFiringWebDriver eventDriver = new EventFiringWebDriver(driver);
        eventDriver.register(new AbstractWebDriverEventListener() {
            @Override
            public void onResponseReceived(WebDriver driver, Response response) {
                if (isSuccessfulStreamResponse(response.getStatus(), response.getUrl())) {
                    successfulStreamResponse[0] = true;
                }
            }
        });
        
        try {
            eventDriver.get("https://www.tiktok.com/@" + username + "/live");
            try {
                Thread.sleep(humanDelay(8000, 10000));
            } catch (InterruptedException e) {}
            
            String currentUrl = eventDriver.getCurrentUrl();
            String bodyText = "";
            try {
                bodyText = eventDriver.findElement(By.tagName("body")).getText();
            } catch (Exception e) {}
            
            Map<String, Object> data = new HashMap<>();
            data.put("username", username);
            data.put("currentPath", new URI(currentUrl).getPath());
            data.put("title", eventDriver.getTitle());
            data.put("bodyText", bodyText);
            data.put("successfulStreamResponse", successfulStreamResponse[0]);
            
            return classifyDirectLiveState(data);
        } catch (Exception error) {
            return new DirectLiveState("technical_error", error.getMessage());
        }
    }
    
    private static String checkLiveStatus(String username) {
        System.setProperty("webdriver.chrome.driver", "/path/to/chromedriver"); // Adjust path
        
        ChromeOptions options = new ChromeOptions();
        options.addArguments("--headless");
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");
        options.addArguments("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
        options.setExperimentalOption("useAutomationExtension", false);
        options.setExperimentalOption("excludeSwitches", Collections.singletonList("enable-automation"));
        
        WebDriver driver = null;
        try {
            driver = new ChromeDriver(options);
            driver.manage().window().setSize(new Dimension(1920, 1080));
            
            // Navigate to profile
            driver.get("https://www.tiktok.com/@" + username);
            
            // Step 1: Close cookie banner
            boolean bannerClosed = closeDSGVOBanner(driver);
            
            // Step 2: Wait for page ready
            boolean pageReady = waitForPageReady(driver);
            
            // Step 3: Detect live status
            LiveDetectionResult liveResult = detectLiveStatus(driver, username);
            
            // Step 4: Inspect direct live state
            DirectLiveState directResult = inspectDirectLiveState(driver, username);
            
            String finalStatus = "offline";
            if ("restricted".equals(directResult.status)) {
                finalStatus = "restricted";
            } else if (liveResult.isLive || "live".equals(directResult.status)) {
                finalStatus = "live";
            } else {
                finalStatus = directResult.status;
            }
            
            // Build result JSON
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("username", username);
            result.put("status", finalStatus);
            result.put("isLive", "live".equals(finalStatus) || "restricted".equals(finalStatus));
            result.put("detectionMethod", "restricted".equals(directResult.status) 
                ? "account-live-restricted" 
                : liveResult.detectionMethod);
            result.put("isAgeRestricted", "restricted".equals(finalStatus));
            result.put("ageRestrictionReason", "restricted".equals(finalStatus) ? directResult.reason : null);
            result.put("indicators", liveResult.indicators);
            result.put("bannerClosed", bannerClosed);
            result.put("pageFullyLoaded", pageReady);
            result.put("timestamp", new Date().toString());
            result.put("version", "2.1");
            
            Gson gson = new GsonBuilder().setPrettyPrinting().create();
            System.out.println(gson.toJson(result));
            
            return finalStatus;
            
        } catch (Exception error) {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("username", username);
            result.put("isLive", false);
            result.put("status", "technical_error");
            result.put("detectionMethod", "error");
            result.put("isAgeRestricted", false);
            result.put("ageRestrictionReason", null);
            result.put("indicators", new HashMap<>());
            result.put("error", error.getMessage());
            result.put("timestamp", new Date().toString());
            result.put("version", 2);
            
            Gson gson = new GsonBuilder().setPrettyPrinting().create();
            System.err.println(gson.toJson(result));
            return "technical_error";
        } finally {
            if (driver != null) {
                try {
                    driver.quit();
                } catch (Exception e) {}
            }
        }
    }
    
    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java TikTokCheckProfile <username>");
            System.exit(64);
        }
        
        String username;
        try {
            username = normalizeUsername(args[0]);
        } catch (IllegalArgumentException error) {
            System.err.println("Usage: java TikTokCheckProfile <username>");
            System.err.println(error.getMessage());
            System.exit(64);
            return;
        }
        
        enforceLoadLimit("playwright_enhanced");
        
        String status = checkLiveStatus(username);
        switch (status) {
            case "live":
                System.exit(0);
                break;
            case "offline":
            case "restricted":
                System.exit(1);
                break;
            default:
                System.exit(2);
                break;
        }
    }
}
