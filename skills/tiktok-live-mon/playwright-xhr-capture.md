> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# Playwright XHR Capture
**Quelle:** https://scrapfly.io/blog/answers/how-to-capture-xhr-requests-playwright

## Request Interception
```javascript
const { chromium } = require('playwright');

async function interceptRequest(route, request) {
 // Update requests with custom headers
 if (request.url().includes("login")) {
 const headers = { ...request.headers(), "Cookie": "cookiesAccepted=true;" };
 await route.continue({ headers });
 }
 else if (request.method() === "POST") {
 await route.continue({ postData: "patched" });
 } else {
 await route.continue();
 }
}

async function interceptResponse(response) {
 // Extract details from background requests
 if (response.url().includes("login")) {
 console.log(response.headers());
 }
 return response;
}

(async () => {
 const browser = await chromium.launch({ headless: false });
 const context = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
 const page = await context.newPage();

 // Intercept requests and responses
 await page.route("**/*", interceptRequest);
 page.on('response', interceptResponse);

 await page.goto("https://example.com");

 await browser.close();
})();
```

## Wichtige Methoden
- `page.route("**/*", handler)` - Alle Requests abfangen
- `page.on('response', handler)` - Alle Responses abfangen
- `route.continue()` - Request fortsetzen
- `route.fulfill()` - Request mit Custom-Response beantworten
# Playwright XHR Capture
**Quelle:** https://scrapfly.io/blog/answers/how-to-capture-xhr-requests-playwright

## Request Interception
```javascript
const { chromium } = require('playwright');

async function interceptRequest(route, request) {
 // Update requests with custom headers
 if (request.url().includes("login")) {
 const headers = { ...request.headers(), "Cookie": "cookiesAccepted=true;" };
 await route.continue({ headers });
 }
 else if (request.method() === "POST") {
 await route.continue({ postData: "patched" });
 } else {
 await route.continue();
 }
}

async function interceptResponse(response) {
 // Extract details from background requests
 if (response.url().includes("login")) {
 console.log(response.headers());
 }
 return response;
}

(async () => {
 const browser = await chromium.launch({ headless: false });
 const context = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
 const page = await context.newPage();

 // Intercept requests and responses
 await page.route("**/*", interceptRequest);
 page.on('response', interceptResponse);

 await page.goto("https://example.com");

 await browser.close();
})();
```

## Wichtige Methoden
- `page.route("**/*", handler)` - Alle Requests abfangen
- `page.on('response', handler)` - Alle Responses abfangen
- `route.continue()` - Request fortsetzen
- `route.fulfill()` - Request mit Custom-Response beantworten
