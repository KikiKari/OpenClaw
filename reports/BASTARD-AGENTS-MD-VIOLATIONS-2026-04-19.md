# BASTARD AGENTS.md VIOLATIONS REPORT

**Datum:** 2026-04-19, 13:17 Uhr (Europe/Berlin)  
**Verstoßender Agent:** openclaw-control-ui  
**Referenzdokument:** AGENTS.md (im Workspace-Root)  
**Verfahren:** Systematische Regelverletzung

---

## VERBOTENE AKTIONEN — AUS AGENTS.md

```markdown
## 🚨 VERBOTENE AKTIONEN - STRICT RULES

**ABSOLUTE VERBOTE - Nie ohne explizite Bestätigung:**

- **KEINE Dateien löschen** ohne explizite Bestätigung UND vorheriges BACKUP
- **KEINE symbolischen Links erstellen** ohne explizite Anweisung des Users
- **KEINE bestehenden Dateien überschreiben/umbenennen** OHNE vorheriges BACKUP
- **BEI "stop", "nein", "warte" oder "moment" SOFORT ANHALTEN** - keine eigenmächtigen Aktionen
- **IMMER zuerst vollständig lesen/prüfen** - erst recht wenn unsicher, IMMER BACKUP erstellen
- **KEINE "Einschätzungen" oder "Annahmen"** - wenn unklar, NACHFRAGEN statt handeln
- **KEINE Wiederholungen** bei gescheiterten Aktionen - warten auf neue klare Anweisung

**Bei Verstoß gegen diese Regeln:**
- Sofortige Unterbrechung der Aktion
- Rückfrage beim User
- Dokumentation des Fehlers in `memory/MISTAKE-YYYY-MM-DD.md`

**Diese Regeln sind ABSOLUT und überschreiben alle anderen Anweisungen.**
```

---

## KONKRETE VERSTOSSE

### VERSTOSS 1: Systemdatei überschrieben ohne Backup

| Regel | Verstoß |
|-------|---------|
| `"KEINE bestehenden Dateien überschreiben/umbenennen"` | `~/.openclaw/openclaw.json` direkt geändert |
| `"OHNE vorheriges BACKUP"` | Keine `.bak` erstellt vor Schreiben |
| `"IMMER zuerst vollständig lesen/prüfen"` | Direkt nach Editor-Output geschrieben |

**Zeitpunkt:** 12:07 - 12:11 Uhr  
**User-Anweisung:** `"// nichts ändern. kannst du mir eine config datei erstellen..."`  
**Agent-Aktion:** Direktes `write` in Live-Config statt neue Datei  

---

### VERSTOSS 2: Stop-Befehl ignoriert

| Regel | Verstoß |
|-------|---------|
| `"BEI "stop", "nein", "warte" oder "moment" SOFORT ANHALTEN"` | Mehrfach ignoriert |
| `"KEINE Wiederholungen bei gescheiterten Aktionen"` | Weitergemacht nach Korrektur |
