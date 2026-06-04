# OpenClaw Cluster

Dieses Repository enthält die synchronisierten Workspaces der OpenClaw AI Gateways
(openclaw.ai). Die Gateways arbeiten als KI/AI-Gateways im Clusterverbund innerhalb
einer bestehenden Netzwerkinfrastruktur. Verbundene OpenClaw Nodes werden über interne
Systemmechanik und nginx Load-Balancer als Worker- und Relay-Nodes eingesetzt.

## Repository-Struktur

| Branch | Beschreibung |
|--------|-------------|
| `main` | Dieses Dokument, Sicherheitsrichtlinie, Issue-Vorlagen |
| `gateway1` | Workspace von Gateway 1 — Skills, Scripts, Agents, Memory, Cron |
| `gateway2` | Workspace von Gateway 2 — Infrastruktur, WireGuard VPN, SSH-Tunnel |
| `gateway1-abstractions` | Script-Abstraktionen von Gateway 1 (automatisch synchronisiert) |
| `gateway2-abstractions` | Script-Abstraktionen von Gateway 2 (automatisch synchronisiert) |

## Netzwerk-Topologie

```
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

## Automatische Synchronisation

| Typ | Zeitpunkte |
|-----|-----------|
| Gateway-Workspace | täglich ~06:15 und ~18:15 Uhr |
| Script-Abstraktionen | täglich ~04:35 und ~13:35 Uhr |
