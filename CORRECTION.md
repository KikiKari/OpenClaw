# Korrektur: Kein su nötig!

Du bist **bereits als openclaw** angemeldet!

Siehe dein Prompt:
```
openclaw@v2202604104722446711:/home/Archiv/workspace$
```

**Kein `su openclaw` nötig** - das fragt nach Passwort weil du schon openclaw bist.

## Richtige Befehle (für dich direkt):

```bash
# Direkt ausführen (kein su!):
crontab /home/openclaw/.openclaw/workspace/crons/db-maintainer.cron

# Oder manuell bearbeiten:
crontab -e

# Verifizieren:
crontab -l
```

Das `su openclaw` wäre nur nötig wenn du als **root** oder anderer User angemeldet wärst.
