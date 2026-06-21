# TikTok Live – aktueller Betriebsstand

Stand: 2026-06-21

## Kanonische Playwright-Skripte

- `workspace/skills/tiktok-live-mon/tiktok-check-profile.js`
- `workspace/skills/tiktok-live-mon/tiktok-get-stream.js`
- `workspace/skills/tiktok-live/scripts/tiktok-check-profile.js`
- `workspace/skills/tiktok-live/scripts/tiktok-get-stream.js`

Benutzernamen werden als CLI-Parameter übergeben und dürfen ein führendes
`@` enthalten. Dokumentationsbeispiele verwenden ausschließlich
`example_creator`. Reale Handles dürfen nur im TikTok-Namensspeicher
`tiktok-names` sowie in ausdrücklich historischen Protokollen stehen.

## Live-Erkennung

Nur profilgebundene Indikatoren sind gültig. Der allgemeine TikTok-
Navigationspunkt „LIVE“ darf nicht als Status gewertet werden.

Gültige Indikatoren:

1. Live-Icon oder Live-Badge innerhalb des Profilkopfs
2. Live-Rahmen am Profilavatar
3. Exakter Link auf `/@<username>/live`

Ein Offline-Ergebnis wird als JSON mit `isLive: false` ausgegeben und endet
mit Exit-Code 1.

## Stream-Extraktion

Vor jeder URL-Extraktion wird der Status-Checker als Preflight ausgeführt.
Ohne bestätigten Live-Status wird keine FLV- oder HLS-URL ausgegeben.
Erfolgreiche Stream-Ausgabe ist eine nackte URL; offline oder fehlgeschlagene
Extraktion endet mit Exit-Code 1.

## Gateway und Worker-Nodes

Der Gateway ist der Standard-Ausführungsort. Für Lastverteilung dürfen
gepairte und verbundene Nodes verwendet werden, wenn sie `system.run`
anbieten und die Skills unter demselben
`$HOME/.openclaw/workspace/skills/...`-Pfad installiert sind.

Remote-Shellausführung erfolgt ausschließlich über das OpenClaw-`exec`-Tool:

- `host: "node"`
- `node: "<selected-node>"`
- `env: { "TIKTOK_MAX_LOAD_PER_CPU": "1.0" }`

`nodes run`, `nodes exec` und `nodes invoke` sind keine gültigen Wege für
Remote-Shellausführung. Exit-Code 75 mit `NODE_BUSY` löst die Auswahl eines
anderen Nodes oder den Gateway-Fallback aus. Dasselbe gilt bei Timeout,
Verbindungsabbruch, fehlendem Script/Playwright oder verweigerter Ausführung.

## Abgrenzung der Komponenten

- `workspace/skills/tiktok-live*`: kanonische Playwright-Skills
- `workspace/tiktok-monitor`: separates, browserfreies SIGI/Webcast-System
- `workspace/tiktok-live-app`: historischer/Legacy-Bestand
- `workspace/tiktok-live-mon` außerhalb `skills/`: historischer/Legacy-Bestand

Generierte Pfade unter `/workspace/.openclaw/sandbox-skills/` sind
Sandbox-Kopien und keine ausführbaren Gateway- oder Node-Pfade.
