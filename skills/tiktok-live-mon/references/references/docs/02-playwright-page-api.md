# Playwright Page API - Relevante Methoden für TikTok
**Quelle:** https://playwright.dev/docs/api/class-page
**Abgerufen:** 2026-04-19

## page.goto(url, options)
Navigates to URL and waits for load event.

```javascript
await page.goto(url, {
  timeout: 60000,           // Navigation timeout in ms
  waitUntil: 'domcontentloaded'  // 'load' | 'domcontentloaded' | 'networkidle' | 'commit'
});
```

### waitUntil Optionen:
- `load` (default) - Wartet auf load event (alle Ressourcen geladen)
- `domcontentloaded` - Wartet nur auf DOM (schneller!)
- `networkidle` - Wartet auf 500ms ohne Netzwerkaktivität (PROBLEMATISCH bei TikTok)
- `commit` - Wartet nur auf Navigation commit (am schnellsten)

## page.addLocatorHandler(locator, handler, options)
Automatisches Handling von Overlays (DSGVO-Banner etc.):

```javascript
await page.addLocatorHandler(page.getByText('Sign up to the newsletter'), async () => {
  await page.getByRole('button', { name: 'No thanks' }).click();
});
```

Options:
- `noWaitAfter` (boolean) - Nicht warten bis Overlay verschwindet
- `times` (number) - Max Anzahl Handler-Aufrufe

## page.on('request', callback) / page.on('response', callback)
Netzwerk-Events abfangen:

```javascript
page.on('request', request => console.log('>>', request.method(), request.url()));
page.on('response', response => console.log('<<', response.status(), response.url()));
```

## page.waitForRequest(urlOrPredicate, options)
Auf bestimmte Requests warten:

```javascript
const requestPromise = page.waitForRequest('**/*logo*.png');
await page.goto('https://wikipedia.org');
const request = await requestPromise;
```

## page.waitForResponse(urlOrPredicate, options)
Auf bestimmte Responses warten (WICHTIG für FLV-URL Capture):

```javascript
// FLV Stream URL abfangen:
const responsePromise = page.waitForResponse(response =>
  response.url().includes('.flv')
);
await page.goto(url);
const response = await responsePromise;
console.log(response.url()); // Die FLV-URL
```

Glob Patterns:
```javascript
page.waitForResponse('**/*.flv*');
```

## page.route(url, handler, options)
Requests intercepten und modifizieren:

```javascript
// Alle Requests loggen:
await page.route('**/*', async (route) => {
  console.log(route.request().url());
  await route.continue();
});

// Bestimmte Requests blocken (Performance):
await page.route('**/*.{png,jpg,jpeg,gif,svg,css,font}', route => route.abort());
```

## page.waitForTimeout(timeout)
Explizite Wartezeit:

```javascript
await page.waitForTimeout(3000); // 3 Sekunden warten
```

## page.waitForSelector(selector, options)
Auf DOM-Element warten:

```javascript
await page.waitForSelector('[data-e2e="live-icon"]', { timeout: 10000 });
```

## page.close() / browser.close()
Browser MUSS nach jedem Check geschlossen werden:

```javascript
await page.close();
await browser.close();
```
