> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# Streamlink Issue #6832 - TikTok Live Inaccessible
**Quelle:** https://github.com/streamlink/streamlink/issues/6832
**Titel:** plugins.tiktok: Tiktok Live Stream is Inaccessible

## Problem
Streamlink 8.2.0 meldet "The stream is inaccessible" obwohl der Stream im Browser funktioniert.

## Debug Log
```
[session][debug] Loading plugin: tiktok
[cli][info] Found matching plugin tiktok for URL https://www.tiktok.com/@***/live
[plugins.tiktok][error] The stream is inaccessible
error: No playable streams found on this URL: https://www.tiktok.com/@***/live
```

## Implikation
- Streamlink TikTok-Plugin ist nicht zuverlässig
- TikTok ändert APIs/Zugangslogik regelmässig
- Playwright-basierte Extraktion bleibt notwendig als primäre Methode
