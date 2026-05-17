# Discord Setup - Vorbereitung

## Bot erstellen
1. https://discord.com/developers/applications → "New Application"
2. Name: Artii (oder ClawHammer)
3. Bot → "Add Bot" → Token kopieren
4. "Privileged Gateway Intents" aktivieren:
   - MESSAGE CONTENT INTENT ✅
   - SERVER MEMBERS INTENT ✅
   - PRESENCE INTENT ✅

## Bot einladen
URL generieren unter OAuth2 → URL Generator:
- Scopes: bot, applications.commands
- Permissions: Send Messages, Read Message History, Add Reactions, Manage Messages

## Config einfügen
In `~/.openclaw/openclaw.json` unter `channels` hinzufügen:

```json
"discord": {
  "enabled": true,
  "token": "DISCORD_BOT_TOKEN_HIER",
  "dm": {
    "enabled": true
  },
  "actions": {
    "reactions": true,
    "messages": true,
    "pins": true,
    "search": true,
    "channelInfo": true,
    "memberInfo": true
  },
  "heartbeat": {
    "showOk": true,
    "showAlerts": true
  }
}
```

Dann: `openclaw gateway restart`

## Status
- [ ] Bot erstellt
- [ ] Token generiert
- [ ] Bot eingeladen
- [ ] Config eingetragen
- [ ] Gateway neugestartet
- [ ] Test-Nachricht gesendet
