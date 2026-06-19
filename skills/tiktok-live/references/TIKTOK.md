# TikTok Live Monitor - Dokumentation

**Letzte Aktualisierung:** 2026-04-06
**Status:** ✅ Playwright-basierte Extraktion operational

---

## Architektur-Update (2026-04-06)

### ❌ Veraltete Architektur (nicht mehr in Betrieb)

Die ursprüngliche 3-Tier API-Architektur ist **obsolet**:

```
┌─────────────────┐     SSH Tunnel      ┌─────────────────┐
│   NODE 1        │═════════════════════│   NODE 2        │
│   (Hetzner)     │◄────Port 15000─────│   (Netcup)      │
│   Main Gateway  │◄────Port 18792─────│   Worker        │
│   Ubuntu 24.04  │                     │   Ubuntu 24.04  │
└─────────────────┘                     └─────────────────┘
         │
         │ Port 18791/18792
         │
         ▼
┌─────────────────┐
│   NODE 3        │
│   (Netcup)      │
│   CentOS 8      │
│   TikTok API    │  ← DEFEKT (liefert falsche OFFLINE-Status)
└─────────────────┘
```

**Warum obsolet:**
- `tiktok-live-connector` API gibt konsistent falsche OFFLINE-Status zurück
- Selbst bei aktiv laufenden Streams: API meldet "OFFLINE"
- NGINX Load-Balancing nutzlos bei defekter Datenquelle

---

## ✅ Neue Architektur: Playwright + Visuelle Erkennung

```
┌─────────────────────────────────────────────┐
│  NODE 1 (Hetzner - Main Gateway)            │
│  Ubuntu 24.04, 16GB RAM                     │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Playwright + Chromium              │   │
│  │  ├─ tiktok-check-profile.js        │   │
│  │  └─ tiktok-get-stream.js           │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Memory & Dokumentation             │   │
│  │  ├─ TIKTOK.md (diese Datei)        │   │
│  │  ├─ MEMORY.md (Langzeitspeicher)   │   │
│  │  └─ memory/2026-04-06.md            │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

---

## Verfügbare Skripte

| Skript | Zweck | Aufruf |
|--------|-------|--------|
| `tiktok-check-profile.js` | Live-Status prüfen | `node tiktok-check-profile.js <username>` |
| `tiktok-get-stream.js` | FLV-Stream-URL extrahieren | `node tiktok-get-stream.js <username>` |

**Pfad:** `/home/openclaw/.openclaw/workspace/`

---

## Überwachte Accounts

- @example_creator
- @example_creator

**Letzte erfolgreiche Extraktion:**
- Account: @example_creator
- Zeit: 2026-04-06 10:42 CET
- Ergebnis: VLC-kompatible FLV-URL extrahiert & verifiziert

---

## Kritische Learnings (2026-04-06)

### 1. DSGVO-Banner Handling
```javascript
// Banner MUSZ zuerst geschlossen werden
const verstandenButton = await page.$('button:has-text("Verstanden")');
if (verstandenButton) await verstandenButton.click();
```
**Warum:** Der Banner überdeckt das Profilbild — ohne Schließung kein LIVE-Badge sichtbar.

### 2. Seitenlade-Reihenfolge
```
1. Navigate to @username
2. Warte auf domcontentloaded
3. Schließe DSGVO-Banner (sofort)
4. Warte 3-5s auf vollständiges Rendern
5. Warte auf networkidle (API-Calls)
6. +2s für TikTok-interne Live-Prüfung
```

**Indikator für vollständiges Laden:**
Der Reiter "Erneute Veröffentlichungen" erscheint erst, wenn die Seite komplett geladen ist.

### 3. Live-Indikatoren (Zuverlässigkeit)
| Indikator | Zuverlässigkeit | Erkennung |
|-----------|-----------------|-----------|
| LIVE-Badge | ⭐⭐⭐⭐⭐ | `text=/^LIVE$/i` |
| Roter Rahmen | ⭐⭐⭐⭐☆ | `borderColor` + `boxShadow` |
| Live-Link | ⭐⭐⭐☆☆ | `a[href*="/live"]` |

### 4. Browser-Cleanup (KRITISCH)
```javascript
await browser.close();  // Nicht vergessen!
```
**Warum:** Ohne sauberes Cleanup bleiben Session-Cookies/Cache erhalten — nächste Abfrage ist beeinflusst.

---

## Stream-URL Format

**Beispiel (funktionierend):**
```
https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/stream-<ID>_ld.flv
?_session_id=<SESSION>
&_webnoredir=1
&abr_pts=-2800
&expire=<TIMESTAMP>
&sign=<SIGNATURE>
```

**Parameter:**
- `_ld.flv` = Low Definition (auch `_sd.flv`, `_hd.flv` möglich)
- `expire` = Unix-Timestamp (2-4h TTL)
- `sign` = HMAC-Signatur (pro Sitzung einzigartig)

---

## Stream-Wiedergabe (Player-Optionen)

### 1. VLC (empfohlen)
```bash
# Direkter Aufruf
vlc "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/stream-..."

# Mit User-Agent (falls nötig)
vlc --http-user-agent="Mozilla/5.0" "https://..."

# Headless (nur Audio)
cvlc "https://..." --intf dummy
```

### 2. MPV
```bash
# Standard
mpv "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/stream-..."

# Mit Cache für stabilere Wiedergabe
mpv --cache=yes --cache-secs=30 "https://..."

# Nur Audio
mpv --no-video "https://..."
```

### 3. FFmpeg (Download/Reweaming)
```bash
# Direktes Download
ffmpeg -i "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/stream-..." \
  -c copy output.flv

# Zu MP4 konvertieren
ffmpeg -i "https://..." -c copy output.mp4

# Zu HLS für Web-Player
ffmpeg -i "https://..." -c copy -f hls -hls_time 10 -hls_list_size 0 playlist.m3u8

# Live-Reweaming zu RTMP (z.B. YouTube)
ffmpeg -i "https://..." -c copy -f flv rtmp://youtube.com/...
```

### 4. ffplay (einfache Wiedergabe)
```bash
ffplay "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/stream-..."

# Mit Buffer
ffplay -buffer_size 65536 "https://..."
```

### 5. Streamlink (Multi-Platform)
```bash
# Installation
pip install streamlink

# TikTok Live (experimentell)
streamlink "https://tiktok.com/@example_creator/live" best

# Mit Player
streamlink --player=mpv "https://tiktok.com/@example_creator/live" best
```

### 6. yt-dlp (Download)
```bash
# Installation
pip install yt-dlp

# Direkte Stream-URL extrahieren
yt-dlp -g "https://tiktok.com/@example_creator/live"

# Mit Wiedergabe
yt-dlp -o - "https://tiktok.com/@example_creator/live" | mpv -
```

---

## Alternative Extraktions-Methoden

### Methode A: yt-dlp (kein Playwright nötig)
```bash
# Prüft Live-Status und gibt Stream-URL
yt-dlp --no-warnings -g "https://tiktok.com/@example_creator/live" 2>/dev/null
```
**Pro:** Kein Browser, schnell
**Con:** Weniger zuverlässig bei Bot-Erkennung

### Methode B: gallery-dl
```bash
# Installation
pip install gallery-dl

# Extraktion
 gallery-dl -g "https://tiktok.com/@example_creator/live"
```

### Methode C: you-get
```bash
# Installation
pip install you-get

# Stream-Info
you-get -i "https://tiktok.com/@example_creator/live"
```

---

## Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| Kein LIVE-Badge sichtbar | DSGVO-Banner prüfen / schließen |
| Browser hängt | `pkill -f chromium` |
| Session abgelaufen | Neue Instanz starten (nicht wiederverwenden) |
| FLV-URL 403 | URL hat 2-4h TTL — neu extrahieren |
| FFmpeg "403 Forbidden" | User-Agent hinzufügen: `-user_agent "Mozilla/5.0"` |
| Stream ruckelt | Buffer erhöhen: `-buffer_size 1M` |

---

## UFW Firewall (für Outgoing)

**Erforderliche Ports:**
```bash
sudo ufw allow out 80/tcp    # HTTP
sudo ufw allow out 443/tcp   # HTTPS
sudo ufw allow out 8080/tcp  # HTTP alt
sudo ufw allow out 8443/tcp  # HTTPS alt
```

---

## Referenzen

- **Detaillierte Session-Doku:** `memory/2026-04-06.md`
- **Langzeitspeicher:** `MEMORY.md` (Abschnitt "TikTok Live Stream Extraktion")
- **AGENTS.md:** Architektur-Learnings & Konventionen
- **Cron-Logs:** `~/.openclaw/cron/runs/`

---

## Historie

| Datum | Änderung |
|-------|----------|
| 2026-04-02 | Erste Architektur (3-Tier API) |
| 2026-04-03 | API-Probleme dokumentiert |
| 2026-04-06 | **Umstellung auf Playwright** — erste erfolgreiche Extraktion |
| 2026-04-06 | Alternative Wiedergabe-Methoden dokumentiert (FFmpeg, MPV, yt-dlp, etc.) |
