# ops-hub — Zentraler Operations- und Steuerungshub

> **Persistent ID:** `subagent:b5c59527-2f60-4b...` | **Kommunikation:** webchat-gebunden

Dieses Verzeichnis enthält alle Dokumentationen, Logs und Steuerungsprotokolle des zentralen Agenten `ops-hub`.

## 🎯 Zweck

- Zentrale Steuerung aller Agenten, Sub-Agenten, Nodes und Tasks
- Auswertung von Reports (z. B. 3-Stunden-Node-Report)
- Manuelle Befehlsausführung
- Start, Konfiguration und Überwachung weiterer Agenten
- Delegation und Koordination von Jobs, Tasks, Skripten, Gateway Cronjobs und Sessions
- Cluster Load Balancing zwischen Nodes
- Zentrale Dokumentationsregistratur (`.md`) und Nutzung der neuen SQL-Datenbanken `docs.db` und `tree.db`.
- Redundante Sicherung von Arbeitsfortschritten in Versionsverläufen
- E-Mail-Integration mit Himalaya

## 📁 Struktur

| Datei | Inhalt |
|-------|--------|
| `agent-log.md` | Chronologische Aufzeichnung aller durchgeführten Aktionen |
| `tasks.md` | Offene und abgeschlossene Tasks |
| `coordination.md` | Delegationen, Zuständigkeiten, Abhängigkeiten |
| `delegation.md` | Übersicht über delegierte Aufgaben und deren Status |
| `status.md` | Aktueller Betriebs- und Verbindungsstatus |
| `ops-hub.md` | Agent Self-Dokumentation (Aufgaben/Ziele) |
| `audits.md` | Audit-Log und Sicherheitsprüfungen |
| `reports.md` | Übersicht aller Reports (letzte 10 manuelle Reports) |
| `cluster-reports.md` | 3-Stunden Übersichten aus Main Channel (rollierend) |
| `email-integration.md` | E-Mail-Integration mit Himalaya |
| `registratur.md` | Vollständiges Inhaltsverzeichnis aller Dokumentationen |
| `system-files.md` | Überwachung kritischer Systemdateien |

## 🔄 Redundanz

Alle kritischen Dokumentationen existieren redundant:
- **Primär:** `docs/ops-hub/*.md`
- **Sekundär (Root-Level):** `OPS-HUB-*.md`

| Primär (docs/ops-hub/) | Sekundär (Root) |
|------------------------|-----------------|
| `ops-hub.md` | `OPS-HUB-AGENT.md` |
| `audits.md` | `OPS-HUB-AUDITS.md` |
| `reports.md` | `OPS-HUB-REPORTS.md` |
| `cluster-reports.md` | `OPS-HUB-CLUSTER-REPORTS.md` |
| `registratur.md` | `OPS-HUB-REGISTRATUR.md` |

## 🔗 Infrastruktur-Referenzen

- **Zentrale Infrastrukturdokumentation:** `/home/openclaw/.openclaw/workspace/INFRASTRUCTURE.md`
  - Enthält: VPN-Tunnel, SSH-Keys, WireGuard, Tailscale, Node-Konfigurationen
  - Konsolidiert am: 2026-04-18
  - Symlinks in: `nodes/`, `hardware/`, `cluster/`

## 📧 Skills

| Skill | Zweck | Status |
|-------|-------|--------|
| `himalaya-email` | E-Mail-Verwaltung via IMAP/SMTP | ✅ Aktiv |
| `healthcheck` | Sicherheitsaudit | ✅ Verfügbar |
| `github` | GitHub-Integration | ✅ Verfügbar |

## 🔐 Zugriff

- **Primärkanal:** `webchat`
- **Erlaubte Befehle:** Alle Tools (read, write, exec, nodes, web_search, memory_search, message, etc.)
- **SSH-Zugriff:** read/write über `ssh user@node docs/ops-hub/`
- **Gateway-intern:** Vollzugriff auf Workspace und System
- **Ziel:** Point of Contact für alle Systeme, Agenten, Jobs

## 🎛️ Für Agenten: Skill-Nutzung

### Wichtig vor der Arbeit:
1. **Skill-Index lesen:** `~/.openclaw/SKILL-INDEX.md`
2. **Diese README lesen:** `docs/ops-hub/README.md`
3. **Arbeitsfortschritt melden:** In `docs/ops-hub/agent-log.md`

### Problem: "Ich kenne ops-hub nicht"
→ Skill-Index prüfen: `cat ~/.openclaw/SKILL-INDEX.md`
→ Skill-Doku lesen: `~/.openclaw/skills/ops-hub/SKILL.md`
→ **NICHT** wild Verzeichnisse erstellen!

## 📚 Weitere Dokumentationen

- [HIMALAYA-GUIDE.md](../HIMALAYA-GUIDE.md) - Verwendungsanleitung für E-Mail
- [Skill: himalaya-email](../../.openclaw/skills/himalaya/SKILL.md)
- [Skill: ops-hub](../../.openclaw/skills/ops-hub/SKILL.md)

*Letzte Aktualisierung: 2026-04-17 06:05 CET*

---

## Ops-Hub Agenten-Details

### Agentenname
- **Name des Agenten**: ops-hub

### Kommunikationskanäle
- **Webchat**: cluster
- **Slack**: DM zu OpenClaw App und Slack-Kanal #workspace
- **IRC**: offen

### Aufgaben
1. **Dokumentationsmanagement**: Pflege und Versionierung der internen Dokumentation.
2. **Systemübersicht und -kontrolle**: Überwachung des Node-Status und Koordination von Sub-Agenten.
3. **Audits und Reports**: Durchführung von Sicherheitsprüfungen und Archivierung von Reports.

### Zugriffsrechte
- Zugriff auf die Umgebungsvariablen und die `.env`-Datei (alle Keys/Tokens).

### Workspace
- **Pfad**: `/home/openclaw/.openclaw/workspace/ops-hub/`
  - Enthält: `AGENT.md`, `INSTRUCTIONS.md`, `KNOWLEDGE.md`, `SKILLS.md`

### Modell
- **Modell**: kimi-k2.5 

### Dokumentation
- Verzeichnis: `/home/openclaw/.openclaw/workspace/docs/ops-hub/` (darf nicht überschrieben oder gelöscht werden, muss weitergeführt werden!)
