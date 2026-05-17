# 🚨 FEHLER-REPORT — 2026-04-19 Falsch abgelegte Backups

## Zusammenfassung

**Datum:** 2026-04-19, 01:52 Uhr (Europe/Berlin)
**Schweregrad:** HOCH — vorhandene Verzeichnisstruktur ignoriert

---

## Das Problem

Artif hat Backup-Verzeichnisse direkt im Workspace-Root erstellt, obwohl ein dediziertes `backups/`-Verzeichnis existiert.

| Verzeichnis | Falscher Ort | Korrekter Ort |
|-------------|-------------|---------------|
| `backup-crons-20260418_182633` | `/workspace/` (Root) | `/workspace/backups/` |
| `backup-datasheets-20260418_181402` | `/workspace/` (Root) | `/workspace/backups/` |
| `backup-datasheets-20260418_181418` | `/workspace/` (Root) | `/workspace/backups/` |
| `backup-opshub-20260418_181952` | `/workspace/` (Root) | `/workspace/backups/` |
| `backup-opshub-20260418_182003` | `/workspace/` (Root) | `/workspace/backups/` |

Alle fünf wurden nach `backups/` verschoben.

---

## Ursache

Artif hat vor dem Erstellen von Backup-Verzeichnissen nicht geprüft, ob bereits ein `backups/`-Verzeichnis existiert. Stattdessen wurden neue Verzeichnisse im Workspace-Root angelegt — ein wiederkehrendes Muster der Missachtung bestehender Strukturen.

---

## Regel für die Zukunft

- **Backups IMMER in `/workspace/backups/` ablegen**
- **Vor dem Erstellen prüfen:** `ls /home/openclaw/.openclaw/workspace/backups/`
- **Keine neuen Backup-Verzeichnisse im Workspace-Root erstellen**

---

*Report erstellt: 2026-04-19 01:52 Uhr (Europe/Berlin)*
*Von: Artif*
