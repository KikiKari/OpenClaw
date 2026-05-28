# Playwright Navigation & Timeouts - Technische Referenz

**Quelle:** https://playwright.dev/docs/navigations + https://playwright.dev/docs/test-timeouts
**Abgerufen:** 2026-04-19

## Navigation Grundlagen

`page.goto(url)` wartet standardmäßig auf das `load` Event.

### waitUntil Optionen

| Option | Verhalten |
|--------|-----------|
| `load` (default) | Wartet bis gesamte Seite inkl. Ressourcen geladen |
| `domcontentloaded` | Wartet nur bis DOM geladen (schneller) |
| `networkidle` | Wartet auf 500ms ohne Netzwerkaktivität |
| `commit` | Wartet nur bis Navigation committed |

### Timeout Konfiguration

```javascript
// Navigation Timeout (default: kein Timeout)
await page.goto('/', { timeout: 30000 });

// Oder global setzen:
// config: { use: { navigationTimeout: 30_000 } }
```

## Relevanz für TikTok Live

### Problem: networkidle Timeout
TikTok-Seiten laden ständig nach (Ads, Analytics, Live-Stream-Daten).
`networkidle` wird nie erreicht → Timeout.

### Lösung: domcontentloaded + explizites Warten
```javascript
// Statt:
await page.goto(url, { waitUntil: 'networkidle' });

// Besser:
await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForTimeout(3000); // Warte auf dynamische Inhalte
// Oder warte auf spezifisches Element:
await page.waitForSelector('[data-e2e="live-icon"]', { timeout: 10000 });
```

## Network Events (für FLV-URL Capture)

```javascript
// Alle Requests monitoren:
page.on('request', request => console.log('>>', request.method(), request.url()));
page.on('response', response => console.log('<<', response.status(), response.url()));

// Auf spezifische Response warten:
const responsePromise = page.waitForResponse(response =>
  response.url().includes('.flv')
);
```

### Glob URL Patterns
```javascript
// FLV Streams matchen:
page.waitForResponse('**/*.flv*');
// Oder mit RegExp:
page.waitForResponse(/\.flv/);
```

## Overlay/Banner Handling (DSGVO)

```javascript
// Automatisches Handling von Overlays (z.B. Cookie-Banner):
await page.addLocatorHandler(
  page.getByText('Verstanden'),
  async (locator) => { await locator.click(); }
);
```

## Wichtige Hinweise

- Playwright wartet automatisch auf Aktionsfähigkeit von Elementen
- `domcontentloaded` ist schneller als `load` oder `networkidle`
- Bei dynamischen Seiten: Element-basierte Waits > Lifecycle-Waits
- Browser MUSS nach jedem Check geschlossen werden (`browser.close()`)
