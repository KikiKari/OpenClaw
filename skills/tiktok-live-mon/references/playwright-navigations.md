> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# Playwright Navigations & Timeouts
**Quelle:** https://playwright.dev/docs/navigations

## Basic navigation
```javascript
await page.goto('https://example.com');
```
Loads the page and waits for the `load` event.

## When is the page loaded?
Modern pages perform numerous activities after the load event. They fetch data lazily, populate UI, load expensive resources. There is no way to tell that the page is loaded. In Playwright you can interact with the page at any moment. It will automatically wait for target elements to become actionable.

```javascript
await page.goto('https://example.com');
await page.getByText('Example Domain').click();
```

## Hydration
When page is hydrated, first a static version is sent, then dynamic part makes it "live". Playwright may interact before listeners are added. Fix: disable interactive controls until hydration complete.

## Waiting for navigation
```javascript
await page.getByText('Click me').click();
await page.waitForURL('**/login');
```

## Navigation events
1. `page.url()` set to new url
2. document content loaded and parsed
3. `page.on('domcontentloaded')` fired
4. scripts execute, resources load
5. `page.on('load')` fired
6. dynamically loaded scripts execute
