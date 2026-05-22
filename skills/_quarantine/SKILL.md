# WaveSpeed Image Skill

Bild-Analyse via WaveSpeedAI Nano Banana 2 mit kostenpflichtiger Nutzung.

## ⚠️ Wichtig: Kostenpflichtig

**Preis:** $0.14 pro Bild  
**Max pro Request:** 7 Bilder = ~$1.00  
**Abrechnung:** Dein WaveSpeed Guthaben

## Verwendung

```bash
# Einzelnes Bild analysieren
wavespeed-image analyze <image-path> [--prompt "Beschreibung was analysiert werden soll"]

# Mehrere Bilder
wavespeed-image analyze <image1> <image2> ... [--prompt "..."]
```

## Beispiele

```bash
# Objekt-Erkennung
wavespeed-image analyze photo.jpg --prompt "Was ist auf diesem Bild zu sehen?"

# Text-Extraktion
wavespeed-image analyze dokument.png --prompt "Extrahiere allen Text"

# Vergleich mehrerer Bilder
wavespeed-image analyze img1.jpg img2.jpg img3.jpg --prompt "Vergleiche diese Bilder"
```

## API

- **Provider:** WaveSpeedAI
- **Modell:** `google/nano-banana-2/edit`
- **Dokumentation:** https://wavespeed.ai/docs/rest-api

## Konfiguration

| Variable | Quelle | Beschreibung |
|----------|--------|--------------|
| `BANANA_TOKEN` | `~/.config/openclaw/env` | WaveSpeed API Key |

## Einschränkungen

- **Niemals automatisch** — nur explizite User-Anfragen
- **Kein Fallback** — wird nie als Fallback-Modell verwendet
- **Preis-Hinweis** — immer vor Ausführung
- **Rate Limit:** Max 7 Bilder pro Request

## Preis-Beispiele

| Anzahl Bilder | Kosten |
|---------------|--------|
| 1 Bild | $0.14 |
| 3 Bilder | $0.42 |
| 7 Bilder | $0.98 |
