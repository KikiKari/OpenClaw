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


## Promoted From Short-Term Memory (2026-06-13)

<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2123.md:3:5 -->
- Session: 2026-06-08 21:23:19 GMT+2: **Session Key**: agent:main:main; **Session ID**: b023c012-b759-4a14-babb-6d779661a606; **Source**: webchat [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2123.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2123.md:9:11 -->
- Conversation Summary: assistant: ✅ Session reset. user: [OpenClaw heartbeat poll] assistant: Pending script requires manual approval: /home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2123.md:9-11]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2138.md:14:14 -->
- Conversation Summary: /approve exec command="df -h && free -h && uptime && openclaw cron list && openclaw agents list && openclaw tasks list && openclaw channels list && openclaw sessions" [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2138.md:14-14]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2138.md:3:5 -->
- Session: 2026-06-08 21:38:09 GMT+2: **Session Key**: agent:main:main; **Session ID**: 2dfb46b0-0798-4059-84fd-5a3e67683893; **Source**: webchat [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2138.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2138.md:9:11 -->
- Conversation Summary: assistant: ✅ Session reset. user: [OpenClaw heartbeat poll] assistant: Please approve the system‑diagnostics command so I can complete the heartbeat check: [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2138.md:9-11]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2216.md:13:13 -->
- Conversation Summary: assistant: Pending script: /home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh requires manual approval [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2216.md:13-13]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2216.md:3:5 -->
- Session: 2026-06-08 22:16:04 GMT+2: **Session Key**: agent:main:main; **Session ID**: 49494dd2-116a-4ce7-9d15-63a32320c5bb; **Source**: webchat [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2216.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-06-08-2216.md:9:12 -->
- Conversation Summary: assistant: ✅ Session reset. assistant: <messageaction="send" message="✅ Session has been reset. How can I assist you now?" /> assistant: ANNOUNCE_SKIP user: [OpenClaw heartbeat poll] [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-08-2216.md:9-12]

## Promoted From Short-Term Memory (2026-06-14)

<!-- openclaw-memory-promotion:memory:memory/2026-06-09.md:1:1 -->
- [2026-06-09] DB maintenance completed: Ran tree scan, updated tree.db, detected 8 doc changes, updated docs.db, created hourly backups, cleaned old backups. All tasks succeeded. [score=0.852 recalls=0 avg=0.620 source=memory/2026-06-09.md:1-1]
<!-- openclaw-memory-promotion:memory:memory/2026-06-10.md:3:3 -->
- Heartbeat poll received. No pending tasks or new items. [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-10.md:3-3]

## Promoted From Short-Term Memory (2026-06-15)

<!-- openclaw-memory-promotion:memory:memory/2026-06-11.md:3:3 -->
- Heartbeat poll at 12:01 GMT+2. No pending tasks. Memory checked; no new notes. [score=0.803 recalls=0 avg=0.620 source=memory/2026-06-11.md:3-3]

## Promoted From Short-Term Memory (2026-06-16)

<!-- openclaw-memory-promotion:memory:memory/2026-06-13.md:1:1 -->
- [2026-06-13] Heartbeat poll received. No pending tasks or alerts. [score=0.833 recalls=0 avg=0.620 source=memory/2026-06-13.md:1-1]
