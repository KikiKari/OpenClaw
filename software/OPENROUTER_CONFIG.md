# OpenRouter Konfiguration

**Stand:** 2026-04-06

## Aktivierte Plugins

### Response Healing ✅ AKTIV
- **Status:** Aktiviert seit 2026-04-06
- **Funktion:** Korrigiert automatisch defekte/malformed JSON-Antworten von LLMs
- **Auswirkungen:**
  - JSON-Outputs werden automatisch validiert und repariert
  - Minimale zusätzliche Latenz durch Parsing
  - Bessere Zuverlässigkeit bei API-Responses

### Weitere Plugins
- **Web Search:** Aktiv - Echtzeit-Web-Suche für LLM-Antworten
- **PDF Inputs:** Aktiv - PDF-Inhaltsextraktion

## Wichtige Hinweise für zukünftige Arbeit

### JSON-Handling
Durch Response Healing:
- ✅ Defekte JSON-Responses werden automatisch korrigiert
- ✅ API-Aufrufe sind robuster gegen Formatierungsfehler
- ⚠️ Bei Debug-Ausgaben: Das "Original"-JSON kann vom "reparierten" abweichen

### Latenz
- Response Healing fügt ~10-50ms Latenz hinzu (JSON-Parsing)
- Nicht relevant für normale Chat-Anfragen
- Relevant bei Batch-Processing oder High-Frequency API-Calls

## Modelle & Konfiguration

| Einstellung | Wert |
|-------------|------|
| Provider | OpenRouter |
| Response Healing | ✅ Aktiviert |
| Web Search | ✅ Aktiviert |
| PDF Inputs | ✅ Aktiviert |

---

**Letzte Aktualisierung:** 2026-04-06 - Response Healing aktiviert
