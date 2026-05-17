# Cron-Job Aktivierung - Korrekte Vorgehensweise

## ⚠️ WICHTIG: Benutzer = openclaw (nicht root!)

Alle Dateien gehören `openclaw`, daher MUSS der Cron-Job unter diesem Benutzer laufen.

## Warum exec blockiert?

OpenClaw blockiert komplexe Shell-Befehle mit `cd`, `&&`, `||` aus Sicherheitsgründen (AGENTS.md Regeln). Das ist **kein Bug**, sondern Absicht.

Für Cron-Jobs ist das korrekt - diese müssen manuell als richtiger User eingerichtet werden.

## Aktuelle Cron-Jobs (Stand: 2026-04-18 23:00)

### 8 Aktive Agents (alle als root):
| Cron-Job | Intervall | Datei | Zweck | Status |
|----------|-----------|-------|-------|--------|
| openclaw-maintenance | @reboot, */20 | openclaw-maintenance.cron | Gateway-Redundanz | ✅ Aktiv |
| db-maintainer | */30 | db-maintainer.cron | DB-Wartung | ✅ Aktiv |
| log-collector | 0 */3 | log-collector.cron | Log-Sammlung | ✅ Aktiv |
| abstractions-manager | 0 */6 | abstractions-manager.cron | Script-Portierungen | ✅ Aktiv |
| clawhub-git-sync | 0 * | clawhub-git-sync.cron | Git-Sync | ✅ Aktiv |
| reports-creator | 0 6, 0 8 So | reports-creator.cron | Tägliche/Wöchentliche Reports | ✅ Aktiv |
| channel-status | 0 9,21, Mo 9 | channel-status.cron | Status-Updates 2x täglich | ✅ Aktiv |
| node-health | */45 | node-health.cron | Node-Monitoring alle 45min | ✅ Aktiv |

### OpenClaw interne Cron-Jobs mit Fehlern:
- `light-system-check` - Timeout nach 60s ❌
- `daily-system-health` - 16h her, Fehler ❌
- `daily-security-check` - 14h her, Fehler ❌

**Hinweis:** Crontab-Duplikate wurden erfolgreich bereinigt.

## Schritt-für-Schritt Anleitung

### 1. Als User openclaw anmelden

```bash
# Wechsel zu openclaw
su openclaw

# ODER falls schon als root:
su - openclaw
```

### 2. Crontab installieren

```bash
# Variante A: Direkte Installation
crontab /home/openclaw/.openclaw/workspace/crons/db-maintainer.cron

# Variante B: Manuelle Bearbeitung
crontab -e
# Dann die Zeile einfügen:
# */30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maitainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1
```

### 3. Verifizierung (als openclaw)

```bash
# Zeige aktive Cron-Jobs
crontab -l

# Ergebnis sollte sein:
# */30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maintainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1
```

### 4. Test (warten auf :00 oder :30)

```bash
# In anderem Terminal folgen:
tail -f /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log
```

## Fehler vermeiden

| ❌ FALSCH | ✅ RICHTIG |
|-----------|------------|
| `sudo crontab -e` | `su openclaw` dann `crontab -e` |
| `crontab -e` als root | Crontab als openclaw |
| Pfad mit `~` | Voller Pfad `/home/openclaw/...` |

## Überprüfung nach 30 Minuten

```bash
# Prüfe ob Log geschrieben wurde
ls -la /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log

# Zeige letzte Einträge
tail /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log
```

## Warum das so ist

1. **Sicherheit**: Exec-Blockierung verhindert versehentliche Systemänderungen
2. **Kontrolle**: User muss aktiv Cron-Job bestätigen (opt-in)
3. **Berechtigungen**: Nur openclaw hat Zugriff auf Workspace-Dateien
4. **Multi-Node**: Konfiguration kann pro Node unterschiedlich sein

## Automatisierung auf anderen Nodes

Für Node 2 (Netcup) identisch:
```bash
# Auf Node 2 als openclaw:
scp node1:/home/openclaw/.openclaw/workspace/crons/db-maintainer.cron /tmp/
crontab /tmp/db-maintainer.cron
```

---
**Status**: Bereit zur Aktivierung durch User
