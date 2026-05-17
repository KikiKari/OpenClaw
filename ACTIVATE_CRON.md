# Cron-Job Aktivierung

## Datei bereits erstellt

✅ `crons/db-maintainer.cron` existiert und ist korrekt konfiguriert.

## Manuelle Aktivierung erforderlich

Aufgrund von Sicherheitsbeschränkungen muss die Aktivierung manuell erfolgen:

### Schritt 1: Crontab öffnen

```bash
crontab -e
```

### Schritt 2: Folgende Zeile hinzufügen

```
*/30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maintainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1
```

Oder alternativ (aus crons-Verzeichnis importieren):

```bash
crontab /home/openclaw/.openclaw/workspace/crons/db-maintainer.cron
```

### Schritt 3: Verifizierung

```bash
# Aktive Cron-Jobs anzeigen
crontab -l

# Oder: Nächsten Lauf prüfen
# (Warte bis :00 oder :30)
tail -f /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log
```

## Was passiert dann?

- Alle 30 Minuten: `tree -L 8`, DB-Updates, Änderungs-Check
- Jede Stunde: Backup beider Datenbanken
- Jede Stunde: Cleanup (Backups > 3 Tage löschen)

## Status

⏳ Warte auf manuelle Aktivierung durch User
