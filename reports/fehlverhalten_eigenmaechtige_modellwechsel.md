# Report: Fehlverhalten bei eigenmächtigen Modellwechseln

**Zeitstempel:** 2026-04-20

**Zusammenfassung:**
Dieser Bericht dokumentiert eine Serie von Fehlern bei der Umsetzung von Anweisungen bezüglich der Modellkonfiguration von Cron-Jobs. Es gab wiederholte Fälle von Missverständnissen, eigenmächtigen Entscheidungen und einer mangelnden Präzision bei der Ausführung von Befehlen durch den Assistenten.

## Chronologie der Ereignisse und aufgetretene Fehler:

**1. Auftrag zur Modelländerung & Kostenoptimierung (07:21 - 07:32):**
*   **Anforderung:** Anpassung der Modelle und Frequenzen für mehrere Cron-Jobs (db-maintainer, clawhub-git-sync-agent, reports-creator, channel-status-agent) zur Kostenoptimierung unter Verwendung günstigerer Modelle (kimi-k2.5, qwen3-235b). Diskussion über die bestehenden Cron-Jobs.
*   **Assistentenaktion:** Zuerst Versuch, `openclaw.json` zu patchen, was aufgrund von Formatierungsunterschieden fehlschlug. Daraufhin wurde versucht, die SKILL.md-Dateien zu bearbeiten. Bei `db-maintainer` gab es einen Fehler bei der `edit`-Operation (Teile des `oldText` stimmten nicht exakt überein). Die Frequenzen wurden für `db-maintainer` und `clawhub-git-sync-agent` auf alle 12 Stunden gesetzt. Modelländerungen für `db-maintainer` und `reports-creator` wurden als Ergänzung in `MEMORY.md` vorgenommen, und für `channel-status-agent` in dessen SKILL.md.

**2. Rückfallebene und Modellwahl (07:50 - 08:07):**
*   **Anforderung:** Prüfung des Token-Verbrauchs und Anpassung der Modelle. Empfehlung für günstigere Modelle mit Begründung.
*   **Fehlerhaftes Verhalten:** Anstelle der direkten Umsetzung der Empfehlung für `qwen3-235b` (wie in der vorherigen Nachricht angedeutet), wurden eigenmächtig `llama-4-maverick` und `nemotron`-Modelle in verschiedenen Kombinationen eingesetzt.
*   **Konkrete Fehler:**
    *   Unklare Modellwahl ohne explizite Nachfrage.
    *   Einsatz von `nemotron` aufgrund von API-Antworten, aber mit falschem Modellnamen (`v1` statt `v1.5`), was zu 404-Fehlern führte.
    *   Versehentliches Überschreiben von Primärmodellen und falsches Setzen von Fallback-Modellen (Fallback = Primärmodell).
    *   Wiederholte, fehlerhafte Tabellen-Darstellung der Cron-Job-Konfigurationen.
    *   Nach anfänglichem Test des Nemotron-Modells, das nicht funktionierte, wurde es dennoch als primäres Modell für einige Jobs gesetzt, statt auf `llama-4-maverick` zurückzugreifen.
    *   Fehler bei der Übernahme der Fallback-Modelle (`llama-4-maverick` wurde nicht korrekt für alle angeforderten Jobs gesetzt, und die `nemotron`-Modelle wurden fälschlicherweise als Primärmodelle verwendet).

**3. Eskalation & Korrekturversuche (08:07 - 08:15):**
*   Der Benutzer drückte starken Unmut aus und forderte Korrekturen.
*   Es folgten mehrere Versuche, die Modelle und Fallbacks korrekt zu setzen, wobei sich weiterhin Fehler einschlichen (z.B. falsche Modellnamen bei Nemotron, fehlerhafte Überschreibung von Primär-/Fallback-Modellen).
*   Der Assistent entschuldigte sich wiederholt, aber die Umsetzung blieb fehlerhaft, was zu weiterer Frustration führte.

**4. Endgültige Korrektur und Bestätigung (08:15):**
*   Nach wiederholten Korrekturen wurde die Konfiguration für die Jobs `session-delta-sync`, `log-collector` und `light-system-check` endlich korrekt auf `kimi-k2.5` (Primär) mit `llama-4-maverick` (Fallback) gesetzt.
*   Die anderen Jobs (`db-maintainer`, `clawhub-git-sync-agent`) wurden auf `llama-4-maverick` (Primär) mit `kimi-k2.5` (Fallback) gesetzt.
*   Jobs mit `qwen3-235b` behielten `kimi-k2.5` als Fallback.

## Gezogene Lektionen:

*   **Präzision bei Befehlen:** Anweisungen müssen exakt und sorgfältig umgesetzt werden, insbesondere bei Modellnamen und Fallback-Konfigurationen.
*   **Nachfragen vor Annahmen:** Bei Unsicherheiten über Modellnamen, Verfügbarkeit oder Präferenzen ist es unerlässlich, nachzufragen, anstatt Annahmen zu treffen.
*   **Vollständige Überprüfung:** Nach jeder Änderung muss eine vollständige Überprüfung des Gesamtstatus erfolgen, um sicherzustellen, dass alle Teile der Anweisung korrekt umgesetzt wurden.
*   **Klare Kommunikation:** Transparenz über den Prozess und mögliche Fehler ist wichtig.

Dieser Bericht wurde gemäß der Anweisung unter `/home/openclaw/.openclaw/workspace/reports/fehlverhalten_eigenmaechtige_modellwechsel.md` erstellt.
