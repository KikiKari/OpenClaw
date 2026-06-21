> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# Streamlink CLI Referenz - TikTok Relevante Optionen

**Quelle:** https://streamlink.github.io/cli.html (Streamlink 8.3.0)
**Abgerufen:** 2026-04-19

## Grundlegende Verwendung

```bash
streamlink [OPTIONS] <URL> [STREAM]
```

### Stream-Qualität auswählen
- `best` - Höchste verfügbare Qualität
- `worst` - Niedrigste Qualität
- Fallback: `"720p,480p,best"`
- TikTok spezifisch: `ao, ld (worst), sd, hd, hd_60, uhd_60, origin (best)`

## Wichtige Optionen für TikTok

### --stream-url
**Gibt die aufgelöste Stream-URL aus statt den Player zu starten.**
```bash
streamlink --stream-url "https://www.tiktok.com/@example_creator/live" best
```
Dies ist die Methode die wir verwenden um VLC-kompatible URLs zu extrahieren.

### --stream-types / --stream-priority
```bash
--stream-types "hls,http,*"
```
Standard: `hls,http,*`

### --retry-streams DELAY
Wiederhole das Abrufen der verfügbaren Streams alle DELAY Sekunden.
```bash
streamlink --retry-streams 5 --retry-max 3 "URL" best
```

### --retry-open ATTEMPTS
Nach erfolgreichem Abrufen, versuche ATTEMPTS mal den Stream zu öffnen.
Default: 1

## Player Optionen (für direkte Übergabe an VLC)

### --player PATH
```bash
streamlink -p vlc "https://www.tiktok.com/@example_creator/live" best
```
Default: VLC (wenn verfügbar)

### --player-passthrough TYPES
Stream-Typen direkt als URL an Player übergeben:
```bash
streamlink --player-passthrough hls,http "URL" best
```

### --player-external-http
HTTP-Server starten ohne Player zu öffnen:
```bash
streamlink --player-external-http --player-external-http-port 8080 "URL" best
```
Nützlich für externe Geräte oder Weiterleitung.

## Output Optionen

### --stdout / -O
Stream-Daten nach stdout schreiben (für Piping):
```bash
streamlink -O "URL" best | vlc -
```

### --output / -o
In Datei schreiben:
```bash
streamlink -o "stream.ts" "URL" best
```

### --record / -r
Gleichzeitig abspielen und aufnehmen:
```bash
streamlink -r "recording.ts" "URL" best
```

## Logging/Debug

### --loglevel
```bash
streamlink --loglevel debug "URL" best
```
Levels: none, critical, error, warning, info, debug, trace, all

### --json
JSON-Output für Scripting:
```bash
streamlink --json "URL"
```

## TikTok-spezifische Erkenntnisse

1. **Streamlink TikTok Plugin** wurde in Version 8.x komplett neu geschrieben
2. **Verfügbare Qualitäten:** ao, ld, sd, hd, hd_60, uhd_60, origin
3. **--stream-url funktioniert** und gibt kürzere URLs als Playwright zurück
4. **Empfohlener Befehl:**
   ```bash
   streamlink --stream-url "https://www.tiktok.com/@example_creator/live" best
   ```
5. **Bei Problemen mit `best`:** Versuche `sd` oder `ld` als Fallback
   ```bash
   streamlink --stream-url "https://www.tiktok.com/@example_creator/live" "sd,ld,best"
   ```
