# Playwright Network Requests Interception Tutorial

> Technische Referenz, nicht operative Anleitung. Aktueller TikTok-
> Betriebsstand: `/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md`.
**Quelle:** https://dev.to/philipfong/intercepting-network-requests-in-playwright-25op

## expectRequest Helper Function
Higher-order function für wiederverwendbare Request-Interception:

```typescript
export const expectRequest = async (
  page: Page,
  requests: {url: string, method: string}[],
  action: () => Promise<void>
) => {
  const promises = requests.map(({url, method}) => {
    const predicate = (response: Response) =>
      response.url().includes(url) &&
      response.request().method() === method &&
      response.status() === 200
    return page.waitForResponse(predicate)
  })

  await action()

  return await Promise.all(promises)
}
```

## Verwendung
```typescript
const loginRequest = {url: '/auth', method: 'POST'}
const profileRequest = {url: '/profile', method: 'GET'}
await expectRequest(page, [loginRequest, profileRequest], async () => {
  await page.getByRole('button', { name: 'Log In' }).click()
})
```

## Anwendung für TikTok FLV Capture
```typescript
const flvRequest = {url: '.flv', method: 'GET'}
const responses = await expectRequest(page, [flvRequest], async () => {
  await page.goto('https://www.tiktok.com/@username/live')
})
const flvUrl = responses[0].url()
```
