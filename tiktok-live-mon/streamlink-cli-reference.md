# Streamlink CLI Reference

> Technische Referenz. Streamlink ist nur ein Extraktions-Fallback nach
> bestätigtem Live-Preflight. Siehe `../TIKTOK-CURRENT.md`.
**Quelle:** https://streamlink.github.io/cli.html

## Grundnutzung
```bash
streamlink [OPTIONS] <URL> [STREAM]
```

## Qualitätsauswahl
- `best` - Höchste verfügbare Qualität
- `worst` - Niedrigste Qualität
- `best-unfiltered` / `worst-unfiltered` - Ohne Filter
- Fallback: `"720p,480p,best"`

## Wichtige Optionen

### Stream-URL Extraktion
```bash
streamlink --stream-url <URL>
```
Gibt die Stream-URL aus statt sie abzuspielen.

### Schreiben in Datei
```bash
streamlink -o <FILENAME> <URL>
streamlink --output <FILENAME> <URL>
```

### Gleichzeitig Aufnehmen und Abspielen
```bash
streamlink --record <FILENAME> <URL>
```

### Player-Optionen
```bash
-p <PATH>      --player <PATH>
-a <ARGS>      --player-args <ARGS>
-v             --player-verbose
--player-fifo       # Named pipe statt stdin
--player-http       # HTTP statt stdin
```

### Retry-Optionen
```bash
--retry-streams <DELAY>   # Wartezeit zwischen Versuchen
--retry-max <COUNT>       # Max Anzahl Versuche
--retry-open <ATTEMPTS>   # Öffnen-Wiederholungen
```

### Weitere
```bash
-l <LEVEL>     --loglevel <LEVEL>  # none, critical, error, warning, info, debug, trace, all
-j             --json              # JSON Output
-f             --force             # Überschreiben erzwingen
--skip        # Nicht überschreiben
```

## Beispiele
```bash
# Stream-URL extrahieren
streamlink --stream-url https://www.tiktok.com/@username/live

# Weniger Qualität (Performance)
streamlink --stream-url "https://www.tiktok.com/@username/live" sd

# Direkt aufnehmen
streamlink --record "~/recordings/{author}/{category}/{id}-{time:%Y%m%d%H%M%S}.ts" <URL> best
```
