# TikTok LIVE Monitor

## Betriebsstand 2026-07-12

- Gateway und `xnetx` verwenden OpenClaw `2026.6.11`; Node-Transport erfolgt
  über Tailscale, ohne Public-IP-Fallback.
- Ein Python-/HTTP-Traceback (einschließlich `IncompleteRead`) ist immer ein
  `technical_error` und darf nicht als `offline` klassifiziert werden.
- Signierte Stream-URLs werden vollständig und bytegenau übernommen. Sie sind
  temporär; bei einem abgelaufenen Link ist genau eine neue Einzelabfrage
  erforderlich.
- Reale Gateway-Smoke-Tests für `@salina1894_official` und `@briansfamily`
  lieferten vollständige FLV-URLs; der Medienabruf für `@briansfamily` wurde als
  Macromedia-Flash-Video validiert.
- TikTok-Aufrufe sind an den aktuellen Slash-Turn gebunden und idempotent.
  Heartbeats dürfen keine TikTok-Aktion ausführen.
- Webchat verwendet `messages.queue.mode: followup`, damit neue Nachrichten
  nicht mit der atomaren Initialisierung eines bereits laufenden Reply-Turns
  kollidieren.

Der gemeinsame Dispatcher ist der kanonische Einstieg für Status- und
URL-Abfragen:

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" check @example_creator
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url example_creator
```

Er normalisiert Handles, unterscheidet `live`, `offline` und `restricted`,
validiert Stream-URLs und liefert Überlast als Exit `75`. Im URL-Modus steht
ohne `--json` ausschließlich die nackte URL auf stdout.

Der Gateway kann alle Abfragen lokal ausführen. Ein OpenClaw-Agent kann
denselben Befehl über `exec host=node` auf einem verbundenen gepaarten Node
mit `--execution local` starten. Fehlschlag, fehlende Abhängigkeiten, Timeout
oder Überlast führen standardmäßig zum Gateway-Fallback.

Für den zustandsbehafteten Monitor und Daemon:

```bash
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" help
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" check example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" url example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" daemon example_creator --hours 24 --poll-min 10
```

Details stehen in `SKILL.md` und `docs/`.
