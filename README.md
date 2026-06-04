# OpenClaw Cluster

Dieses Repository enthält die synchronisierten Workspaces der OpenClaw AI Gateways
(openclaw.ai). Die Gateways arbeiten als KI/AI-Gateways im Clusterverbund innerhalb
einer bestehenden Netzwerkinfrastruktur. Verbundene OpenClaw Nodes werden über interne
Systemmechanik und nginx Load-Balancer als Worker- und Relay-Nodes eingesetzt.

## Repository-Struktur

| Branch | Beschreibung |
| ------ | ----------- |
| `main` | Dieses Dokument, Sicherheitsrichtlinie, Issue-Vorlagen |
| `gateway1` | Workspace von Gateway 1 — Skills, Scripts, Agents, Memory, Cron |
| `gateway2` | Workspace von Gateway 2 — Infrastruktur, WireGuard VPN, SSH-Tunnel |
| `gateway1-abstractions` | Script-Abstraktionen von Gateway 1 (automatisch synchronisiert) |
| `gateway2-abstractions` | Script-Abstraktionen von Gateway 2 (automatisch synchronisiert) |

## Netzwerk-Topologie

```text
                        INTERNET
                            │
           ┌────────────────┴────────────────┐
           │                                 │
       Gateway 1                         Gateway 2
           │                                 │
           └──────────┬──────────────────────┘
                      │  Tailscale VPN (Fallback: WireGuard)
          ┌───────────┼───────────────────────┐
          │           │                       │
       Node 2      Node 3–6             Node 7–8
    (Worker/Relay) (Worker/Relay)     (Worker/Relay)
          │
   [Docker Container]
   für schwere Jobs
```

Beide Gateways können **Nodes 2–8** als Worker- oder Relay-Nodes verwenden —
je nach aktueller Erreichbarkeit, Verfügbarkeit und Priorität.
Auf den Nodes vorbereitete Docker-Container werden für rechenintensive
Jobs, Abstraktionen und andere Aufgaben eingesetzt.

## Abstraction Manager

Jeder Gateway betreibt einen **Abstraction Manager**, der automatisch
Abstraktionen der verwendeten Scripts und Programme erstellt und in die
jeweiligen `*-abstractions`-Branches sowie auf ClawHub (Skills) veröffentlicht.

## ClawHub — Veröffentlichte Skills

Die Abstraction Manager beider Gateways veröffentlichen Skills automatisch
im öffentlichen OpenClaw Registry auf **[clawhub.ai/@KikiKari](https://clawhub.ai/@KikiKari)**.

### Installation

```bash
# Skill suchen / Search skills
openclaw skills search "cluster-gateway"

# Skill installieren / Install skill
openclaw skills install <skill-slug>

# Alle Skills aktualisieren / Update all skills
openclaw skills update --all
```

### Veröffentlichte Skills / Published Skills

| Skill | Version | Downloads | Security | Install |
| --- | --- | --- | --- | --- |
| Cluster Gateway | v1.0.0 | 292 | ✅ Pass | `openclaw skills install cluster-gateway` |
| MCP Tool Utils | v1.0.0 | 338 | ✅ Pass | `openclaw skills install mcp-tool-utils` |
| Reports Creator | v1.0.0 | 289 | ✅ Pass | `openclaw skills install reports-creator` |
| Relay Node | v1.0.0 | 298 | ✅ Pass | `openclaw skills install relay-node` |
| JSON Utils | v1.0.0 | 304 | ✅ Pass | `openclaw skills install json-utils` |
| Log Collector | v1.0.0 | 302 | 🔍 Review | `openclaw skills install log-collector` |
| TikTok Live Monitor | v1.0.0 | 288 | 🔍 Review | `openclaw skills install tiktok-live-monitor` |
| Doc Scraper | v1.0.0 | 290 | 🔍 Review | `openclaw skills install doc-scraper` |
| Workspace Database Manager | v1.0.0 | 312 | 🔍 Review | `openclaw skills install workspace-database-manager` |
| Scripting Utils | v1.0.0 | 269 | 🔍 Review | `openclaw skills install scripting-utils` |

> Downloads und Security-Status werden vom Abstraction Manager bei jedem
> Sync aktualisiert. / Downloads and security status are updated by the
> Abstraction Manager on each sync.

## Automatische Synchronisation

| Typ | Zeitpunkte |
| --- | --------- |
| Gateway-Workspace | täglich ~06:15 und ~18:15 Uhr |
| Script-Abstraktionen | täglich ~04:35 und ~13:35 Uhr |
