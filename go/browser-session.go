// abstraction-provenance: {"artifact_sha256": "676f2025cdea63074635c4845eafd8e9afe873300d767516e4193505e3f56361", "source_sha256": "acf29634657ddc4b0dd7488e70f24c496bf7bd82883eecf4ebbed3a1486457cd", "target_language": "go"}
// browser-session.mjs — portiert nach go
// Quelle: javascript, Onboarding@main:scripts/browser-session.mjs
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/**
 * Persistente Browser-Sitzung der Sandbox.
 *
 * Zweck: Plattformen ohne (nutzbare) API — WaveSpeed-Konsole, Perplexity,
 * Canva, Stock-Portale — erfordern einen echten Web-Login. Diese Sitzung
 * speichert Cookies/LocalStorage DAUERHAFT in einem user-data-dir, akzeptiert
 * Cookie-Banner automatisch und bleibt über Skript-Läufe hinweg angemeldet.
 *
 * Profil-Verzeichnis: <repo>/.browser-profile (gitignored — enthält Secrets).
 *
 * Nutzung (immer unter Xvfb, damit echtes Chrome mit Codecs läuft):
 *   xvfb-run -a node scripts/browser-session.mjs open <URL>          # öffnen, Cookies akzeptieren, Screenshot
 *   xvfb-run -a node scripts/browser-session.mjs login <URL> [--user-field ..] [--pass-field ..] [--env-user X] [--env-pass Y]
 *   xvfb-run -a node scripts/browser-session.mjs shot <URL> [--out file.png] [--wait ms] [--full]
 *   xvfb-run -a node scripts/browser-session.mjs state                 # gespeicherte Cookies auflisten (Domains)
 *
 * Die Sitzung wird NICHT geschlossen-und-verworfen: das Profil bleibt auf Platte.
 */
package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/playwright-community/playwright-go"
)

var (
	REPO    string
	PROFILE string
	CHROME  string
)

func init() {
	ex, err := os.Executable()
	if err != nil {
		panic(err)
	}
	REPO = filepath.Dir(filepath.Dir(ex))
	PROFILE = os.Getenv("BROWSER_PROFILE_DIR")
	if PROFILE == "" {
		PROFILE = filepath.Join(REPO, ".browser-profile")
	}
	chromePaths := []string{"/usr/bin/google-chrome-stable", "/usr/bin/google-chrome"}
	for _, p := range chromePaths {
		if _, err := os.Stat(p); err == nil {
			CHROME = p
			break
		}
	}
}

// .env laden (nur für login-Credentials; nichts wird geloggt)
func loadEnv() map[string]string {
	envFile := filepath.Join(REPO, ".env")
	if _, err := os.Stat(envFile); os.IsNotExist(err) {
		return make(map[string]string)
	}
	file, err := os.Open(envFile)
	if err != nil {
		return make(map[string]string)
	}
	defer file.Close()

	out := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		matches := regexp.MustCompile(`^\s*([A-Z0-9_]+)\s*=\s*"?([^"]*)"?\s*$`).FindStringSubmatch(line)
		if len(matches) > 2 {
			out[matches[1]] = matches[2]
		}
	}
	return out
}

/** Häufige Cookie-Consent-Buttons klicken (mehrsprachig, best effort). */
func acceptCookies(page playwright.Page) (string, error) {
	labels := []string{
		"Accept all", "Accept All", "Alle akzeptieren", "Accept all cookies",
		"Alle Cookies akzeptieren", "I agree", "Ich stimme zu", "Zustimmen",
		"Allow all", "Akzeptieren", "Accept", "Got it", "Agree",
	}
	for _, name := range labels {
		btn := page.GetByRole("button", playwright.PageGetByRoleOptions{Name: name, Exact: playwright.Bool(false)}).First()
		if isVisible, _ := btn.IsVisible(playwright.PageIsVisibleOptions{Timeout: playwright.Float(800)}); isVisible {
			if err := btn.Click(playwright.ElementHandleClickOptions{Timeout: playwright.Float(1500)}); err == nil {
				return name, nil
			}
		}
	}
	// Generische Consent-IDs
	selectors := []string{"#onetrust-accept-btn-handler", "[aria-label*='accept' i]", "button[title*='accept' i]"}
	for _, sel := range selectors {
		el := page.Locator(sel).First()
		if isVisible, _ := el.IsVisible(playwright.LocatorIsVisibleOptions{Timeout: playwright.Float(500)}); isVisible {
			if err := el.Click(playwright.ElementHandleClickOptions{Timeout: playwright.Float(1500)}); err == nil {
				return sel, nil
			}
		}
	}
	return "", nil
}

func main() {
	args := os.Args[1:]
	if len(args) < 1 {
		fmt.Println("Befehle: open <URL> | shot <URL> | login <URL> | state")
		return
	}

	cmd := args[0]
	var target string
	var rest []string
	if len(args) > 1 {
		target = args[1]
		rest = args[2:]
	}

	flag := func(n, d string) string {
		for i, arg := range rest {
			if arg == "--"+n && i+1 < len(rest) {
				return rest[i+1]
			}
		}
		return d
	}
	has := func(n string) bool {
		for _, arg := range rest {
			if arg == "--"+n {
				return true
			}
		}
		return false
	}

	os.MkdirAll(PROFILE, 0755)

	SOCKS := flag("socks", "")
	var PROXY string
	if SOCKS != "" {
		PROXY = "socks5://" + SOCKS
	} else {
		proxyEnv := os.Getenv("HTTPS_PROXY")
		if proxyEnv == "" {
			proxyEnv = os.Getenv("https_proxy")
		}
		PROXY = proxyEnv
	}

	pw, err := playwright.Run()
	if err != nil {
		panic(err)
	}
	defer pw.Stop()

	browserType := pw.Chromium
	context, err := browserType.LaunchPersistentContext(
		PROFILE,
		playwright.BrowserTypeLaunchPersistentContextOptions{
			Headless:          playwright.Bool(false),
			ExecutablePath:    &CHROME,
			Viewport:          &playwright.ViewportSize{Width: 1440, Height: 900},
			AcceptDownloads:   playwright.Bool(true),
			IgnoreHTTPSErrors: playwright.Bool(has("insecure")),
			Proxy:             &playwright.Proxy{Server: PROXY, Bypass: "localhost,127.0.0.1,::1"},
			Args: []string{
				"--no-sandbox",
				"--autoplay-policy=no-user-gesture-required",
				"--disable-blink-features=AutomationControlled",
			},
		},
	)
	if err != nil {
		panic(err)
	}
	defer context.Close()

	page := context.Pages()[0]
	if page == nil {
		page, _ = context.NewPage()
	}

	switch cmd {
	case "state":
		cookies, _ := context.Cookies()
		domainMap := make(map[string]bool)
		for _, cookie := range cookies {
			domainMap[cookie.Domain] = true
		}
		domains := make([]string, 0, len(domainMap))
		for domain := range domainMap {
			domains = append(domains, domain)
		}
		sort.Strings(domains)
		fmt.Printf("Profil: %s\n", PROFILE)
		fmt.Printf("%d Cookies über %d Domains:\n", len(cookies), len(domains))
		for _, domain := range domains {
			fmt.Printf("  %s\n", domain)
		}
	case "open", "shot":
		if target == "" {
			panic("URL fehlt")
		}
		page.Goto(target, playwright.PageGotoOptions{WaitUntil: playwright.WaitUntilStateDOMContentLoaded, Timeout: playwright.Float(60000)})
		waitTime, _ := strconv.Atoi(flag("wait", "2500"))
		time.Sleep(time.Duration(waitTime) * time.Millisecond)
		accepted, _ := acceptCookies(page)
		if accepted != "" {
			fmt.Printf("Cookie-Consent bestätigt via: %s\n", accepted)
		}
		time.Sleep(1 * time.Second)
		out := flag("out", filepath.Join("/tmp", fmt.Sprintf("browser-%d.png", time.Now().Unix())))
		page.Screenshot(playwright.PageScreenshotOptions{Path: &out, FullPage: playwright.Bool(has("full"))})
		fmt.Printf("Screenshot: %s\n", out)
		fmt.Printf("URL final: %s\n", page.URL())
	case "login":
		if target == "" {
			panic("URL fehlt")
		}
		env := loadEnv()
		user := env[flag("env-user", "")] 
		if user == "" {
			user = flag("user", "")
		}
		pass := env[flag("env-pass", "")] 
		if pass == "" {
			pass = flag("pass", "")
		}
		page.Goto(target, playwright.PageGotoOptions{WaitUntil: playwright.WaitUntilStateDOMContentLoaded, Timeout: playwright.Float(60000)})
		time.Sleep(2500 * time.Millisecond)
		acceptCookies(page)
		if user != "" {
			uf := flag("user-field", "input[type=email], input[name=email], input[name=username], input[id*=email i]")
			page.Locator(uf).First().Fill(user, playwright.LocatorFillOptions{Timeout: playwright.Float(8000)})
		}
		if pass != "" {
			pf := flag("pass-field", "input[type=password]")
			page.Locator(pf).First().Fill(pass, playwright.LocatorFillOptions{Timeout: playwright.Float(8000)})
		}
		out := flag("out", filepath.Join("/tmp", fmt.Sprintf("login-%d.png", time.Now().Unix())))
		page.Screenshot(playwright.PageScreenshotOptions{Path: &out})
		fmt.Printf("Login-Formular ausgefüllt (user=%s, pass=%s). Screenshot: %s\n", 
			map[bool]string{true: "gesetzt", false: "-"}[user != ""],
			map[bool]string{true: "gesetzt", false: "-"}[pass != ""], 
			out)
		fmt.Println("Absenden bewusst NICHT automatisch — nächster Schritt nach Sichtprüfung.")
	default:
		fmt.Println("Befehle: open <URL> | shot <URL> | login <URL> | state")
	}
}
