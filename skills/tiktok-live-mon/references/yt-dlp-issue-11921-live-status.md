> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# yt-dlp Issue #11921 - TikTok Live Status Bug
**Quelle:** https://github.com/yt-dlp/yt-dlp/issues/11921
**Titel:** [TikTok:live] Livestreams are mistaken as "not currently live" after JSON metadata request

## Problem
TikTok Live API endpoints senden Fehler-Responses, und der Extractor interpretiert diese fälschlicherweise als "nicht live".

## Fehlermeldung
```
[tiktok:live] brxlus: Downloading webpage
[tiktok:live] 7504709338582240046: Downloading JSON metadata
ERROR: [tiktok:live] brxlus: The channel is not currently live
```

## Ursache
- JSON metadata Request gibt Fehler zurück
- Extractor behandelt Fehler als "nicht live" statt als API-Fehler
- Möglicherweise API-Änderungen seitens TikTok

## Implikationen für unser System
- **yt-dlp ist NICHT zuverlässig für TikTok Live-Status**
- Playwright-basierte visuelle Erkennung (roter Rahmen, LIVE-Badge) ist fundamental notwendig
- yt-dlp nur als Fallback für bekannte Fälle nutzen

## Empfohlene Vorgehensweise
1. Playwright check zuerst (visuell)
2. Nur wenn Live bestätigt: URL-Extraktion versuchen
3. yt-dlp nur wenn Streamlink/Playwright fail
- Bei yt-dlp: `--cookies` und `--user-agent` erforderlich
