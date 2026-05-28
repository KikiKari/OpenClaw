# Playwright Navigations & Timeouts
**Quelle:** https://playwright.dev/docs/navigations
**Abgerufen:** 2026-04-19

## Basic navigation

```javascript
await page.goto('https://example.com');
```
Loads the page and waits for the `load` event. If the page does a client-side redirect before load, `page.goto()` will wait for the redirected page to fire the load event.

## When is the page loaded?

Modern pages perform numerous activities after the load event was fired. They fetch data lazily, populate UI, load expensive resources, scripts and styles after the load event was fired. There is no way to tell that the page is loaded, it depends on the page, framework, etc.

In Playwright you can interact with the page at any moment. It will automatically wait for the target elements to become actionable.

```javascript
await page.goto('https://example.com');
await page.getByText('Example Domain').click();
```

## Hydration

When page is hydrated, first, a static version of the page is sent to the browser. Then the dynamic part is sent and the page becomes "live". As a very fast user, Playwright will start interacting with the page the moment it sees it. And if the button on a page is enabled, but the listeners have not yet been added, Playwright will do its job, but the click won't have any effect.

A simple way to verify: open Chrome DevTools, pick "Slow 3G" network emulation and reload the page.

## Waiting for navigation

Clicking an element could trigger multiple navigations. In these cases, it is recommended to explicitly `page.waitForURL()` to a specific url.

```javascript
await page.getByText('Click me').click();
await page.waitForURL('**/login');
```

## Navigation events

- `page.url()` is set to the new url
- document content is loaded over network and parsed
- `page.on('domcontentloaded')` event is fired
- page executes some scripts and loads resources like stylesheets and images
- `page.on('load')` event is fired
- page executes dynamically loaded scripts
