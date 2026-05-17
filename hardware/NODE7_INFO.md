# Node 7 - ARM Worker Node

## Übersicht

Neuer ARM-basierter Worker-Node im Cluster, ersetzt xNetX (Node 3).

## Systeminformationen

- **Hostname:** v2202604104722449961
- **Provider:** Netcup
- **OS:** Debian 13 (Trixie)
- **Architektur:** ARM64
- **Öffentliche IP:** 89.58.15.220
- **Tailscale IP:** 100.104.68.51
- **Docker:** v29.4.0 ✅
- **OpenClaw:** v2026.4.11 (Node.js v22.22.2 via nvm) ✅
- **Tailscale:** v1.96.4 ✅
- **Rolle:** Worker-Node (openclaw node run)

## Verbindung zum Gateway

- **Gateway:** Node 1 (Hetzner) — 100.111.216.40:18789
- **Verbindungsart:** Tailscale (WireGuard-verschlüsselt) über ws://
- **Config:** `gateway.mode: "remote"` mit `gateway.remote.url: "ws://100.111.216.40:18789"`
- **Auth:** Token-basiert
- **Pairing:** ✅ Abgeschlossen (devices approve)
- **Status:** ✅ paired · connected
- **Env-Variable:** `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1` (Tailscale verschlüsselt bereits)

## Benutzer

- **openclaw:** Hauptbenutzer für OpenClaw-Dienste
  - Docker-Gruppe: ✅
  - nvm installiert: ✅ (Node.js v22.22.2)
  - Shell: /sbin/nologin (Systembenutzer, Login via sudo)
  - Sudo: hinzufügen mit `usermod -aG sudo openclaw`
- **root:** Systemadministration

## Services

- **openclaw.service** (`/etc/systemd/system/openclaw.service`)
  - User: openclaw
  - ExecStart: `openclaw node run --host 100.111.216.40 --port 18789`
  - Environment: `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1`
  - Restart: on-failure / RestartSec: 5
  - Status: ✅ active (running)

## Config-Dateien

- **openclaw.json:** `/home/openclaw/.openclaw/openclaw.json`
  - gateway.mode: "remote"
  - gateway.remote.url: "ws://100.111.216.40:18789"
  - gateway.auth: token-basiert

## SSH-Zugang

- Von Node 1: `ssh openclaw@100.104.68.51` (Tailscale)
- Von extern: `ssh root@89.58.15.220` (öffentliche IP)

## Wichtige Erkenntnisse

- `gateway.mode` akzeptiert NUR "local" oder "remote" — NICHT "client" oder "serve"
- `gateway.address` ist ein UNGÜLTIGER Key — stattdessen `gateway.remote.url` verwenden
- `gateway.remote.url` Format: `ws://IP:PORT` oder `wss://IP:PORT`
- Node-Pairing erfolgt über `openclaw devices list` + `openclaw devices approve <requestId>` auf dem Gateway
- `openclaw nodes pending` zeigt KEINE device-pairing requests — `openclaw devices list` verwenden!
- Der Node beendet sich sofort nach "pairing required" — Schleife oder Systemd-Restart nötig während Pairing

## Offene Punkte

- [ ] Let's Encrypt Zertifikat für wss:// Verbindung (nach Rate-Limit-Ablauf)
- [ ] Docker-Container für TikTok-Pipeline einrichten
- [ ] Node umbenennen (openclaw nodes rename)

## Wartung

- Regelmäßige Updates von OpenClaw, Docker und OS
- Monitoring der Systemressourcen (CPU, RAM, Disk, Netzwerk)
