# TikTok Live – aktueller Betriebsstand

Stand: 2026-07-13

## Kanonische Playwright-Skripte

- `workspace/skills/tiktok-live-mon/tiktok-check-profile.js`
- `workspace/skills/tiktok-live-mon/tiktok-get-stream.js`
- `workspace/skills/tiktok-live/scripts/tiktok-check-profile.js`
- `workspace/skills/tiktok-live/scripts/tiktok-get-stream.js`

Benutzernamen werden als CLI-Parameter übergeben und dürfen ein führendes
`@` enthalten. Dokumentationsbeispiele verwenden ausschließlich
`example_creator`. Reale Handles dürfen nur im TikTok-Namensspeicher
`tiktok-names` sowie in ausdrücklich historischen Protokollen stehen.

## Namensliste in OpenClaw Control

Der exakte Chatbefehl `/tiktok-names` zeigt den aktuellen Inhalt aus
`workspace/tiktok-names/identities/*.json` an. Er akzeptiert keine Argumente
und führt ausschließlich die rein lesende Operation `list` aus.

Die Ausgabe enthält alphabetisch sortiert den aktuellen `@handle`, den
Nickname sowie – falls vorhanden – frühere Handles (`früher: …` aus
`rename_history`) und den Beobachtungszeitraum (`gesehen: <erstes Datum> bis
<letztes Datum>`). `sec_uid`, `user_id` und andere technische Felder werden
nicht ausgegeben. Der Slash-Command liefert das Ergebnis deterministisch
direkt aus dem Plugin-Handler (kein Modell im Pfad); das parameterlose Tool
`tiktok_names_list` bleibt für Natural-Language-Anfragen bestehen. Der Befehl
verändert weder Identity- noch Pointer-Dateien.

Identitäten werden aus drei Quellen aufgezeichnet: SIGI-Scrapes des
Python-Monitors, `owner`-Daten der Webcast-room/info-Antwort und in
Playwright-Ergebnisse eingebettete `identity`-Objekte (Dispatcher
`record_identity`). Die Aufbewahrung beträgt standardmäßig 90 Tage
(`TT_LIVE_IDENTITY_RETENTION_DAYS`, 0 = nie löschen); Löschungen werden in
`workspace/tiktok-names/cleanup.log` protokolliert.

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
Extraktion endet mit Exit-Code 1. Das JSON des Enhanced-Extractors enthält
zusätzlich `streams` (alle erfassten URLs mit Container/Qualität) und
`identity`.

## Live-Antwortformat (Endnutzer)

Bei LIVE liefert der Dispatcher zusätzlich `info` (Titel, Zuschauer aktuell/
gesamt, Likes, Follower/Gefolgt, Live-Beginn; die Room-ID bleibt im Payload,
wird aber nicht angezeigt) und `qualities` (alle
Tiers Original…360p, je HLS und FLV). Das tiktok-live-dispatch-Plugin rendert
daraus die finale Antwort: Info-Zeilen, danach pro Qualität und Container eine
eigene Codebox, die ausschließlich die URL enthält (Copy/Paste-sicher),
abschließend `Method:`. Details: `workspace/tiktok-monitor/docs/SCHEMA.md`
§6.2 und `workspace/skills/tiktok-live/SKILL.md`.

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
