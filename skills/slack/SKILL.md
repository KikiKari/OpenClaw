# slack

Slack-Integration für OpenClaw

> ⚠️ **Dokumentation des funktionierenden Zustands** — Diese Config läuft produktiv. Änderungen nur mit Vorsicht!

## Übersicht

| Eigenschaft | Wert |
|-------------|------|
| **Name** | slack |
| **Version** | 1.0.0 |
| **Status** | ✅ **PRODUKTIV** (seit 2026-04-17) |
| **Autor** | OpenClaw Community |
| **Token-Quelle** | Umgebungsvariablen (`.env`)

## Beschreibung

Dieser Skill ermöglicht die volle Integration von OpenClaw mit Slack. Der Bot kann DMs empfangen, in Channels erwähnt werden und bietet nahtlose Kommunikation zwischen Slack und OpenClaw.

## Konfiguration

### Voraussetzungen

1. **Slack App erstellen:**
   - Gehe zu [api.slack.com/apps](https://api.slack.com/apps)
   - "Create New App" → "From scratch"
   - Namen vergeben (z.B. "OpenClaw") und Workspace auswählen

2. **Bot Token Scopes:**
   Unter **OAuth & Permissions** → **Bot Token Scopes**:
   - `chat:write` — Nachrichten senden
   - `im:history` — DM-Verlauf lesen
   - `im:write` — DMs senden
   - `channels:history` — Channel-Verlauf lesen
   - `channels:read` — Channel-Liste lesen
   - `users:read` — Benutzerinformationen lesen
   - `reactions:write` — Reaktionen hinzufügen

3. **App-Level Token (für Socket Mode):**
   Unter **Basic Information** → **App-Level Tokens**:
   - Token mit Scope `connections:write` erstellen

4. **Socket Mode aktivieren:**
   Unter **Socket Mode** → Enable Socket Mode

5. **Tokens kopieren:**
   - **Bot User OAuth Token** (beginnt mit `xoxb-`)
   - **App-Level Token** (beginnt mit `xapp-`)

### OpenClaw Konfiguration (AKTUELL — Funktionierend!)

**WICHTIG:** Die Tokens werden aus Umgebungsvariablen gelesen, NICHT aus `openclaw.json`!

#### Schritt 1: `.env` Datei (`~/.config/openclaw/env`)

```bash
# Slack - Bot Token (für API-Zugriff)
SLACK_BOT_TOKEN="xoxb-DEIN-BOT-TOKEN"

# Slack - App-Level Token (für Socket Mode)  
SLACK_APP_TOKEN="xapp-DEIN-APP-TOKEN"
```

#### Schritt 2: `openclaw.json` (MINIMAL)

```json
{
  "plugins": {
    "entries": {
      "slack": {
        "enabled": true
        // Keine Config nötig — Plugin liest .env automatisch!
      }
    }
  }
}
```

#### Alternative: Hardcoded in JSON (NICHT empfohlen)

Falls Umgebungsvariablen nicht funktionieren:

```json
{
  "plugins": {
    "entries": {
      "slack": {
        "enabled": true,
        "config": {
          "botToken": "xoxb-DEIN-BOT-TOKEN",
          "appToken": "xapp-DEIN-APP-TOKEN",
          "socketMode": true
        }
      }
    }
  }
}
```

**Aber:** Der aktuelle funktionierende Zustand nutzt die `.env`-Methode!

### Pairing

1. User sendet "challenge" an den Bot (DM oder @Mention)
2. Bot antwortet mit Pairing-Code
3. Admin führt aus:
   ```bash
   openclaw pairing approve slack <CODE>
   ```
4. Der User ist jetzt gepaired und kann den Bot nutzen

## Verwendung

### Direktnachrichten (DMs)

Schreibe direkt an @OpenClaw im Slack:
```
Hallo, kannst du mir bei X helfen?
```

### Channel-Mentions

Erwähne den Bot in einem Channel:
```
@OpenClaw Wie ist das Wetter heute?
```

### Reactions

Der Bot kann auf Nachrichten reagieren (👍, ✅, etc.) wenn konfiguriert.

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| Bot antwortet nicht | Prüfe Pairing: `openclaw pairing list` |
| "access not configured" | Token in `openclaw.json` prüfen |
| Verbindung bricht ab | Socket Mode aktivieren |
| Keine DMs möglich | `im:write` Scope prüfen |

## Gateway-Neustart

Nach Konfigurationsänderungen:
```bash
openclaw gateway restart
```

## Verwandte Dokumente

- [SLACK.md](/home/openclaw/.openclaw/workspace/SLACK.md) — Workspace-Dokumentation
- [MEMORY.md](/home/openclaw/.openclaw/workspace/MEMORY.md) — Aktuelle Änderungen

## Änderungshistorie

| Datum | Änderung |
|-------|----------|
| 2026-04-17 | Skill erstellt, Token konfiguriert, Pairing aktiviert |
