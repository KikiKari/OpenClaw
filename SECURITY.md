# Security Policy — OpenClaw Cluster

## Geltungsbereich

Diese Richtlinie gilt für alle Branches dieses Repositories und
insbesondere für die Script-Verarbeitungs-Pipeline des Abstraction Managers.

## Implementierte Sicherheitsmaßnahmen

### Eingabevalidierung (`validators.py`)

- **Path-Traversal-Schutz:** `Path.resolve()` + Allowlist für Quellverzeichnisse
- **Shell-Injection-Prävention:** Allowlist-basierte Zeichenprüfung für Task-Beschreibungen
- **Modell-Allowlist:** Nur explizit freigegebene KI-Modell-Namen werden akzeptiert
- **Timeout-Grenzen:** Eingaben werden auf erlaubte Wertebereiche geprüft

### Prozess-Spawning (`spawn_agent.py`)

- `subprocess.run()` wird ausschließlich mit Argument-Liste aufgerufen (`shell=False`)
- Kein Shell-Interpreter in der Prozesskette — keine Shell-Injection möglich

### Fehlerbehandlung (`exceptions.py`)

- Anwendungsspezifische Exceptions verhindern Info-Leakage bei Crashes
- Sensible Werte werden in Exception-Messages nicht eingebettet

### Logging (`logger.py`)

- Strukturiertes JSON-Logging in Produktion
- API-Schlüssel und Secrets dürfen nicht in Logfiles erscheinen
- Rotierende Log-Dateien (max. 10 MB, 7 Backups)

### API-Schlüssel

- Ausschließlich über Umgebungsvariablen (`.env`), nie hartcodiert
- Validierung auf Vorhandensein und Mindestlänge beim Start

## Bekannte Findings (Stand: 2026-05-26)

Vollständige Analyse in `CODE_REVIEW_FULL.md` (Branch `gateway2`):

| ID | Schwachstelle | Kritikalität | Status |
| --- | -------------- | -------------- | ------ |
| S1 | Shell-Injection via `--task` | KRITISCH | ✅ Behoben in `spawn_agent.py` |
| S2 | Path-Traversal via `--source` | KRITISCH | ✅ Behoben in `validators.py` |
| S3 | Unkontrollierter `--model`-Parameter | HOCH | ✅ Behoben in `validators.py` |
| S4 | Cron-Log world-readable | HOCH | ⚠️ Offen — `chmod 640` + logrotate |
| S5 | API-Schlüssel-Management | HOCH | ✅ Behoben via `.env` |
| S6 | Fehlende Timeout-Limits | MITTEL | ✅ Behoben in `validators.py` |
| S7 | Git-Commits ohne GPG-Signierung | MITTEL | ⚠️ Offen |

## Sicherheitslücken melden

Sicherheitsprobleme bitte ausschließlich über
[GitHub Security Advisories](../../security/advisories/new) melden —
nicht als öffentliches Issue.
