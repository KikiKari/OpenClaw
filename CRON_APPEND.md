# Crontab-Eintrag HINZUFÜGEN (nicht überschreiben)

## Methode 1: Bestehende Crontab behalten + neuen Eintrag

```bash
# Als openclaw (bist du schon):

# 1. Aktuelle Crontab in Datei speichern
crontab -l > /tmp/mein_crontab.txt

# 2. Neuen Eintrag anhängen
echo "*/30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maintainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1" >> /tmp/mein_crontab.txt

# 3. Neue Crontab laden
crontab /tmp/mein_crontab.txt

# 4. Verifizieren
crontab -l
```

## Methode 2: Direkt mit crontab -e (sicherer)

```bash
# Als openclaw:
crontab -e

# Im Editor ans Ende der Datei gehen und einfügen:
*/30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maintainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1

# Speichern und schließen (nano: Ctrl+O, Enter, Ctrl+X)
```

## Methode 3: One-Liner (kompakt)

```bash
# Zeile an bestehende Crontab anhängen
(crontab -l 2>/dev/null; echo "*/30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maintainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1") | crontab -
```

## Prüfung

```bash
# Alle Einträge anzeigen (bestehende + neuer)
crontab -l
```

---
**Wichtig**: Alle Methoden behalten bestehende Einträge bei!
