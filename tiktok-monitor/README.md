# Browserfreies SIGI/Webcast-Monitoring

Dieses System ist unabhängig von den kanonischen Playwright-Skills unter
`workspace/skills/tiktok-live*`. Zuständigkeiten und aktueller Betriebsstand:
`/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md`.

# Beschreibung und Test mit:
`$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh help`

# Aufruf und Verwendung mit:
`$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh check example_creator`

`$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh url example_creator`

`$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh url example_creator --json`
(JSON mit `url`, `source`, `room_id`, `info` (Titel/Zuschauer/Likes/Follower)
und `qualities` (alle Auflösungen, je HLS+FLV); siehe `docs/SCHEMA.md` §6.2)

`$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh daemon example_creator --hours 12`
