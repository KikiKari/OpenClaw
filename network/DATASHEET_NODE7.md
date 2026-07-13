# DATASHEET_NODE7

## Identifikation

- **Nickname:** Node 7
- **Hostname:** v2202604104722449961
- **Rolle:** Worker Node (OpenClaw Node Prozess läuft direkt auf dem Host, verwaltet durch systemd)
- **Cluster:** Cluster 1 (Hetzner Gateway als Controller)

## Hardware

- **Architektur:** ARM64
- **CPU:** ARM-basiert (Details unbekannt)
- **RAM:** [Unbekannt, > 400M Peak Nutzung]
- **Storage:** NVMe SSD [Größe?]
- **Netzwerk:** 10 Gbit/s (vermutlich)

## Software

- **Betriebssystem:** Debian 13 (Trixie)
- **OpenClaw:** v2026.4.11 (Node.js v22.22.2 via nvm) ✅
- **Docker:** v29.4.0 ✅
- **Tailscale:** v1.96.4 ✅
- **Node.js:** v22.22.2 ✅

## Verbindung zum Gateway

- **Gateway:** Node 1 (Hetzner Gateway)
- **Gateway IP:** 100.64.80.9 (Tailscale)
- **Gateway Port:** 18789
- **Verbindungsprotokoll:** ws:// (unverschlüsselt, falls OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1 gesetzt ist)
- **Authentifizierung:** Token-basiert (laut `gateway.auth` in `openclaw.json`)
- **Node-Modus:** `gateway.mode: "client"` (in `openclaw.json` auf Node 7)

## Services

- **openclaw.service** (systemd)
  - User: openclaw
  - ExecStart: `/home/openclaw/.nvm/versions/node/v22.22.2/bin/node /home/openclaw/.npm-global/lib/node_modules/openclaw/openclaw.mjs node run --host 100.64.80.9 --port 18789`
  - **Status:** Läuft (nach Korrektur der Konfiguration)

## Sicherheitskontext

- **Node 7:** `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1` gesetzt, um eine Verbindung über unverschlüsseltes `ws://` zu erlauben (da Tailscale die Verschlüsselung auf Netzwerkebene übernimmt).

## Wichtige Erkenntnisse

- **`gateway.mode`:** Muss `"local"` oder `"remote"` sein (basierend auf den Fehlermeldungen).
- **`gateway.address`:** Ist ein ungültiger Schlüssel.
- **Verbindung von Node zu Gateway:** Erfordert korrekte Konfiguration von `mode`, `address`/`remote.url` und `auth.token`/`auth.mode` in der **Node's** `openclaw.json`.
- **"Pairing required":** Zeigt, dass Node 7 Node 1 erreicht, aber Node 1 (Gateway) ihn noch nicht genehmigt hat. Da `openclaw nodes pending` nichts anzeigt, muss die Gateway-Konfiguration auf Node 1 überprüft werden, um `mode: "serve"` zu haben.

## Offene Punkte

- [ ] **Pairing:** Node 7 muss auf Node 1 genehmigt werden.
- [ ] **Gateway-Konfiguration auf Node 1:** Überprüfen, ob `gateway.mode: "serve"` und `bind: "loopback"` korrekt gesetzt sind.
- [ ] **Task-Logik:** Einrichtung von `coding-agent` und TikTok-Pipeline.

## Wartung

- Regelmäßige Updates von OpenClaw, Docker und OS.
- Monitoring der Systemressourcen (CPU, RAM, Disk, Netzwerk).
- Sicherstellen, dass die Verbindung zwischen Nodes stabil bleibt.

**Datum der Erstellung/letzten Änderung:** 2026-04-13
