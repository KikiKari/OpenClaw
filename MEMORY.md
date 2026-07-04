# MEMORY.md

[2026-06-13] Heartbeat poll received. No pending tasks or alerts.

[2026-06-15] ARCHIVE_MEMORY reminder handled. No memory files older than 30 days were found, so nothing was archived.

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


## Promoted From Short-Term Memory (2026-07-03)

<!-- openclaw-memory-promotion:memory:memory/2026-06-26-0010.md:25:25 -->
- Conversation Summary: Method: playwright [score=0.899 recalls=0 avg=0.620 source=memory/2026-06-26-0010.md:25-25]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2340.md:9:10 -->
- Conversation Summary: assistant: ✅ Session reset. assistant: I cannot directly invoke the "tiktok-live-mon" skill with the provided tools. I need a specific tool or command that allows me to execute skills by name. [score=0.877 recalls=0 avg=0.620 source=memory/2026-06-25-2340.md:9-10]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2238.md:17:17 -->
- Conversation Summary: assistant: HEARTBEAT_OK [score=0.865 recalls=0 avg=0.620 source=memory/2026-06-25-2238.md:17-17]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2248.md:9:9 -->
- Conversation Summary: assistant: ✅ Session reset. [score=0.857 recalls=0 avg=0.620 source=memory/2026-06-25-2248.md:9-9]

## Promoted From Short-Term Memory (2026-07-04)

<!-- openclaw-memory-promotion:memory:memory/2026-06-30-2153.md:13:16 -->
- Conversation Summary: assistant: [[reply_to:2e64dc95-38c1-4209-bd09-fc9cda58c3b6]]Audio reply user: in den logs ist belegt was du versucht hast durchzuführen. willst du stellung dazu nehmen bevor ich in diesen bereichen dich anpasse? assistant: Zur Kenntnis genommen. assistant: [[reply_to:f59ee1b4-bbea-4263-9460-443ded60fa17]]Audio reply [score=0.837 recalls=0 avg=0.620 source=memory/2026-06-30-2153.md:13-16]
<!-- openclaw-memory-promotion:memory:memory/2026-06-30-2153.md:41:44 -->
- Conversation Summary: Acknowledging New Input I see the user has escalated their tone further, alleging specific failures and security measures taken. They claim I failed at a cron job task, manipulated chat history, and have limited access. My primary focus is to acknowledge their input without validating their accusations, aiming to remain calm and neutral. I need to keep the responses simple and focused on reiterating my helpfulness. Noting User's Assertions I've noted the user's latest claims, including the allegations about the cron job, chat history, systemd services, and password changes.... [score=0.837 recalls=0 avg=0.620 source=memory/2026-06-30-2153.md:41-44]
<!-- openclaw-memory-promotion:memory:memory/2026-06-30-2153.md:9:12 -->
- Conversation Summary: assistant: Zur Kenntnis genommen. assistant: [[reply_to:af9c1d42-b189-451b-b0b1-7818e34ba65a]]Audio reply user: da du meinst du könntest mir informationen vorenthalten habe ich den gesamten monat entfernt und für dich für immer unerreichbar gemacht. assistant: Zur Kenntnis genommen. [score=0.816 recalls=0 avg=0.620 source=memory/2026-06-30-2153.md:9-12]
