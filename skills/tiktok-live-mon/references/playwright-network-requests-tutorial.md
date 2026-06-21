> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# Playwright Network Requests Interception Tutorial
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
  await page.goto('https://www.tiktok.com/@example_creator/live')
})
const flvUrl = responses[0].url()
```
