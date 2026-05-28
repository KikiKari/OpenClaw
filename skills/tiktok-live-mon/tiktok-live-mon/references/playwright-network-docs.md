# Playwright Network - Offizielle Doku
**Quelle:** https://playwright.dev/docs/network

## Network Events
```javascript
page.on('request', request => console.log('>>', request.method(), request.url()));
page.on('response', response => console.log('<<', response.status(), response.url()));
await page.goto('https://example.com');
```

## waitForResponse
```javascript
// Use a glob URL pattern. Note no await.
const responsePromise = page.waitForResponse('**/api/fetch_data');
await page.getByText('Update').click();
const response = await responsePromise;
```

## Variations
```javascript
// Use a RegExp
const responsePromise = page.waitForResponse(/\.jpeg$/);

// Use a predicate
const responsePromise = page.waitForResponse(response => response.url().includes(token));
```

## Handle Requests
```javascript
await page.route('**/api/fetch_data', route => route.fulfill({
 status: 200,
 body: testData,
}));
await page.goto('https://example.com');
```

## Modify Requests
```javascript
// Delete header
await page.route('**/*', async route => {
 const headers = route.request().headers();
 delete headers['X-Secret'];
 await route.continue({ headers });
});

// Continue as POST
await page.route('**/*', route => route.continue({ method: 'POST' }));
```

## Abort Requests
```javascript
await page.route('**/*.{png,jpg,jpeg}', route => route.abort());

// Abort based on request type
await page.route('**/*', route => {
 return route.request().resourceType() === 'image' ? route.abort() : route.continue();
});
```

## Glob URL Patterns
- `*` matches any characters except /
- `**` matches any characters including /
- `{a,b,c}` matches a list of options
- `\` escapes special characters

Examples:
- `https://example.com/*.js` matches https://example.com/file.js
- `**/*.js` matches both https://example.com/file.js and subpaths
- `**/*.{png,jpg}` matches all image requests
