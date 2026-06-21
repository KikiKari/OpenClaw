# Streamlink Issue #6832 - TikTok Live Inaccessible

> Externe/historische Referenz. Aktueller OpenClaw-Betriebsstand:
> `/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md`.
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
