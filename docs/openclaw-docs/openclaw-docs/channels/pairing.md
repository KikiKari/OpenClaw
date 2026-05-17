# OpenClaw Pairing

Quelle: https://docs.openclaw.ai/channels/pairing
Gescrapt: 2026-04-21

## DM Pairing
```bash
openclaw pairing list telegram
openclaw pairing approve telegram <CODE>
```
- Codes: 8 Zeichen, uppercase, 1h Gültigkeit
- Max 3 pending Requests pro Channel
- State: ~/.openclaw/credentials/<channel>-pairing.json

## Node Device Pairing
```bash
openclaw devices list
openclaw devices approve <requestId>
openclaw devices reject <requestId>
```

## Pairing via Telegram (empfohlen für iOS)
1. /pair im Telegram Chat
2. Setup Code kopieren
3. In iOS App → Settings → Gateway einfügen
4. /pair pending → approve
