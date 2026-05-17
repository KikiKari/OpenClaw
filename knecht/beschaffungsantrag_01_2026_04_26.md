---
Titel: Beschaffungsantrag: Sandbox-Umgebung `knecht` – fehlende SysTools, OpenClaw & Logging
Priorität: Hoch
Datum: 2026-04-26
Zeit: 01:41 CEST
Korrelations-ID: hb-2026-04-26-0129
Betroffener Agent/System: `knecht` Sandbox

## Problembeschreibung

Die aktuelle Sandbox-Umgebung für Agent `knecht` ist stark eingeschränkt:
- **Fehlende Systemwerkzeuge:** Programme wie `free`, `vmstat`, `ps`, `journalctl` sind **nicht verfügbar** (Command not found). Dies verhindert grundlegende Systemprüfungen und Debugging.
- **OpenClaw-Befehle nicht ausführbar:** `openclaw doctor`, `openclaw status` etc. werden nicht gefunden. Operative Wartung ist blockiert.
- **Fehlendes Logging:** Systemprotokolle (`journalctl`, `/var/log/*`) sind nicht abrufbar (`logs-unavailable`).
- **Eingeschränkte Prozessinformationen:** Nur rudimentäre Daten über `/proc` verfügbar.

## Aktueller Status (eingeschränkt messbar)
- **Disk:** `/workspace` ca. 11% genutzt (OK)
- **Memory:** Gesamtspeicher ca. 15.6 GB, verfügbar ca. 13.5 GB (OK)
- **Load:** 0.84 0.93 0.82 (OK)

## Anforderung / Lösungsansätze

1.  **Dauerhafte Verfügbarkeit der Systemwerkzeuge** (`free`, `vmstat`, `ps`, `journalctl`) in der Sandbox. Ggf. Anpassung des PATH oder Installation.
2.  **Vollständige OpenClaw-Installation/Konfiguration** in der Sandbox sicherstellen, damit operative Befehle ausführbar sind. Ggf. Berechtigungen prüfen/korrigieren.
3.  **Robuste Prozess- und Systeminformationen:** Dauerhafte Verfügbarkeit von `vmstat` und `ps` sicherstellen. `/proc`-Metriken beibehalten, aber als Fallback ansehen.
4.  **Verfügbarkeit von Logging:** Konfiguration für les-/abrufbares Logging (z.B. via Journald, Syslog) einrichten.

## Nächste Schritte / Handlungsempfehlung

Bitte um **dringende Prüfung und Behebung** der genannten Mängel in der `knecht`-Sandbox-Umgebung. Ohne diese Grundlagen sind valide Heartbeat-Checks und operative Wartung nicht möglich.

---
Erstellt vom Agent `knecht`.
---
