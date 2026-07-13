# DREI-NODE OPENCLAW SYSTEM

**Letzte Aktualisierung:** 2026-07-12

---

## Übersicht
OpenClaw-Gateway mit gepaarten Nodes. Die Transportverbindung für Node-Pairing
und Node-Betrieb erfolgt ausschließlich über Tailscale. Es gibt keinen
Fallback über öffentliche IP-Adressen.

---

## Node 1 (Hauptnode)
- **Hostname:** v2202604104722449961
- **Tailscale-IP:** 100.82.198.122
- **OS:** Ubuntu 24.04
- **OpenClaw:** Gateway via `openclaw gateway restart`
- **Gateway-Port:** 18790
- **Erreichbarkeit:** Loopback und Tailscale; kein Public-IP-Listener
- **TikTok:** Gateway-lokaler Dispatcher mit optionaler agent-gesteuerter Node-Ausführung
- **User:** openclaw
- **Config:** /home/openclaw/.openclaw/openclaw.json
- **ENV:** /home/openclaw/.config/openclaw/env
- **Workspace:** /home/openclaw/.openclaw/workspace/
- **DB:** /home/openclaw/.openclaw/db/artii.db
- **Skills:** /home/openclaw/.openclaw/skills/
- **Cron:** /home/openclaw/.openclaw/cron/
- **Skripte:** /home/openclaw/bin/

---

## Node 2
- **Provider:** Netcup
- **Externe IP:** 159.195.78.116 (Administration, nicht für OpenClaw-Pairing)
- **Tailscale-IP:** 100.92.155.34
- **Hostname:** v2202603104722445775
- **OS:** Ubuntu 24.04
- **OpenClaw:** gepaarter Node
- **Transport:** Tailscale zum Gateway
- **User:** openclaw
- **Public-IP-Fallback:** nicht eingerichtet und nicht vorgesehen

---

## Node 3
- **Provider:** xNetX
- **Externe IP:** 185.162.248.90 (nur Administration, nicht für OpenClaw-Pairing)
- **Tailscale-IP:** 100.73.154.125
- **Hostname:** xnetx
- **OS:** CentOS Stream 8
- **OpenClaw:** gepaarter Node
- **Transport:** Tailscale zum Gateway `100.82.198.122:18790`
- **User:** root (wegen systemd Einschränkungen)
- **Public-IP-Fallback:** nicht eingerichtet und nicht vorgesehen
- **Administration:** SSH kann separat als `root` erfolgen; dies ist vom OpenClaw-Pairing unabhängig

---

## Modell-Konfiguration (Stand 2026-04-06)
- **Primary:** openrouter/moonshotai/kimi-k2.5
- **Fallbacks:** claude-3.5-sonnet, deepseek-v3, llama-3.3-70b, minimax-01
- **Registrierte Modelle:**
  - openrouter/moonshotai/kimi-k2.5
  - openrouter/auto (Alias: OpenRouter)
  - openrouter/openai/gpt-4o (Alias: OpenAI GPT-4o)
  - openrouter/openai/gpt-4o-mini (Alias: OpenAI GPT-4o Mini)

---

## Aktivierte Skills (Stand 2026-04-06)
weather, summarize, github, himalaya, session-logs, tmux, healthcheck,
skill-creator, video-frames, nano-pdf, blogwatcher, discord, model-usage,
oracle, sherpa-onnx-tts, spotify-player, notion, openai-whisper-api, sag,
coding-agent, **tiktok-live**, **tiktok-live-mon**

---

## TikTok LIVE (Aktualisiert 2026-06-21)

**Kanonischer Einstieg:** `$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py`

**Skills:**
- `$HOME/.openclaw/workspace/skills/tiktok-live/` — Basisprüfung und URL-Extraktion
- `$HOME/.openclaw/workspace/skills/tiktok-live-mon/` — `live|restricted|offline` und Fallbacks

**Ausführung:** lokal auf dem Gateway oder durch einen OpenClaw-Agenten über `exec host=node` auf einem verbundenen gepaarten Node. Bei fehlendem Node, Abhängigkeit, Timeout oder Überlast erfolgt standardmäßig Gateway-Fallback.

**Vertrag:** keine festen Handles; Überlast Exit `75`; Offline/Restricted Exit `1`; nicht-JSON URL-Erfolg schreibt ausschließlich die nackte URL.

Die alte Port-5001-API und die TikTok-Cron-Beispiele sind nicht aktiv.

---

## Netzwerk- und SSH-Vertrag

- OpenClaw-Pairing und Node-Traffic: ausschließlich Tailscale.
- Kein automatischer oder manueller Pairing-Fallback über externe IPs.
- Root-SSH-Schlüssel dienen nur administrativen Aufgaben wie Updates und Dienstneustarts.
- SSH-Schlüssel, Tailscale-SSH und OpenClaw-Pairing sind getrennte Authentisierungsebenen.

---

## Transportdienste auf dem Gateway

Die früher dokumentierten Dienste `tunnel-18790`, `openclaw-tunnel` und
Public-IP-Reverse-Tunnel sind auf diesem Gateway nicht vorhanden. Tailscale ist
der einzige vorgesehene Node-Transport.

---

## Alle Cron-Jobs (OpenClaw intern)

| Job | Zeit | Zweck |
|-----|------|-------|
| hourly-email-check | XX:00 | E-Mail-Check |
| light-system-check | alle 3h | System-Health |
| session-delta-sync | alle 3h | Session-Monitoring |
| daily-system-health | 06:00 | Täglicher Health-Check |
| daily-memory-cleanup | 07:00 | Memory-Wartung |
| daily-security-check | 08:00 | Sicherheits-Check |

**Config:** `~/.openclaw/cron/jobs.json`

---

## Aktive Crontab (2026-04-18)

| Job | Zeit | Zweck | User |
|-----|------|-------|------|
| **openclaw-gateway** | @reboot + */20 | Gateway Start + Redundanz | openclaw |
| **db-maintainer** | */30 | DB-Wartung, Backup, Tree-Scan | openclaw |
| **log-collector** | */3h | Log-Sammlung von Nodes via SSH | openclaw |
| **daily-db-backup** | 3:00 | DB-Backup | openclaw |
| **nodes-report** | */3h | Nodes-Status-Report | openclaw |
| **ops-hub-heartbeat** | */30 | Ops-Hub Heartbeat | openclaw |

### Redundanz-Erklärung

**@reboot + */20 für Gateway:**
- @reboot: Versucht Start direkt nach Boot
- */20: Prüft alle 20 Min, startet falls nicht läuft
- Verhindert: Mehrfachstarts durch PID-Prüfung

**Beispiel-Ablauf:**
```
Boot → @reboot startet Gateway → */20 prüft: läuft → OK
Boot → @reboot fehlschlägt → */20 (nach 20min) startet Gateway
```

---

## Datenbanken

| Datenbank | Zweck | Intervall | Retention |
|-----------|-------|-----------|-----------|
| **docs.db** | Dokumentations-Index | 30min | Permanent |
| **tree.db** | Datei-Tracking | 30min | Permanent |
| **logs.db** | Node/Gateway Logs | 3h | **30 Tage** |

**Pfad:** `~/.openclaw/workspace/db/`

---

## Node Start

Vorlagen für Node-Start mit VPN-IP:
- [NODE_START_TEMPLATE.md](docs/reference/NODE_START_TEMPLATE.md)

**Node 2 (Netcup, 10.10.0.2):**
```bash
openclaw node run --host 10.10.0.2 --port 18789
```

**Node 3 (xNetX, 10.10.0.3):**
```bash
openclaw node run --host 10.10.0.3 --port 18789
```

---

## Wichtige Dokumente

| Dokument | Pfad |
|----------|------|
| SYSTEM.md | Diese Datei |
| TikTok LIVE | `workspace/skills/tiktok-live/references/TIKTOK.md` |
| MAINTENANCE.md | `memory/MAINTENANCE.md` |
| MEMORY.md | `workspace/MEMORY.md` |

---

## Bekannte Probleme

| Problem | Status | Notiz |
|---------|--------|-------|
| Node-Service --gateway Flag | ⚠️ Offen | Bug 2026.4.2 |
| Externe Gateway-Verbindung | ⚠️ Offen | Nicht möglich |
| Node 3 fail2ban | ⚠️ Offen | Blockt Node 1 IP |
| TikTok API Port 5001 | Retired | Dispatcher/Playwright ersetzt den Dienst |
| DSGVO-Banner | ✅ Gelöst | Automatisches Schließen |
