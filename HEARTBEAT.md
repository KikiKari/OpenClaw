# HEARTBEAT.md – Main-Checkliste

## Verbindliche Ausführungsregeln

- Innerhalb der Sandbox ausschließlich Pfade unter `/workspace/...` verwenden.
- Keine Hostpfade innerhalb des Sandbox-Containers verwenden.
- Hostdiagnosen einzeln über den gepaarten Node `xnetx` mit `system.run` ausführen.
- Alternativ nur einen ausdrücklich auf Gateway/Host gerichteten Exec verwenden.
- Sandboxwerte von `ps`, `uptime`, `journalctl`, `vmstat` oder `free` niemals als Hostwerte ausgeben.
- Pro Tool-Aufruf exakt einen Befehl ausführen.
- Keine Pipes, Umleitungen, Subshells oder sonstige zusammengesetzte Shell-Befehle verwenden.
- Prozessausgabe erst nach dem Tool-Aufruf auf zehn Einträge begrenzen.
- Keine automatische Reparatur, Bereinigung oder Migration starten.

## Einzeln auszuführende Hostprüfungen

1. `vmstat`
2. `ps aux`
3. `df -h`
4. `free -h`
5. `uptime`
6. `journalctl -n 200 -q`

Zusätzlich:

- Cron-Status über das Cron-Tool prüfen.
- Agenten über das Agents-Tool prüfen.
- Nodes ausschließlich mit `action: status` prüfen.
- Keine erfundenen oder aus Sandboxwerten abgeleiteten Hostzustände melden.

## Abschluss

- Bei Problemen einen kurzen Fehlerstatus mit dem fehlgeschlagenen Check liefern.
- Bei vollständig erfolgreichem Lauf exakt `HEARTBEAT_OK` als finale Textantwort liefern.
- `heartbeat_respond` gilt nicht als Ersatz für diese finale Antwort.
