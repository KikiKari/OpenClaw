# Memory Runtime Comparison Workpack — 24h

> Beobachtet 24 Stunden lang das Verhalten der aktiven Memory-Plugin-Pipeline.
> Zwei OpenClaw-Gateways laufen identisch konfiguriert bis auf ein Detail:
>
> - **Gateway A (Migration-Subjekt)**: `plugins.slots.memory = "memory-lancedb"`, `memory-core.enabled = false`
> - **Gateway B (Kontrolle)**: `plugins.slots.memory = "memory-core"`, `memory-lancedb` deaktiviert/inaktiv
>
> Ziel ist ein **Apples-to-Apples-Vergleich** auf 5 Achsen: Sweep-Ergebnis, Daten-Wachstum, Cron-Lauf-Häufigkeit, Recall-Aktivität und Fehler/Warnungen.

---

## 0. Vor dem Start ausfüllen

Jede Seite ergänzt diesen Block einmal manuell im eigenen Report:

```yaml
# Bitte ausfüllen vor dem ersten Run:
gateway_label: ""            # z.B. "v2202604104722446711" (claude/lancedb) oder "v2202604104722449961" (main/memory-core)
gateway_role:  ""            # "subject" (lancedb) | "control" (memory-core)
active_memory_plugin: ""     # "memory-lancedb" | "memory-core"
agent_workspace: ""          # "main" | "ops-hub" | "knecht" — egal welcher, beide Seiten gleich wählen
start_iso:     ""            # ISO-8601 wann Run gestartet wird, beide Seiten möglichst gleicher Zeitpunkt
```

Empfehlung: **agent_workspace = "main"** auf beiden Seiten (höchstes Recall-Volumen, vergleichbarste Datenbasis).

---

## 1. Setup (einmalig, dauert ~2 Min)

Auf der gewählten Seite, im Workspace des gewählten Agents (`~/.openclaw/workspace/<agent>` bzw. Root `~/.openclaw/workspace` für `main`):

```bash
# Ergebnisordner anlegen
REPORT_ROOT=~/.openclaw/workspace/_runtime-test-$(date +%Y%m%d)
mkdir -p "$REPORT_ROOT/snapshots" "$REPORT_ROOT/logs"
echo "$REPORT_ROOT" > /tmp/runtime_test_path.txt
echo "Report-Ordner: $REPORT_ROOT"

# Snapshot-Script ablegen
cat > "$REPORT_ROOT/snapshot.sh" <<'EOF'
#!/usr/bin/env bash
# Erfasst einen Zeitpunkt-Snapshot ohne Live-System zu stressen.
set -u
REPORT_ROOT="$(cat /tmp/runtime_test_path.txt 2>/dev/null || echo ~/.openclaw/workspace/_runtime-test)"
TS=$(date -Is)
OUT="$REPORT_ROOT/snapshots/$TS.json"
mkdir -p "$(dirname "$OUT")"

# Sichere JSON-Helper
j() { python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$1"; }

{
  echo "{"
  echo "  \"ts\": $(j "$TS"),"
  echo "  \"hostname\": $(j "$(hostname)"),"
  echo "  \"plugin_slot\": $(jq -r '.plugins.slots.memory // "none"' ~/.openclaw/openclaw.json | xargs -I{} python3 -c "import json,sys;print(json.dumps('{}'))"),"

  # Storage-Größen (was wächst?)
  echo "  \"disk\": {"
  echo "    \"lancedb_bytes\":     $(du -sb ~/.openclaw/memory/lancedb 2>/dev/null | cut -f1 || echo 0),"
  echo "    \"sqlite_total_bytes\": $(du -cb ~/.openclaw/memory/*.sqlite 2>/dev/null | tail -1 | cut -f1 || echo 0),"
  echo "    \"workspace_dreams_bytes\": $(du -csb ~/.openclaw/workspace/*/memory/.dreams 2>/dev/null | tail -1 | cut -f1 || echo 0)"
  echo "  },"

  # short-term-recall.json Zeilen-Counts (memory-core legacy data)
  echo "  \"recall_counts\": {"
  for ws in ~/.openclaw/workspace/*/memory/.dreams/short-term-recall.json; do
    [ -f "$ws" ] || continue
    name=$(basename "$(dirname "$(dirname "$(dirname "$ws")")")" )
    count=$(jq '.entries | length' "$ws" 2>/dev/null || echo null)
    echo "    \"$name\": $count,"
  done
  # auch root workspace (main)
  [ -f ~/.openclaw/workspace/memory/.dreams/short-term-recall.json ] && \
    echo "    \"main\": $(jq '.entries | length' ~/.openclaw/workspace/memory/.dreams/short-term-recall.json 2>/dev/null || echo null)"
  echo "    ,\"_end\": null"
  echo "  },"

  # Gateway laufend?
  PID=$(pgrep -f "openclaw.*gateway" | head -1)
  echo "  \"gateway_pid\": ${PID:-null},"
  echo "  \"gateway_uptime_seconds\": $([ -n "$PID" ] && ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ' || echo 0),"

  # Cron-Files vorhanden?
  echo "  \"cron_files\": $(find ~/.openclaw/cron -type f 2>/dev/null | wc -l),"

  # Anzahl DREAMS.md-Einträge (grobe Heuristik: Zeilen mit ## Datum)
  DREAMS=$(grep -c "^## " ~/.openclaw/workspace/DREAMS.md 2>/dev/null || echo 0)
  echo "  \"dreams_md_h2_count_root\": $DREAMS,"

  echo "  \"end\": null"
  echo "}"
} > "$OUT"
echo "[snapshot] $OUT"
EOF
chmod +x "$REPORT_ROOT/snapshot.sh"
"$REPORT_ROOT/snapshot.sh"   # Initialer Snapshot (T0)

# Cron eintragen: jede Stunde ein Snapshot
( crontab -l 2>/dev/null | grep -v "runtime-test"; echo "0 * * * * $REPORT_ROOT/snapshot.sh >> $REPORT_ROOT/logs/cron.log 2>&1" ) | crontab -
crontab -l | grep runtime
```

> **Wichtig**: Dieser Cron ist ein **systemd/cron-User-Cron**, nicht OpenClaw-Cron. Damit beeinflusst der Test nicht den OpenClaw-Cron-Scheduler.

---

## 2. Optionale aktive Sonden (nur wenn gewünscht)

Wenn dein Gateway noch `openclaw memory` CLI hat (Kontroll-Gateway B), kannst du periodisch Suchqualität messen. Bei Gateway A (lancedb) ist die `openclaw memory` CLI nicht verfügbar — dort überspringen:

```bash
# NUR auf Gateway B (memory-core aktiv) ausführen
cat > "$REPORT_ROOT/probe.sh" <<'EOF'
#!/usr/bin/env bash
set -u
REPORT_ROOT="$(cat /tmp/runtime_test_path.txt)"
TS=$(date -Is)
OUT="$REPORT_ROOT/snapshots/probe-$TS.txt"
QUERIES=(
  "memory configuration"
  "lancedb"
  "dreaming"
  "session"
  "user preference"
)
{
  echo "=== Probe $TS ==="
  for q in "${QUERIES[@]}"; do
    echo "--- query: $q ---"
    time openclaw memory search "$q" --max-results 3 2>&1 | head -30
  done
} > "$OUT" 2>&1
EOF
chmod +x "$REPORT_ROOT/probe.sh"

# Eintrag zusätzlich alle 4h
( crontab -l 2>/dev/null | grep -v "runtime-test-probe"; echo "30 */4 * * * $REPORT_ROOT/probe.sh >> $REPORT_ROOT/logs/probe.log 2>&1 # runtime-test-probe" ) | crontab -
```

Auf Gateway A (lancedb) ersetzen wir die aktive Suche durch **Beobachtung der Agent-Session-Logs** — siehe Abschnitt 3.

---

## 3. Was zusätzlich beobachten

Beide Seiten, manuell oder via UI:

1. **02:00 Berlin (Gateway A)** und **03:00 Berlin (Gateway B)** → Dreaming-Sweep läuft. Am Morgen prüfen:
   - UI „Träume → Tagebuch": Wurde ein neuer Eintrag geschrieben?
   - UI „Träume → Erweitert": Wartende vs. heute-befördert
   - `~/.openclaw/workspace/<ws>/DREAMS.md`: Neuer `## YYYY-MM-DD`-Block?
2. **OpenClaw Control UI → Crons-Tab**: Screenshot um T0, T+6h, T+12h, T+24h. Welche Cron-Aufgaben zeigen welche „nächste Ausführung", Status, Fehler?
3. **OpenClaw Control UI → Sessions-Tab**: Stört der Test irgendwelche Live-Sessions? (Erwartung: nein)
4. **`openclaw status --deep`** bei T0 und T+24h einmal, Output in den Report-Ordner kippen.

---

## 4. Auswertung (nach 24h)

```bash
REPORT_ROOT=$(cat /tmp/runtime_test_path.txt)
cd "$REPORT_ROOT"

# Snapshot-Zusammenfassung
echo "=== Snapshots: ==="
ls snapshots/ | wc -l

# Disk-Wachstum
echo "=== Disk-Wachstum lancedb vs sqlite ==="
for f in snapshots/*.json; do
  jq -r '[.ts, .plugin_slot, .disk.lancedb_bytes, .disk.sqlite_total_bytes] | @tsv' "$f"
done

# Recall-Wachstum (alle workspaces summiert)
echo "=== Recall-Entries-Wachstum (alle ws summiert) ==="
for f in snapshots/*.json; do
  jq -r '[.ts, ([.recall_counts | to_entries[] | select(.value != null and .value != "null") | .value] | add // 0)] | @tsv' "$f"
done

# Cron-Aktivität
echo "=== Cron-Trigger-Log (letzte 50 Zeilen) ==="
tail -50 logs/cron.log

# Abschluss-Snapshot
"$REPORT_ROOT/snapshot.sh"
```

Output in `$REPORT_ROOT/SUMMARY.md` kopieren und mit der anderen Seite austauschen.

---

## 5. Aufräumen (nach Abschluss)

```bash
# Cron-Einträge entfernen
crontab -l | grep -vE "runtime-test|runtime-test-probe" | crontab -
crontab -l

# Report-Ordner bleibt liegen — kann verglichen werden
echo "Test-Artefakte: $REPORT_ROOT (manuell löschen wenn nicht mehr benötigt)"
```

---

## 6. Erwartete Unterschiede (Hypothesen — werden durch Daten widerlegt oder bestätigt)

| Achse | Gateway A (lancedb) | Gateway B (memory-core) |
|---|---|---|
| `lancedb_bytes` | wächst ab 02:00 deutlich | bleibt klein (Plugin schreibt nicht) |
| `sqlite_total_bytes` | bleibt konstant (eingefroren) | wächst kontinuierlich |
| `recall_counts` Summe | bleibt konstant (Legacy-Daten unangerührt) | wächst weiter |
| Dreaming-Sweep (Sweep-Run) | 02:00 erfolgreich | 03:00 erfolgreich |
| Tagebuch-Einträge | +1 ab heute Nacht | +1 ab heute Nacht |
| `openclaw status` Warnings | 2 (load.paths + mc disabled) | 2 (load.paths + lancedb disabled) |
| Agent-Recall-Latenz | ? | ? |
| Embedding-API-Calls | spike heute Nacht | gleichmäßig |

---

## 7. Was zu klären ist

- **Wer macht's wann?** Beide Seiten **gleichzeitig starten** wäre ideal (T0 identisch). Mindestens innerhalb derselben Stunde.
- **Was tun bei Test-Anomalien?** Wenn ein Cron-Job auf einer Seite fehlschlägt, beide Seiten anhalten und gemeinsam diagnostizieren — der Vergleich ist nur sinnvoll wenn beide gleich lange laufen.
- **Embedding-Kosten**: Auf Gateway A wird der erste lancedb-Sweep heute Nacht 02:00 vermutlich einen Batch Embedding-API-Calls auslösen (text-embedding-3-small, ein paar Cent erwartet). Gateway B macht das schon länger regelmäßig.

---

## 8. Ergebnis-Übergabe

Nach 24h schickst du mir **eine** dieser Optionen:

1. **Snapshot-Ordner als tar** (`tar czf gw-X-runtime.tgz "$REPORT_ROOT"`) — ich ziehe ihn auf meiner Seite auseinander und vergleiche.
2. **Markdown-Report SUMMARY.md mit eingebetteten Tabellen** — beste Lesbarkeit.
3. **Beide jq-Ausgaben aus Abschnitt 4** als plain text — quick&dirty.

Ich mache parallel dasselbe für Gateway A.
