# Playwright Request/Response Interception
**Quelle:** https://checklyhq.com/docs/learn/playwright/intercept-requests

## Request Interception
```typescript
test('intercept requests', async ({ page }) => {
 page.on('request', request => {
 console.log('Request:', request.url());
 });

 page.on('response', response => {
 console.log('Response:', response.url(), response.status());
 });

 await page.goto('https://example.com/');
});
```

## Block Requests
```typescript
test('block image requests', async ({ page }) => {
 await page.route('**/*', route => {
 if (route.request().resourceType() === 'image') {
 route.abort();
 } else {
 route.continue();
 });
 });

 await page.goto('https://example.com/');
});
```

## Response Interception / Stubbing
```typescript
test('intercept and modify response', async ({ page }) => {
 await page.route('**/api/best-sellers', route => {
 const customResponse = {
 books: [
 { title: 'Custom Book', author: 'Custom Author', price: '$19.99' }
 ]
 };

 route.fulfill({
 status: 200,
 contentType: 'application/json',
 body: JSON.stringify(customResponse)
 });
 });

 await page.goto('https://example.com/');
});
```

## Takeaways
1. Playwright gives control over outgoing HTTP requests
2. Playwright can easily stub HTTP responses
3. For production monitoring, avoid network interception - test the entire stack
