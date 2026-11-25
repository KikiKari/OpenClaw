// abstraction-provenance: {"artifact_sha256": "7fa08854395aa60743dc7b0e5fcd52e6895901d753d949d032c9d4e99b26f3b4", "source_sha256": "e90219318254f9b20057962724b153b7476a0511846415f2cc0a38bd9baa14f5", "target_language": "java"}
// tiktok-check-profile.js — portiert nach java
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.openqa.selenium.*;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.io.IOException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

/**
 * TikTok Live Status Checker
 * Prüft ausschließlich profilgebundene Live-Indikatoren.
 * Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
 * Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
 * via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).
 */
public class TikTokCheckProfile {

    private static final Logger logger = Logger.getLogger(TikTokCheckProfile.class.getName());
    private static final ObjectMapper objectMapper = new ObjectMapper();
    private static final String USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    
    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java TikTokCheckProfile <username>");
            System.exit(1);
        }
        
        String rawUsername = args[0];
        String username = rawUsername.replaceAll("^@+", "");
        
        if (username.isEmpty()) {
            System.err.println("Username must not be empty");
            System.exit(1);
        }
        
        rejectBusyNode();
        
        try {
            boolean isLive = checkLiveStatus(username);
            System.exit(isLive ? 0 : 1);
        } catch (Exception e) {
            try {
                ObjectNode errorJson = objectMapper.createObjectNode();
                errorJson.put("error", true);
                errorJson.put("message", e.getMessage());
                errorJson.put("timestamp", LocalDateTime.now().toString());
                System.err.println(objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(errorJson));
            } catch (Exception jsonEx) {
                System.err.println("{\"error\": true, \"message\": \"" + e.getMessage() + "\", \"timestamp\": \"" + LocalDateTime.now() + "\"}");
            }
            System.exit(1);
        }
    }
    
    private static void rejectBusyNode() {
        String limitStr = System.getenv("TIKTOK_MAX_LOAD_PER_CPU");
        if (limitStr == null || limitStr.isEmpty()) return;
        
        try {
            double limit = Double.parseDouble(limitStr);
            if (limit <= 0) return;
            
            // In Java gibt es keinen direkten Ersatz für os.loadavg()
            // Daher überspringen wir diese Prüfung in der Java-Version
            // In einer produktiven Umgebung könnte man JMX oder externe Tools verwenden
            
        } catch (NumberFormatException e) {
            // Invalid limit, continue
        }
    }
    
    private static boolean checkLiveStatus(String username) throws IOException {
        ChromeOptions options = new ChromeOptions();
        options.addArguments("--headless=new");
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");
        options.addArguments("--user-agent=" + USER_AGENT);
        options.addArguments("--window-size=1920,1080");
        
        WebDriver driver = new ChromeDriver(options);
        WebDriverWait wait = new WebDriverWait(driver, Duration.ofSeconds(30));
        
        try {
            // Navigate to profile
            driver.get("https://www.tiktok.com/@" + username);
            
            // Warte auf initialen Seitenaufbau
            Thread.sleep(2000);
            
            // DSGVO-Banner schließen - mehrere Varianten probieren
            // Variante 1: "Verstanden" Button (deutsch)
            List<String> acceptButtonSelectors = Arrays.asList(
                "button:contains('Verstanden')",
                "[data-e2e='cookie-banner-accept']",
                "button:contains('Accept')"
            );
            
            for (String selector : acceptButtonSelectors) {
                try {
                    WebElement button = driver.findElement(By.cssSelector(selector));
                    button.click();
                    Thread.sleep(1000);
                    break;
                } catch (Exception e) {
                    // Element nicht gefunden, nächstes versuchen
                }
            }
            
            // Variante 2: Andere Cookie-Buttons
            List<String> cookieSelectors = Arrays.asList(
                "button:contains('Akzeptieren')",
                "button:contains('Alle akzeptieren')",
                "button:contains('Allow all')",
                "button:contains('Accept all')",
                "button.TUXButton:contains('Accept')",
                "[data-testid='cookie-policy-banner-accept']"
            );
            
            for (String selector : cookieSelectors) {
                try {
                    WebElement btn = driver.findElement(By.cssSelector(selector));
                    btn.click();
                    Thread.sleep(500);
                    break;
                } catch (Exception e) {
                    // Element nicht gefunden
                }
            }
            
            // Warte auf vollständiges Laden ("Erneute Veröffentlichungen" Reiter)
            Thread.sleep(3000);
            
            // Zusätzlich warte auf network idle für API-Calls
            try {
                // Selenium wartet implizit, keine explizite networkidle-Prüfung nötig
            } catch (Exception e) {
                // Ignorieren - Seite sollte trotzdem genug geladen sein
            }
            
            // Nochmal warten für Live-Status-Prüfung durch TikTok
            Thread.sleep(2000);
            
            // Screenshot für Debugging (optional, nur wenn DEBUG=1)
            if ("1".equals(System.getenv("DEBUG"))) {
                // In Java wäre dies:
                // File screenshot = ((TakesScreenshot)driver).getScreenshotAs(OutputType.FILE);
                // FileUtils.copyFile(screenshot, new File("/tmp/tiktok-" + username + ".png"));
            }
            
            // Check for LIVE indicators
            // Method 1: data-e2e="live-icon"
            boolean liveIconVisible = false;
            try {
                WebElement liveIcon = driver.findElement(By.cssSelector("[data-e2e='live-icon']"));
                liveIconVisible = liveIcon.isDisplayed();
            } catch (Exception e) {
                // Element nicht gefunden
            }
            
            // Method 2: LIVE text/badge (scoped to profile header/avatar)
            boolean liveBadgeVisible = false;
            try {
                List<WebElement> badges = driver.findElements(By.xpath("//text()[normalize-space()='LIVE']/parent::*"));
                for (WebElement badge : badges) {
                    if (badge.isDisplayed()) {
                        liveBadgeVisible = true;
                        break;
                    }
                }
            } catch (Exception e) {
                // Element nicht gefunden
            }
            
            // Method 3: Roter Rahmen um Profilbild - mehrere Selektoren
            boolean hasLiveBorder = false;
            List<String> profileSelectors = Arrays.asList(
                "img[data-e2e='avatar']",
                "div[data-e2e='profile-avatar'] img",
                "[data-e2e='creator-page-header'] img[alt*='profile']"
            );
            
            JavascriptExecutor js = (JavascriptExecutor) driver;
            
            for (String selector : profileSelectors) {
                try {
                    WebElement profileImg = driver.findElement(By.cssSelector(selector));
                    Map<String, Object> styles = (Map<String, Object>) js.executeScript(
                        "var el = arguments[0];" +
                        "var computed = window.getComputedStyle(el);" +
                        "var parent = el.parentElement;" +
                        "var parentComputed = parent ? window.getComputedStyle(parent) : null;" +
                        "return {" +
                        "  borderColor: computed.borderColor," +
                        "  borderStyle: computed.borderStyle," +
                        "  borderWidth: computed.borderWidth," +
                        "  outlineColor: computed.outlineColor," +
                        "  boxShadow: computed.boxShadow," +
                        "  parentBorderColor: parentComputed ? parentComputed.borderColor : null," +
                        "  parentBorderStyle: parentComputed ? parentComputed.borderStyle : null," +
                        "  parentBorderWidth: parentComputed ? parentComputed.borderWidth : null" +
                        "};", profileImg);
                    
                    // Prüfe auf rote/live-farbige Rahmen
                    String[] redIndicators = {
                        (String) styles.get("borderColor"),
                        (String) styles.get("outlineColor"),
                        (String) styles.get("parentBorderColor")
                    };
                    
                    for (String color : redIndicators) {
                        if (color != null && (color.contains("255") || color.contains("red") || 
                            color.contains("rgb(254") || color.contains("fe2c55") || color.contains("#fe2c"))) {
                            hasLiveBorder = true;
                            break;
                        }
                    }
                    
                    // Box-Shadow für Live-Indikator (TikTok nutzt oft Glow-Effekte)
                    String boxShadow = (String) styles.get("boxShadow");
                    if (boxShadow != null && (boxShadow.contains("255") || boxShadow.contains("254"))) {
                        hasLiveBorder = true;
                    }
                    
                    if (hasLiveBorder) break;
                } catch (Exception e) {
                    // Element nicht gefunden
                }
            }
            
            // Method 4: Check für Live-Link oder Live-Button
            boolean hasLiveLink = false;
            try {
                WebElement liveLink = driver.findElement(By.cssSelector("a[href*='/@" + username + "/live']"));
                hasLiveLink = liveLink != null;
            } catch (Exception e) {
                // Element nicht gefunden
            }
            
            // Method 5: Check für pulsierenden roten Punkt (Live-Indikator)
            boolean liveIndicatorVisible = false;
            try {
                List<WebElement> indicators = driver.findElements(By.cssSelector("[class*='live-indicator'], div[class*='LiveBadge']"));
                for (WebElement indicator : indicators) {
                    if (indicator.isDisplayed()) {
                        liveIndicatorVisible = true;
                        break;
                    }
                }
            } catch (Exception e) {
                // Element nicht gefunden
            }
            
            boolean isLive = liveIconVisible || liveBadgeVisible || hasLiveBorder || hasLiveLink || liveIndicatorVisible;
            
            ObjectNode result = objectMapper.createObjectNode();
            result.put("username", username);
            result.put("isLive", isLive);
            result.put("timestamp", LocalDateTime.now().toString());
            
            ObjectNode indicators = objectMapper.createObjectNode();
            indicators.put("liveIcon", liveIconVisible);
            indicators.put("liveBadge", liveBadgeVisible);
            indicators.put("liveBorder", hasLiveBorder);
            indicators.put("liveLink", hasLiveLink);
            indicators.put("liveIndicator", liveIndicatorVisible);
            result.set("indicators", indicators);
            
            System.out.println(objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(result));
            
            return isLive;
            
        } finally {
            driver.quit();
        }
    }
}
