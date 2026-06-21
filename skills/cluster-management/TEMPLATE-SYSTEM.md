# SYSTEM.md Template

**Template for multi-node OpenClaw deployments**

---

## Übersicht

[N]-Node OpenClaw [Cluster/Gateways] Konfiguration

---

## Node 1 (Hauptnode / Gateway)

- **Provider:** [Provider-Name]
- **IP:** [IP-Adresse]
- **Hostname:** [Hostname]
- **OS:** [Ubuntu/CentOS Version]
- **OpenClaw:** Gateway via `openclaw gateway restart`
- **Port:** 18789
- **User:** [openclaw/root]
- **Config:** ~/.openclaw/openclaw.json
- **ENV:** ~/.config/openclaw/env
- **Workspace:** ~/.openclaw/workspace/
- **Skills:** ~/.openclaw/skills/

---

## Node 2 (Relay / Worker)

- **Provider:** [Provider-Name]
- **IP:** [IP-Adresse]
- **Hostname:** [Hostname]
- **OS:** [Ubuntu/CentOS Version]
- **OpenClaw:** [Gateway/Node-Mode]
- **Tunnels:** [Ports]
- **SSH-Key:** [Key-Path]

---

## Node 3+ (Worker / Spezialisiert)

[Kopiere Template für weitere Nodes]

---

## Modell-Konfiguration

- **Primary:** [openrouter/model-name]
- **Fallbacks:** [fallback1], [fallback2], [fallback3]

---

## Aktivierte Skills

[Liste der aktivierten Skills]

---

## Spezialisierte Funktionen

[Playwright, TikTok, etc.]

---

## SSH Keys

- [Key-Path] → [Zweck]

---

## Systemd-Services

| Service | Zweck | Status |
|---------|-------|--------|
| [service-name] | [Beschreibung] | [enabled/disabled] |

---

## Cron-Jobs

| Job | Zeit | Zweck |
|-----|------|-------|
| [job-name] | [schedule] | [Beschreibung] |

---

## Wichtige Dokumente

| Dokument | Pfad |
|----------|------|
| SYSTEM.md | Diese Datei |
| INFRASTRUCTURE.md | ~/workspace/INFRASTRUCTURE.md |
| MEMORY.md | ~/workspace/MEMORY.md |

---

## Quick-Reference

```bash
# Gateway neu starten
openclaw gateway restart

# Alle Nodes Status
openclaw nodes status

# Sub-Agent spawnen
sessions_spawn --agent <type> --task "<description>"

# Auf Node ausführen
# OpenClaw exec tool: host="node", node="<node-id>", command="<command>"
```

---

*Template basierend auf: tools/SYSTEM.md (Master)*
