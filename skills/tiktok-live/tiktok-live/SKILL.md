---
name: tiktok-live
description: Extract TikTok live stream URLs and check live status using Playwright and visual detection. Use when: (1) Checking if a TikTok user is currently live streaming, (2) Extracting VLC/MPV-compatible stream URLs from TikTok Live, (3) Monitoring TikTok accounts for live streams, (4) Converting TikTok live streams to FLV URLs for playback or download. NOT for: recorded videos, TikTok API queries, or non-live content.
---

# TikTok Live Stream Extraction

Extract live stream URLs from TikTok using Playwright-based visual detection. Replaces unreliable API-based methods.

## Overview

This skill provides reliable TikTok Live stream extraction by:
1. Using Playwright + Chromium for visual live status detection
2. Capturing network traffic to extract FLV stream URLs
3. Supporting multiple playback methods (VLC, MPV, FFmpeg)

**Why not API?** TikTok's API consistently returns OFFLINE even for active streams. Visual detection is the only reliable method.

## Prerequisites

```bash
# Install Playwright (if not present)
npm install playwright
npx playwright install chromium

# UFW Firewall (outgoing)
sudo ufw allow out 80/tcp
sudo ufw allow out 443/tcp
```

## Quick Start

### Check Live Status

```bash
node ~/.openclaw/skills/tiktok-live/scripts/tiktok-check-profile.js <username>
```

**Output:** JSON with `isLive` boolean and detection indicators

### Extract Stream URL

```bash
node ~/.openclaw/skills/tiktok-live/scripts/tiktok-get-stream.js <username>
```

**Output:** Nackte URL (eine Zeile), z.B.:
```
https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/stream-..._ld.flv?...
```
Bei Fehler oder nicht-live: leerer Output + exit code 1.

## How It Works

### Step 1: DSGVO Banner Handling
The cookie banner blocks the profile picture. Must be closed first:

```javascript
const verstandenButton = await page.$('button:has-text("Verstanden")');
if (verstandenButton) await verstandenButton.click();
```

### Step 2: Wait for Full Page Load
Wait for "Erneute Veröffentlichungen" tab to appear (indicates complete load).

### Step 3: Visual Live Detection
Check multiple indicators in order of reliability:
1. LIVE badge (`text=/^LIVE$/i`) - most reliable
2. Red border around profile picture - check `borderColor` and `boxShadow`
3. Live link presence (`a[href*="/live"]`)

### Step 4: Stream URL Extraction
If live, navigate to `/live` and capture network traffic for `.flv` URLs.

### Step 5: Browser Cleanup
**Critical:** Always close browser with `browser.close()` to ensure fresh sessions.

## Stream Playback Options

Das Skript gibt nur die nackte URL aus. Zum Abspielen:

```bash
# VLC
vlc "$(node ~/.openclaw/skills/tiktok-live/scripts/tiktok-get-stream.js username)"

# MPV (mit Cache)
mpv --cache=yes --cache-secs=30 "URL"

# FFmpeg (Download)
ffmpeg -i "URL" -c copy output.mp4

# FFmpeg (Restream zu RTMP)
ffmpeg -i "URL" -c copy -f flv rtmp://...
```

**Wichtig:** URLs immer als nackte URLs weitergeben — kein `vlc "..."` Prefix in Dokumentation oder Logs.

## Alternative Extraction Methods

| Method | Command | Pros | Cons |
|--------|---------|------|------|
| yt-dlp | `yt-dlp -g "https://tiktok.com/@user/live"` | Fast, no browser | Less reliable |
| streamlink | `streamlink "https://tiktok.com/@user/live" best` | Multi-platform | Experimental support |
| gallery-dl | `gallery-dl -g "https://..."` | Dedicated tool | Limited TikTok support |

## Critical Learnings

- **DSGVO banner**: MUST close first or LIVE badge is hidden
- **Page load**: Wait for "Erneute Veröffentlichungen" tab
- **Browser cleanup**: Essential for fresh sessions
- **Stream TTL**: URLs valid 2-4 hours (signature-based)
- **Quality levels**: `_ld.flv` (low), `_sd.flv` (standard), `_hd.flv` (high)

## Stream Restrictions

TikTok Live Streams können verschiedene Einschränkungen haben, die die Extraktion beeinflussen:

### 1. Age-Restricted / Age-Gated Streams
**Erkennungsmerkmale:**
- Kein roter Rahmen um Profilbild auf der Profilseite
- Kein LIVE-Badge auf der Profilseite
- Auf `/live` Seite: "Bei TikTok anmelden" + "Dieses LIVE enthält Themen, die von einigen als unangenehm empfunden werden können"
- Stream läuft technisch, ist aber ohne Login nicht zugänglich

**Auswirkungen:**
- FLV-URLs können nicht extrahiert werden (kein Netzwerk-Traffic ohne Auth)
- `tiktok-check-profile.js` zeigt möglicherweise `isLive: true` (technisch korrekt, aber nicht öffentlich)
- Alte FLV-Links funktionieren nicht (Signatur abgelaufen)

**Lösung:**
- Warten auf nächsten öffentlichen Stream
- Oder: Extraktion mit authentifiziertem TikTok-Account (Login-Cookies erforderlich)

### 2. [Weitere Einschränkungen - dokumentieren sobald reproduzierbar]
- Region-locked Streams
- Follower-only Streams
- Subscriber-only Streams

## Multi-Node Support (Stand: 2026-04-11)

### Verfügbare Nodes mit Playwright/Chromium

| Node | Status | Xvfb | Playwright | Verwendung |
|------|--------|------|------------|------------|
| Gateway | ✅ Bereit | :99 | Nativ | Haupt-Checks |
| Node 2 | ✅ Bereit | :99 | v1.59.1 | Parallel-Checks |
| Node 3 | ✅ Bereit | :99 | v1.59.x | Backup/Parallel |  

### Node-basierte Ausführung

```bash
# Auf Node 2
ssh node2 "cd /tmp && export DISPLAY=:99 && node check-tiktok.js username"

# Auf Node 3  
ssh node3 "cd /tmp && export DISPLAY=:99 && node check-tiktok.js username"
```

**Wichtig:** Alle Nodes nutzen einheitlich User=openclaw für Xvfb (systemd-Service).

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No LIVE badge visible | Check/close DSGVO banner |
| Browser hangs | `pkill -f chromium` |
| 403 on stream URL | URL expired, re-extract |
| Session issues | Ensure `browser.close()` called |
| FFmpeg 403 | Add `-user_agent "Mozilla/5.0"` |
| Stream erkannt aber keine FLV URL | Prüfe auf Age-Restriction (siehe oben) |
| "Bei TikTok anmelden" auf /live | Stream ist age-restricted, Login erforderlich |
| SSH-Tunnel down (Node 3) | Restart: `ssh -f -N -R 18794:localhost:22 ...` |

## References

- Full documentation: `references/TIKTOK.md`
- Master documentation: `/home/openclaw/.openclaw/workspace/TIKTOK.md`
- Session log: `/home/openclaw/.openclaw/workspace/memory/2026-04-06.md`
- MEMORY.md: Search "TikTok Live Stream Extraktion"

## Scripts

- `scripts/tiktok-check-profile.js` - Live status check
- `scripts/tiktok-get-stream.js` - Stream URL extraction
