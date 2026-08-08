# Gateway 1 — OpenClaw Workspace

Workspace des ersten OpenClaw AI Gateways im Clusterverbund.
Dieser Branch wird automatisch 2× täglich synchronisiert (`auto: gateway-sync`).

## Worker- und Relay-Nodes

Gateway 1 kann folgende Nodes als Worker/Relay verwenden — je nach
Verfügbarkeit, Erreichbarkeit und Priorität (Tailscale VPN / Fallback WireGuard):

| Node | Kapazität | Typ | Anmerkung |
| --- | --- | --- | --- |
| node2 | medium | Server | Stabil, Fallback |
| node3 | medium | Server | Bedingt verfügbar |
| node5 | low | Redmi Note 11S | Mobile, wenn online |
| node7 | high | Server | Docker, schwere Jobs |
| node4, node6, node8 | — | — | Je nach Konfiguration |

Docker-Container auf den Nodes werden für rechenintensive Jobs verwendet.

## Workspace-Inhalte

| Verzeichnis / Datei | Beschreibung |
| --- | --- |
| `scripts/` | Ausführbare Scripts des Gateways |
| `skills/` | ClawHub Skills (veröffentlichte Abstraktionen) |
| `abstraction-manager/` | Abstraction-Manager-Konfiguration |
| `cron/` | Geplante Aufgaben (Heartbeat, Sync, …) |
| `logs/` | Gateway-Logs |
| `docs/` | Lokale Dokumentation |
| `MEMORY.md` | Persistentes Gateway-Gedächtnis |
| `SOUL.md` | Gateway-Identität und Verhalten |
| `AGENTS.md` | Konfigurierte Sub-Agents |
| `TOOLS.md` | Verfügbare Tools |
| `SYNC-SYSTEM.md` | Beschreibung der Sync-Mechanik |

## Verfügbare Skills

`cluster-gateway` · `cluster-management` · `coding-agent` · `db-maintainer` ·
`doc-scraper` · `documentation` · `git-publish-agent` · `json-utils` ·
`log-collector` · `mcp-tool-utils` · `model-usage` · `multi-nodes-utils` ·
`relay-node` · `reports-creator` · `resource-manager` ·
`script-abstractions-manager` · `scripting-utils` · `server-maintenance` ·
`sherpa-onnx-tts` · `spotify-player` · `sub-agents-utils` · `tiktok-live-mon` ·
`web-scraper` · `worker-node` · `workspace-db`

## Script-Abstraktionen

→ Branch [`gateway1-abstractions`](../../tree/gateway1-abstractions)
