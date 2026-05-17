# ops-hub Skill

**Name:** ops-hub  
**Beschreibung:** Zentraler Operations- und Steuerungshub für OpenClaw Agenten, Nodes, Tasks und Dokumentation  
**Version:** 1.0.0  
**Emoji:** 🎛️  
**Zuständig:** Main Agent  

---

## 🎯 Zweck

Der ops-hub ist der zentrale Koordinationspunkt für:
- Agenten- und Sub-Agenten-Verwaltung
- Node-Überwachung und -Steuerung
- Task-Delegation und -Koordination
- Zentrale Dokumentationsregistratur
- Redundante Datensicherung
- Cluster Load Balancing
- System-Audits und Reports

---

## 📁 Struktur

```
~/.openclaw/workspace/docs/ops-hub/
├── README.md              # Einstieg und Übersicht
├── ops-hub.md            # Agent Self-Dokumentation
├── audits.md             # Audit-Logs
├── reports.md            # Manuelle Reports (max. 10)
├── cluster-reports.md    # 3h-Übersichten (rollierend)
├── email-integration.md  # E-Mail mit Himalaya
├── registratur.md        # Inhaltsverzeichnis aller Doku
├── system-files.md       # Überwachung kritischer Dateien
├── agent-log.md          # Aktions-Log
├── coordination.md       # Delegations-Übersicht
├── delegation.md         # Delegierte Aufgaben
├── status.md             # Aktueller Systemstatus
├── tasks.md              # Offene/abgeschlossene Tasks
└── .redundancy-index     # Redundanz-Verwaltung
```

**Redundante Kopien** (Root-Level):
- `OPS-HUB-AGENT.md`, `OPS-HUB-AUDITS.md`, `OPS-HUB-REPORTS.md`
- `OPS-HUB-CLUSTER-REPORTS.md`, `OPS-HUB-REGISTRATUR.md`
- `OPS-HUB-EMAIL-INTEGRATION.md`

---

## 🔧 Verwendung

### Als Basis für neue Agenten

```bash
# Einen Sub-Agenten spawnen
cd ~/.openclaw/workspace && openclaw agents spawn --name worker-1 --description "Worker für Task X" --mode detached
```

### Dokumentation aktualisieren

```bash
# Neue Einträge hinzufügen
cd ~/.openclaw/workspace/docs/ops-hub/

echo "$(date '+%Y-%m-%d %H:%M') - Aktion durchgeführt" >> agent-log.md
```

### System-Status prüfen

```bash
# Alle Nodes anzeigen
openclaw nodes list

# Gateway-Status
openclaw gateway status
```

---

## 📊 Automatisierte Tasks

### Heartbeat (täglich)
- Dokumentation prüfen
- Redundanz-Überprüfung
- Cluster-Reports aktualisieren

### 3-Stunden-Reports
- Cluster-Status aus Main Channel einlesen
- Rollierend max. 10 Einträge halten
- Ältere Einträge archivieren

### Wöchentlich
- Audit-Review durchführen
- Backup-Integrität prüfen

---

## 📋 Konventionen

### Dokumentations-Standards

| Typ | Naming | Speicherort |
|-----|--------|-------------|
| Reports | `REPORT-YYYY-MM-DD-TITEL.md` | `/workspace/reports/` |
| Lessons | `LESSONS-LEARNED-YYYY-MM-DD.md` | `/workspace/reports/` |
| Daily | `memory/YYYY-MM-DD.md` | `/workspace/memory/` |

### Redundanz-Prinzip

1. **Primär:** `docs/ops-hub/{dokument}.md`
2. **Sekundär:** `OPS-HUB-{DOKUMENT}.md` (Root-Level)
3. Bei Änderungen: BEIDE Dateien synchronisieren!

---

## 🔄 Integration mit anderen Skills

| Skill | Integration | Nutzung |
|-------|-------------|---------|
| himalaya-email | E-Mail-Überwachung | Alerts, Verifizierungs-Codes |
| healthcheck | Sicherheitsaudits | System-Härtung, Updates |
| github | Issue-Tracking | PR-Reviews, Bug-Reports |
| taskflow | Task-Verwaltung | Workflows, Delegationen |

---

## 🆘 Troubleshooting

### Dokumentation nicht gefunden
```bash
# Primäre Quelle
cat ~/.openclaw/workspace/docs/ops-hub/README.md

# Sekundäre Quelle (Root-Level)
cat ~/OPS-HUB-AGENT.md
```

### Redundanz-Check fehlgeschlagen
```bash
# .redundancy-index prüfen
cat ~/.openclaw/workspace/docs/ops-hub/.redundancy-index

# Fehlende Dateien identifizieren
ls -la OPS-HUB-*.md
```

### Gateway nicht erreichbar
```bash
openclaw gateway status
```

---

## 📚 Referenzen

- [Primäre Doku](../../workspace/docs/ops-hub/README.md)
- [Agent Self-Doku](../../workspace/docs/ops-hub/ops-hub.md)
- [Registratur](../../workspace/docs/ops-hub/registratur.md)
- [HIMALAYA-GUIDE](../../workspace/HIMALAYA-GUIDE.md)

---

**Erstellt:** 2026-04-17  
**Letzte Aktualisierung:** 2026-04-17 05:27 CET
