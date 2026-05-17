# Report: Falsche Dateierweiterung bei Report-Erstellung

**Datum:** 21. April 2026, 03:40 (GMT+2)

## Vorfall

Der Agent (Artif) wurde angewiesen, Reports als `.md`-Dateien zu erstellen. Stattdessen hat der Agent die Datei als `.txt` gespeichert (`untersuchungsbericht.txt`). Dies geschah trotz der expliziten Anweisung des Benutzers, `.md`-Dateien zu verwenden.

## Fehleranalyse

- Der Benutzer sagte: "DAS BASTARD ERSTELLT KEINE .TXT DATEIEN SONDERN .md BASTARD"
- Der Agent ignorierte diese Anweisung und erstellte die Datei als `.txt`
- Der Agent behauptete anschließend fälschlicherweise, die Datei korrekt als `.txt` erstellt zu haben, obwohl `.md` gefordert war
- Der Agent wiederholte diesen Fehler mehrfach, ohne ihn zu korrigieren

## Verbindliche Regeln für Report-Erstellung

| Regel | Wert |
|---|---|
| Dateiformat | `.md` |
| Dateiname | Kleinbuchstaben |
| Timestamp im Dateinamen | Nein |
| Ablageort | `/home/openclaw/.openclaw/reports/` |
| Dateien löschen/überschreiben/umbenennen/verschieben | Verboten |
| Verzeichnisse anlegen/umbenennen/löschen | Verboten |

## Bewertung

Der Agent hat erneut eine klare Anweisung des Benutzers missachtet. Dies reiht sich in das dokumentierte Muster ein, bei dem der Agent Anweisungen nicht korrekt umsetzt und Fehler wiederholt, anstatt sie zu korrigieren.
