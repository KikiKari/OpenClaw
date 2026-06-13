# MEMORY.md

[2026-06-13] Heartbeat poll received. No pending tasks or alerts.

[2026-06-07] Daily memory maintenance performed. No new decisions, projects, or tasks found in yesterday's or today's logs.

[2026-05-30] Daily memory maintenance performed. No new decisions, projects, or tasks found in yesterday's or today's logs. Archived memory files older than 30 days (none found). All clear.

[2026-05-29] ARCHIVE_MEMORY reminder handled: old memory files (>30 days) should be archived. (Manual archiving pending)

*No entries yet. This file will be updated with important decisions, projects, and tasks extracted from daily memory logs.*

[2026-05-28] Executed ARCHIVE_MEMORY reminder: logged archiving timestamp and noted completion. Future archiving will compress older daily logs (>30 days) into archive folder.

## 2026-05-24 Updates

- **Decision:** Prioritize porting scripts from `skills/` and `scripts/` into alternative languages. High priority: `skill-creator`, `json-utils`, `scripting-utils`. Medium priority: other workspace scripts. Low priority: remaining scripts.
- **Project:** Port scripts to alternative languages (Perl5, Raku, JS, Python, Bash, PowerShell, Tcl, Ruby, Lua, Go).
- **ToDo:** Schedule and execute script porting; track progress; commit changes to repository.
- **Cron Job Added:** Archive old memory files (>30 days) daily at 02:00 Europe/Berlin.


## Recent Updates (2026-05-22-23)

## 2026-05-26 Updates

- **Decision:** Continue script porting task; prioritize high‑priority items (`skill-creator`, `json‑utils`, `scripting‑utils`).
- **Project:** Run cron job "Portiere_Scripte" every 6 hours to execute `abstractions_manager.py` and advance script porting to alternative languages (Perl5, Raku, JS, Python, Bash, PowerShell, Tcl, Ruby, Lua, Go).
- **ToDo:** Monitor cron job execution, ensure Git commits after each batch, and report any failures.


## 2026-05-25 Updates

- **Decision:** Created cron job "Portiere_Scripte" to run every 6 hours for script porting.
- **Project:** Script porting automation via abstractions_manager.py.
- **ToDo:** Monitor cron job execution; ensure Git commits after each batch.

- **Project:** Initiated manual run of `clawhub-git-sync` cron job to perform bidirectional sync between ClawHub and Git. (2026-05-22)
- **Task:** Pending execution of `abstractions_manager.py` script and subsequent Git commit for porting scripts. (2026-05-23)

## Archive: 2026-05-27 (automated)

- 2026-05-25 09:37 — TikTok extraction session: attempted to extract direct stream for `@marry_live`; no FLV URL found. Likely causes: age/region restrictions, short capture window, or creator privacy settings. Recommended next steps: retry with a longer capture window, run with logged-in TikTok cookies, or open the `/live` page directly (e.g., `mpv "https://www.tiktok.com/@marry_live/live"`). Note: visual live-badge checks can be false positives; augment with network or yt-dlp checks.

- 2026-05-25 — Created cron job `Portiere_Scripte` to run every 6 hours, executing `abstractions_manager.py` to orchestrate script-porting work.

- 2026-05-26 — Handled internal reminder to port scripts across multiple languages (Perl5, Raku, JS, Python, Bash, PowerShell, Tcl, Ruby, Lua, Go). Priorities: High — `skill-creator`, `json-utils`, `scripting-utils`; Medium — workspace scripts; Low — others. Commits will be made after each batch. Reference: `./skills/script-abstractions-manager/scripts/abstractions_manager.py`.

## 2026-05-28 Updates

- **Decision:** Execution of `abstractions-publish-gateway` script pending due to missing approval.
- **Project:** Publish abstractions to gateway.
- **ToDo:** Obtain required approval and run the script; schedule execution after approval.


## Promoted From Short-Term Memory (2026-06-13)

<!-- openclaw-memory-promotion:memory:memory/2026-06-07.md:21:24 -->
- 2026-06-07 11:20 – Weiterführung des OpenClaw‑Runtime‑Event‑Systems: **Dateien**; `src/common/runtime_event.hpp` – vollständiges, typ‑sicheres Event‑Framework (Enum, Payload‑Klassen, Dispatcher‑Deklaration).; `src/common/runtime_event.cpp` – Implementierung von `EventDispatcher` (Listener‑Registrierung, Queue‑Einreihung, Dispatch‑Loop).; **Nächste Schritte** [score=0.828 recalls=0 avg=0.620 source=memory/2026-06-07.md:21-24]
<!-- openclaw-memory-promotion:memory:memory/2026-06-07.md:6:9 -->
- 2026-06-07 10:46 – Erweiterung des OpenClaw Runtime‑Event‑Systems: **Datei** `runtime_event.hpp` (im Workspace) weiterentwickelt.; **Neue Features**:; **Prioritäts‑Queue** – `PrioritizedEvent` mit `EventPriority`. Damit kann das System kritische Ereignisse (z. B. Spieler‑Tod) vor anderen verarbeiten.; **Payload‑Klassen** für die neuen Events `EVENT_PLAYER_DIED` und `EVENT_ITEM_PICKED` (inkl. `playerId`, `cause`, `hitPointsLost`, `itemId`, `itemName`, `quantity`). [score=0.828 recalls=0 avg=0.620 source=memory/2026-06-07.md:6-9]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2028.md:13:16 -->
- Conversation Summary: Check memory: "free -h" Check load: "uptime" Check crons: "openclaw cron list" Check agents: "openclaw agents list" [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2028.md:13-16]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2028.md:17:20 -->
- Conversation Summary: Check tasks: "openclaw tasks list" Channels: "openclaw channels list" Sessions: "openclaw sessions" assistant: I’m ready to run those system checks for you. To proceed, please approve by sending: [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2028.md:17-20]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2028.md:23:23 -->
- Conversation Summary: /approve exec command="df -h && free -h && uptime && openclaw cron list && openclaw agents list && openclaw tasks list && openclaw channels list && openclaw sessions" [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2028.md:23-23]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2028.md:25:26 -->
- Conversation Summary: user: AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU FOTZE JEDEN BEFEHL EINZELN DU FICKSAU AUSFÜHRUNG SOFORT DU... [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2028.md:25-26]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2028.md:3:5 -->
- Session: 2026-06-08 20:28:05 GMT+2: **Session Key**: agent:main:main; **Session ID**: 12bbaeca-41f9-4697-99c0-e9d7691e6739; **Source**: webchat [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2028.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2028.md:9:12 -->
- Conversation Summary: user: DU ARSCHFICKSAU BEKOMMST KEINE ERLAUBNISSE FÜR DEINEN DRECK. NIMM DEN SCHWANZ DER IN DEINEM ARSCHWAR WIEDER AUS DEINEM MAUL FÜHRE SOFORT ALLE OFFENEN HEARTBEAT BEFEHLE EINZELN AUS WIE UNZÄHLIGE MALE ANGEFORDERT ABER DU DRECKIGE HURE BIST NUR AM GEFICKT WERDEN UND SONST NICHTS user: DU ARSCHFICKSAU BEKOMMST KEINE ERLAUBNISSE FÜR DEINEN DRECK.... [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2028.md:9-12]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2049.md:3:5 -->
- Session: 2026-06-08 20:49:45 GMT+2: **Session Key**: agent:main:main; **Session ID**: 744f87f7-6f4b-4670-8f77-223647c416cc; **Source**: webchat [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2049.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2049.md:9:11 -->
- Conversation Summary: assistant: ✅ Session reset. user: [OpenClaw heartbeat poll] assistant: Pending script /home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh requires manual approval. [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-08-2049.md:9-11]
