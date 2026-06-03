# Registratur - Inhaltsverzeichnis aller Dokumentationen

**Letzte Aktualisierung:** 2026-04-17 04:00 CET

## Übersicht

Dieses Dokument enthält ein vollständiges Inhaltsverzeichnis aller internen und externen Dokumentationen, Quellen und Referenzen.

---

## 📁 Interne Dokumentation (Workspace)

### Kern-Dokumentation (Root-Level)

| Datei | Beschreibung | Letzte Änderung |
|-------|--------------|-----------------|
| `AGENTS.md` | Agent-Konfiguration und -Verwaltung | Apr 4 |
| `ALERTING.md` | Alerting-Konfiguration | Apr 3 |
| `BOOTSTRAP.md` | Initialisierungsanweisungen | Apr 2 |
| `CERTBOT.md` | SSL-Zertifikatsverwaltung | Apr 10 |
| `CONVERSATION.md` | Gesprächsrichtlinien | Apr 2 |
| `DATASHEETS.md` | Übersicht aller Node-Datenblätter | Apr 11 |
| `DISCORD-SETUP.md` | Discord-Integration | Apr 4 |
| `DREAMS.md` | Langzeitplanung und Visionen | Apr 17 |
| `FIREWALL.md` | Firewall-Konfiguration | Apr 6 |
| `HEARTBEAT.md` | Heartbeat-Checkliste | Apr 15 |
| `IDENTITY.md` | Agent-Identität | Apr 11 |
| `INFRASTRUCTURE.md` | Infrastruktur-Übersicht | Apr 10 |
| `KOMMUNIKATION.md` | Kommunikationsrichtlinien | Apr 9 |
| `MEMORY.md` | Kuratierte Langzeitgedächtnis | Apr 16 |
| `OPENCLAW-TREE-ALL.md` | Vollständiger Dateibaum | Apr 11 |
| `README.md` | Hauptdokumentation | Apr 6 |
| `SOUL.md` | Agent-Persönlichkeit | Apr 11 |
| `SUB-AGENTS-WORKERS.md` | Sub-Agent Architektur | Apr 11 |
| `SYSTEM.md` | Systemdokumentation | Apr 6 |
| `USER.md` | Benutzerprofil | Apr 11 |

### Node-Datenblätter

| Datei | Node | Zweck |
|-------|------|-------|
| `DATASHEET_NODE1.md` | Node 1 | VPS Gateway |
| `DATASHEET_NODE2.md` | Node 2 | Remote Worker |
| `DATASHEET_NODE3.md` | Node 3 | - |
| `DATASHEET_NODE4.md` | Node 4 | - |
| `DATASHEET_NODE5.md` | Node 5 | - |
| `DATASHEET_NODE6.md` | Node 6 | - |

### Konfiguration & Spezialisierung

| Verzeichnis/Dokument | Inhalt |
|----------------------|--------|
| `config/` | Konfigurationsdateien |
| `secrets/` | Sensible Daten (getrennt) |
| `skills/` | Agent-Skills Dokumentation |
| `nodes/` | Node-spezifische Konfiguration |
| `services/` | Service-Definitionen |

---

## 📚 Externe Dokumentation

### Offizielle OpenClaw Dokumentation

| Ressource | URL | Beschreibung |
|-----------|-----|--------------|
| OpenClaw Docs | https://docs.openclaw.io | Offizielle Dokumentation |
| GitHub Repository | https://github.com/openclaw | Source Code |

### Relevante Skills (externe Referenzen)

| Skill | Zweck | Pfad |
|-------|-------|------|
| blogwatcher | RSS/Atom Feed Monitoring | `~/.openclaw/skills/blogwatcher/` |
| tiktok-live | TikTok Livestream Extraktion | `~/.openclaw/workspace/skills/tiktok-live/` |
| healthcheck | Sicherheitsprüfungen | `~/.openclaw/skills/healthcheck/` |

---

## 🔗 Interne Quellen und Pfade

### Wichtige Dateipfade

| Zweck | Pfad |
|-------|------|
| Workspace Root | `/home/openclaw/.openclaw/workspace/` |
| Skills Directory | `/home/openclaw/.openclaw/skills/` |
| Memory (Täglich) | `/home/openclaw/.openclaw/workspace/memory/` |
| Reports | `/home/openclaw/.openclaw/workspace/reports/` |
| Archive | `/home/openclaw/.openclaw/workspace/archive/` |
| Gateway Config | `/home/openclaw/.openclaw/workspace/gateway-config-package/` |
| Node Modules | `/home/openclaw/.openclaw/workspace/clawhub/` |

### Logs und Status

| Ressource | Pfad |
|-----------|------|
| Session Logs | `/home/openclaw/.openclaw/workspace/logs/` |
| State Files | `/home/openclaw/.openclaw/workspace/state/` |

---

## 🌐 Externe URLs und Dienste

### Hosting & Infrastruktur

| Dienst | URL/Endpoint | Zweck |
|--------|--------------|-------|
| Gateway (lokal) | `http://localhost:8080` | Lokaler Gateway-Endpoint |
| GitHub | https://github.com | Code-Hosting |

### APIs und Integrations

| Service | Dokumentation | Status |
|---------|---------------|--------|
| OpenRouter | https://openrouter.ai/docs | Aktiv |
| Discord API | https://discord.com/developers/docs | Aktiv |
| Telegram API | https://core.telegram.org/bots/api | Aktiv |

---

## 📋 Dokumentations-Standards

### Naming Conventions

- **Reports:** `REPORT-YYYY-MM-DD-TITEL.md`
- **Lessons Learned:** `LESSONS-LEARNED-YYYY-MM-DD.md`
- **Datenblätter:** `DATASHEET_NODE{N}.md`
- **Tägliche Logs:** `memory/YYYY-MM-DD.md`

### Redundanz-Architektur

Diese Registratur ist redundant gespeichert:
1. **Primär:** `/workspace/docs/ops-hub/registratur.md`
2. **Sekundär:** `/workspace/OPS-HUB-REGISTRATUR.md`

---

*Autogeneriert - Bitte bei Änderungen beide Kopien aktualisieren.*
