# Hersteller-Bugreport: Approval-Regression nach nicht abgestimmter Befehlsänderung

**Datum:** 2026-07-11  
**Komponente:** OpenClaw Skill-Ausführung / Exec-Allowlist  
**Status:** Bestätigt; lokale Rückstellung durchgeführt

## Kurzbeschreibung

Der TikTok-LIVE-Skill wurde von dem bestehenden, freigegebenen Dispatcher-Aufruf mit `--json` auf einen neuen Aufruf mit `--response` geändert. Die zugehörige enge Exec-Allowlist erlaubte weiterhin ausschließlich `--json`. Da die Exec-Konfiguration bei einem Allowlist-Miss eine Rückfrage verlangt, erschien beim nächsten normalen `/tiktok_live`-Aufruf unerwartet erneut eine Approval-Anfrage.

## Beleg

- Ausgeführter Befehl am 2026-07-11 um 18:28:05 MESZ:
  `python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @jazzlegrande_ --response`
- Unmittelbar danach protokolliert:
  `exec.approval.waitDecision`
- Bestehende freigegebene Argumentform:
  `^/home/openclaw/\.openclaw/workspace/tiktok-monitor/tiktok_dispatch\.py url @?[A-Za-z0-9._]{1,24} --json$`
- Globale Exec-Einstellung: `security: allowlist`, `ask: on-miss`

## Ursache

Die Änderung des Skill-Befehls und die bestehende Freigaberegel wurden nicht als gemeinsame Schnittstelle behandelt. Der neue Parameter `--response` war technisch implementiert, aber nicht Bestandteil der vorhandenen Freigabe. Die Approval-Anfrage war deshalb das erwartbare Ergebnis des Allowlist-Misses, jedoch eine durch die Änderung verursachte Regression im Benutzerablauf.

## Rückstellung

Der Skill verwendet wieder den zuvor freigegebenen Aufruf:

```text
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @name --json
```

Es wurde ausdrücklich keine weitere Allowlist- oder Approval-Regel ergänzt. Ebenso wurden keine Einstellungen oder Regeln für andere Server, Nodes oder Verbindungen angelegt oder verändert.

## Erwartung an den Hersteller

1. Änderungen an Skill-Befehlen müssen gegen die tatsächlich aktive Exec-Allowlist geprüft werden.
2. Tests müssen sicherstellen, dass ein zuvor genehmigungsfreier Standardablauf nach Änderungen genehmigungsfrei bleibt.
3. Ein Skill-Validator sollte melden, wenn ein dokumentierter kanonischer Befehl nicht auf eine vorhandene enge Freigaberegel passt.
4. Befehlsänderungen dürfen niemals automatisch neue oder breitere Server-, Node- oder Exec-Freigaben erzeugen.

## Reproduktion

1. Exec auf `allowlist` und `ask: on-miss` konfigurieren.
2. Nur die `--json`-Argumentform freigeben.
3. Den Skill auf denselben Befehl mit `--response` ändern.
4. `/tiktok_live @name` ausführen.
5. Ergebnis: unerwartete Approval-Anfrage.

## Datenschutz

Dieser Report enthält keine signierte Stream-URL, Zugangsdaten oder Tokens.
