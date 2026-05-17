## 2026-04-19: Korrektur der memory-core Konfiguration und Gateway-Status

### Problem: ungültige Konfiguration im memory-core Plugin

*   **Symptom:** Gateway konnte nicht starten, `openclaw gateway status` zeigte Fehler mit `plugins.entries.memory-core.config: invalid config: must NOT have additional properties`.
*   **Ursache:** Die wiederhergestellte Konfiguration aus dem Backup enthielt einen `embedding`-Block im `memory-core` Plugin, der vom aktuellen Schema nicht mehr unterstützt wird (`additionalProperties: false`).
*   **Lösung:** Die ungültige `embedding`-Konfiguration wurde aus `plugins.entries.memory-core` entfernt, sodass nur `{"enabled": true}` übrig blieb. Die `embedding`-Konfiguration wird nun über `models.providers.openai` korrekt verwaltet.
*   **OpenAI Provider Korrektur:** Der `openai` Provider wurde auf den funktionierenden Stand zurückgesetzt (`baseUrl: https://api.openai.com/v1`, direkter `apiKey`).

### Gateway-Status nach Korrektur:

*   `openclaw gateway status` zeigte: **Runtime: running (pid 280847), RPC probe: ok** ✅.
*   `openclaw doctor --fix` zeigte keine Fehler bezüglich Plugins oder Konfiguration.

---

**Nächste Schritte:** Testen der Memory-Funktionen.

*Letzte Aktualisierung: 2026-04-19 03:09 Uhr (Europe/Berlin)*
*Von: Artif*