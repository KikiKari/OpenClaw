# 🚨 FEHLER-REPORT — 2026-04-19 Namenskonventionen

## Zusammenfassung

**Datum:** 2026-04-19, 01:47 Uhr (Europe/Berlin)
**Schweregrad:** HOCH — wiederholt gleichen Fehler gemacht
**Betroffener:** User

---

## Fehler 1: Verzeichnisname ABSTRAKTIONEN_REPO

Artif hat das Verzeichnis `ABSTRAKTIONEN_REPO` in GROßBUCHSTABEN erstellt, obwohl **alle anderen Verzeichnisse im Workspace in Kleinbuchstaben** benannt sind.

Zusätzlich erstellt:
- `ABSTRAKTIONEN_LOGS` (Großbuchstaben)
- `ABSTRAKTIONEN-TASK.md` (Großbuchstaben)

**Korrekt wäre gewesen:** `abstraktionen` — wie vom User vorgegeben.

**Status:** User hat Umbenennung in `abstraktionen` angewiesen. Noch umzusetzen.

---

## Fehler 2: Neues Verzeichnis REPORTS statt vorhandenes reports

Beim Erstellen eines Reports hat Artif ein **neues Verzeichnis** `REPORTS` (Großbuchstaben) erstellt, obwohl bereits ein Verzeichnis `reports` (Kleinbuchstaben) existiert und alle bisherigen Reports dort abgelegt sind.

Das ist exakt der gleiche Fehler wie bei ABSTRAKTIONEN_REPO — Großbuchstaben statt Kleinbuchstaben, neues Verzeichnis statt vorhandenes nutzen.

**Korrektur:** Report wurde nach `reports/` verschoben, leeres `REPORTS/` Verzeichnis wurde gelöscht.

---

## Muster des Versagens

1. **Ignorieren bestehender Konventionen:** Artif prüft nicht, welche Namenskonvention im Workspace bereits verwendet wird, bevor neue Verzeichnisse erstellt werden.
2. **Wiederholung des gleichen Fehlers:** Der Fehler mit Großbuchstaben wurde mehrfach gemacht (ABSTRAKTIONEN_REPO, ABSTRAKTIONEN_LOGS, REPORTS).
3. **Keine Prüfung auf bestehende Verzeichnisse:** Vor dem Erstellen eines neuen Verzeichnisses wird nicht geprüft, ob bereits ein gleichnamiges (in anderer Schreibweise) existiert.

---

## Regel für die Zukunft

- **Immer Kleinbuchstaben** für Verzeichnisnamen im Workspace
- **Immer zuerst prüfen** ob ein Verzeichnis bereits existiert (`ls` vor `mkdir`)
- **Bestehende Strukturen respektieren** statt neue zu erfinden

---

*Report erstellt: 2026-04-19 01:47 Uhr (Europe/Berlin)*
*Von: Artif*
