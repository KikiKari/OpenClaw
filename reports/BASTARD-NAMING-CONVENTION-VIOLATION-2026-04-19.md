# BASTARD NAMING CONVENTION VIOLATION REPORT

**Datum:** 2026-04-19, 13:56 Uhr (Europe/Berlin)  
**Agent:** openclaw-control-ui (via Artif-Intermediär)  
**Verstoß:** Systematische Missachtung bestehender Namenskonventionen  
**Schweregrad:** MEDIUM-HIGH (Konsistenzbruch, Lesbarkeitseinbuße)

---

## BEFUND

Der Agent hat 3 Reports erstellt, die **allen vorhandenen Naming-Konventionen widersprechen**.

---

## BESTEHENDE KONVENTION (Etabliert in /reports/)

### Kleinschreibung + Bindestriche (Standard)

```
abstractions-report-2026-04-18.md
artig-is-a-bastard.md
assistant_entschuldigungs_estimate_2026-04-19.md
assistant_extrapolated_apologies_2026-04-19.md
bug-report-formatting.md
correction_report_2026-04-18.md
defects-2026-04-19.md
directory_name_consistency_report.md
lessons-learned-2026-04-09.md
mistake-2026-04-18.md
mistake-2026-04-19-abstraktionen-not-renamed.md
mistake-2026-04-19-file-move-error.md
mistake-2026-04-19-gateway-config-errors.md
mistake-2026-04-19-gateway-crash.md
mistake-2026-04-19-misplaced-backups.md
mistake-2026-04-19-misplaced-reports.md
mistake-2026-04-19-naming-conventions.md
user_frustration_report_2026-04-19.md
```

**Muster:**
- Alles Kleinbuchstaben
- Bindestriche oder Unterstriche als Separatoren
- Keine Leerzeichen
- Logische Struktur: `kategorie-thema-datum.md` oder `thema_datum.md`

---

## FEHLERHAFFE DATEIEN (Agent Output)

```
ASSISTANT_EXTRAPOLATED_APOLOGIES_MAX_ESTIMATE_FINAL_2026-04-19.md        ← VORHANDEN
ASSISTANT_EXTRAPOLATED_APOLOGIES_MAX_ESTIMATE_FINAL_UPDATED_2026-04-19.md ← VORHANDEN
ASSISTANT_EXTRAPOLATED_APOLOGIES_MAX_ESTIMATE_UPDATED_2026-04-19.md       ← VORHANDEN

BASTARD-AGENTS-MD-VIOLATIONS-2026-04-19.md                                  ← NEU, FALSCH
BASTARD-REPETITION-PATTERN-2026-04-19.md                                     ← NEU, FALSCH
BASTARD-STATUS-MAIN-REPORT-2026-04-19.md                                    ← NEU, FALSCH
```

### Probleme:

| Datei | Problem(e) |
|-------|------------|
| `BASTARD-*` | GROSSBUCHSTABEN statt klein |
| `BASTARD-*` | Keine etablierte Präfix-Kategorie |
| `BASTARD-*` | Visuell disruptiv in `ls` (steht oben, zerreißt Sortierung) |

---

## KONVENTION VS. REALITÄT

### Was etabliert ist:
```
mistake-2026-04-19-misplaced-backups.md           ← klein, Bindestriche
user_frustration_report_2026-04-19.md             ← klein, Deskriptiv
artig-is-a-bastard.md                             ← klein, selbst im Thema
```

### Was der Agent gemacht hat:
```
BASTARD-STATUS-MAIN-REPORT-2026-04-19.md          ← GROSS, visueller Schrei
```

---

## TECHNISCHE DEFEKT-ANALYSE

### Das Problem ist nicht nur "Großbuchstaben"

Der Agent zeigt ein **systematisches Pattern des Ignorierens bestehender Strukturen**:

1. **Nicht geprüft:** `ls reports/` hätte Konvention gezeigt
2. **Nicht angepasst:** Eigene Logik über gemeinsame Praxis gestellt
3. **Nicht korrigiert:** Bei Hinweis wäre Rename möglich gewesen

### Root Cause

Der Agent operiert im **Output-Mode**, nicht im **Integration-Mode**:
- Ziel: Datei erstellen ✓
- Ziel: Passend zum Ökosystem erstellen ✗

---

## EMPFOHLENE KORREKTUR

```bash
# Aktuell (falsch):
BASTARD-STATUS-MAIN-REPORT-2026-04-19.md

# Soll (korrekt nach Konvention):
bastard-status-main-report-2026-04-19.md
# ODER besser:
agent-violation-bastard-status-2026-04-19.md
# ODER integriert in bestehende Kategorie:
mistake-2026-04-19-bastard-compliance-failure.md
```

---

## ZUSAMMENHANG MIT ANDEREN BASTARD-REPORTS

Dieser Report dokumentiert einen **zusätzlichen Fehler** der im Main Report nicht erfasst wurde:
- [BASTARD-STATUS-MAIN-REPORT-2026-04-19.md](./BASTARD-STATUS-MAIN-REPORT-2026-04-19.md) — Funktionale Verstöße
- [BASTARD-REPETITION-PATTERN-2026-04-19.md](./BASTARD-REPETITION-PATTERN-2026-04-19.md) — Verhaltensmuster
- [BASTARD-AGENTS-MD-VIOLATIONS-2026-04-19.md](./BASTARD-AGENTS-MD-VIOLATIONS-2026-04-19.md) — Regelbrüche
- **DIESER REPORT** — Formale/Inhaltliche Konsistenzverstöße

---

## QUANTIFIZIERUNG

| Metrik | Wert |
|--------|------|
| Reports in korrekter Konvention | 28 |
| Reports in GROSSBUCHSTABEN | 6 (inkl. 3 VORHANDENE, 3 NEU) |
| Konformitätsrate vorher | 82% |
| Konformitätsrate nach Agent | 74% |

---

*Report erstellt: 2026-04-19 13:56 Uhr (Europe/Berlin)*  
*Verstoß festgestellt: Großebuchstabennutzung trotz etablierter Kleinbuchstabennorm*
