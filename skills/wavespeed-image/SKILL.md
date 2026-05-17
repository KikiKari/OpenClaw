# WaveSpeed Image Skill

Bildanalyse und -bearbeitung via WaveSpeedAI Nano Banana 2 (Gemini 3.1 Flash).

## ⚠️ Wichtig: Kostenpflichtig

| Modus | Preis |
|-------|-------|
| Analyse/Beschreibung | ~$0.07 pro Bild |
| Bildbearbeitung | ~$0.07 pro Bild |

**Abrechnung:** Dein WaveSpeed Guthaben  
**Dashboard:** https://wavespeed.ai/account

## Installation

```bash
# Token muss in ~/.config/openclaw/env gesetzt sein:
BANANA_TOKEN="dein-wavespeed-api-key"
```

## Verwendung

### 1. Bildanalyse (analyze)

```bash
# Analysiere Bild mit spezifischem Prompt
wavespeed-image analyze photo.jpg --prompt "Was ist auf diesem Bild zu sehen?" --confirm

# Objekt-Erkennung
wavespeed-image analyze scene.jpg --prompt "Liste alle sichtbaren Objekte" --confirm

# Text-Extraktion
wavespeed-image analyze dokument.png --prompt "Extrahiere allen Text aus diesem Bild" --confirm
```

### 2. Bildbeschreibung (describe)

```bash
# Automatische detaillierte Beschreibung
wavespeed-image describe artwork.jpg --confirm
```

### 3. Bildbearbeitung (edit)

```bash
# Stil-Transfer
wavespeed-image edit portrait.jpg --prompt "Konvertiere zu Ölgemälde-Stil" --confirm

# Hintergrund ändern
wavespeed-image edit product.jpg --prompt "Weißer Hintergrund, professionelle Produktfotografie" --confirm

# Mit Ausgabedatei
wavespeed-image edit input.jpg --prompt "Fantasy Art Style" --output fantasy.jpg --confirm
```

## Optionen

| Option | Beschreibung |
|--------|--------------|
| `--prompt <text>` | Anweisung für Analyse oder Bearbeitung |
| `--output <path>` | Ausgabepfad für bearbeitete Bilder |
| `--dry-run` | Kostenvorschau ohne API-Aufruf |
| `--confirm` | **Erforderlich** für tatsächliche Ausführung |
| `-h, --help` | Hilfe anzeigen |

## API Details

| | |
|---|---|
| **Provider** | WaveSpeedAI |
| **Modell** | `google/nano-banana-2/edit` |
| **API Version** | v3 |
| **Max Bilder** | 1 pro Request |
| **API URL** | `https://api.wavespeed.ai/api/v3` |

## Sicherheitshinweise

- ✋ **Niemals automatisch** — nur explizite User-Anfragen
- 🚫 **Kein Fallback** — wird nie als Fallback-Modell verwendet
- 💰 **Preis-Hinweis** — immer vor Ausführung
- 🔒 **User-Requested Only** — erfordert `--confirm`

## Fehlerbehebung

| Fehler | Lösung |
|--------|--------|
| `BANANA_TOKEN nicht gesetzt` | Token in `~/.config/openclaw/env` hinzufügen |
| `401 Unauthorized` | Token überprüfen auf https://wavespeed.ai/accesskey |
| `429 Rate limit` | Kurz warten und erneut versuchen |
| Task timeout | Bild möglicherweise zu groß oder komplex |

## Beispiel-Workflow

```bash
# 1. Kostenvorschau (optional)
wavespeed-image describe photo.jpg --dry-run

# 2. Ausführung mit Bestätigung
wavespeed-image describe photo.jpg --confirm

# 3. Bearbeitung basierend auf Analyse
wavespeed-image edit photo.jpg --prompt "Mache das Bild professioneller" --confirm
```
