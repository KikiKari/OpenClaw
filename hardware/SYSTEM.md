# DREI-NODE OPENCLAW SYSTEM

**Letzte Aktualisierung:** 2026-04-06

---

## Übersicht
Drei separate OpenClaw Gateways (kein Cluster-Mode möglich wegen Bug in 2026.4.2)

---

## Node 1 (Hauptnode)
- **Provider:** Hetzner
- **IP:** 152.53.145.65
- **Hostname:** v2202604104722446711
- **OS:** Ubuntu 24.04
- **OpenClaw:** Gateway via `openclaw gateway restart`
- **Port:** 18789
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
- **IP:** 159.195.78.116
- **Hostname:** v2202603104722445775
- **OS:** Ubuntu 24.04
- **OpenClaw:** Gateway
- **Port:** 18789
- **User:** openclaw
- **Tunnels:** Port 15000, 18790 (Reverse zu Node 1)
- **SSH-Key:** /root/.ssh/node1_tunnel (für Reverse-Tunnel zu Node 1)
- **Systemd-Services:** tunnel-15000, tunnel-18790, openclaw-tunnel (alle enabled)

---

## Node 3
- **Provider:** xNetX
- **IP:** 185.162.248.90
- **Hostname:** xnetx
- **OS:** CentOS Stream 8
- **OpenClaw:** Gateway
- **Port:** 18789
- **User:** root (wegen systemd Einschränkungen)
- **Tunnel:** Port 18792 (Reverse zu Node 1)
- **Auth:** Passwort (sshpass), kein SSH-Key-Auth aktiv
- **Bekanntes Problem:** fail2ban blockt Node 1 IP regelmäßig

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

## SSH Keys
- `/root/.ssh/node2_tunnel` → Zugang zu Node 2
- `/root/.ssh/node1_tunnel` → Zugang von Node 2 zu Node 1
- `/root/.ssh/node3_tunnel` → Zugang zu Node 3 (Key-Auth nicht aktiv)
- `/home/openclaw/.ssh/.node2_root` → Passwort für Node 3

---

## Systemd-Services auf Node 1
- `tunnel-to-node2` → Local Forward Port 5002 zu Node 2 (enabled)
- `tunnel-to-node3` → Local Forward Port 18793 zu Node 3 via sshpass (enabled)

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
