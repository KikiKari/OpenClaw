# Playwright Response Values aus Network Requests
**Quelle:** https://playwrightsolutions.com/get-a-response-value-of-an-underlying-network-request-when-running-a-playwright-test/

## Konzept: Response-Werte abfangen und nutzen

### page.route + route.fetch Pattern
Variable auf Test-Level deklarieren, dann in route-Handler setzen:

```javascript
let message;

await page.route("**/message/count", async (route) => {
  const response = await route.fetch();
  message = await response.json();
  route.continue();
});

await page.goto("https://example.com");
// message ist jetzt verfügbar
```

### waitForResponse Pattern
```javascript
await page.waitForResponse("**/message/count");
```

## Anwendung für TikTok FLV
```javascript
let flvUrl;

await page.route("**/*.flv*", async (route) => {
  flvUrl = route.request().url();
  route.continue();
});

// Oder mit page.on:
page.on('response', (response) => {
  if (response.url().includes('.flv')) {
    flvUrl = response.url();
  }
});

await page.goto("https://www.tiktok.com/@username/live");
// flvUrl enthält jetzt die Stream-URL
```

## Wichtig
- Variable mit `let` auf äusserem Scope deklarieren (nicht in route-Callback)
- `route.fetch()` + `route.continue()` um Response zu lesen UND weiterzuleiten
- `page.waitForResponse()` als synchroner Wait-Punkt
