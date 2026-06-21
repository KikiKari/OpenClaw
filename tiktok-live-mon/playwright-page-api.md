# Playwright Page API - TikTok relevante Methoden

> Technische Referenz, nicht operative Anleitung. Aktueller TikTok-
> Betriebsstand: `/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md`.
**Quelle:** https://playwright.dev/docs/api/class-page

## page.goto(url, options)
```javascript
await page.goto(url, {
  timeout: 60000,
  waitUntil: 'domcontentloaded' // 'load'|'domcontentloaded'|'networkidle'|'commit'
});
```

## page.addLocatorHandler(locator, handler, options)
Overlay/DSGVO-Banner automatisch schliessen:
```javascript
await page.addLocatorHandler(page.getByText('Sign up'), async () => {
  await page.getByRole('button', { name: 'No thanks' }).click();
});
// Options: noWaitAfter (bool), times (number)
```

## page.on('request'/'response', callback)
```javascript
page.on('request', req => console.log('>>', req.method(), req.url()));
page.on('response', res => console.log('<<', res.status(), res.url()));
```

## page.waitForResponse(urlOrPredicate, options)
FLV-URL capture:
```javascript
const resp = page.waitForResponse(r => r.url().includes('.flv'));
await page.goto(url);
const flvResponse = await resp;
console.log(flvResponse.url());
```

## page.route(url, handler)
Request interception:
```javascript
await page.route('**/*', async route => {
  console.log(route.request().url());
  await route.continue();
});
// Block resources for performance:
await page.route('**/*.{png,jpg,css}', route => route.abort());
```

## page.waitForTimeout(ms)
```javascript
await page.waitForTimeout(3000);
```

## page.waitForSelector(selector, options)
```javascript
await page.waitForSelector('[data-e2e="live-icon"]', { timeout: 10000 });
```

## page.close() / browser.close()
```javascript
await page.close();
await browser.close();
```
