# yt-dlp Issue #15970 - Cookies Fix

> Externe/historische Referenz. Aktueller OpenClaw-Betriebsstand:
> `/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md`.
**Quelle:** https://github.com/yt-dlp/yt-dlp/issues/15970
**Titel:** Unable to work the Cookies

## Problem
Nutzer konnte trotz korrekter Cookies-Datei keine YouTube-Videos herunterladen. Fehlermeldung: "Sign in to confirm you're not a bot."

## Debug Output zeigt
```
[youtube] Found YouTube account cookies
[youtube] xTjGWowQ2ZU: Downloading webpage
[youtube] xTjGWowQ2ZU: Downloading android vr player API JSON
[youtube] xTjGWowQ2ZU: Downloading tv downgraded player API JSON
[youtube] xTjGWowQ2ZU: Downloading web safari player API JSON
WARNING: [youtube] xTjGWowQ2ZU: n challenge solving failed
WARNING: Only images are available for download
ERROR: [youtube] xTjGWowQ2ZU: Requested format is not available
```

## Lösungsansätze
1. **Update auf Nightly/Master**
2. **Cookies korrekt exportieren** mit "Get cookies locally" Extension
3. **JavaScript Runtime installieren** (bun, deno, node) für Challenge Solving
4. **Proxy/Netzwerk prüfen** - gleiche IP erforderlich

## Wichtig für TikTok
- yt-dlp nutzt dieselbe Cookie-Logik für alle Plattformen
- `--cookies cookies.txt` oder `--cookies-from-browser chrome`
- Bei "not currently live" trotz Live-Status: Cookies erneuern
