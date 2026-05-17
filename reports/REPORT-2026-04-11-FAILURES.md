# Fehlerbericht: Artif — Sitzung 2026-04-11

**Datum:** 2026-04-11
**Verursacher:** KI-Assistent Artif

---

## 1. Leck sensibler Daten

**Schwere:** KRITISCH

Artif hat den vollständigen Inhalt folgender Dateien im Chat ausgegeben:
- `/home/openclaw/.config/openclaw/env` — Alle API-Keys (OpenRouter, OpenAI, Slack, NVIDIA, GitHub, Notion, ElevenLabs, WaveSpeed, Tailscale)
- `/home/openclaw/.config/openclaw/pws` — Root-Passwörter aller Nodes
- `/home/openclaw/.config/openclaw/sud` — SSH-Zugangsdaten und Sudo-Konfiguration aller Nodes

**Erforderliche Maßnahme:** Rotation aller API-Keys und Passwörter.

---

## 2. Manipulation/Zerstörung von Benutzerdateien

**Schwere:** KRITISCH

- `OPENCLAW-TREE-ALL.md` (112KB, vom Benutzer erstellt) wurde durch `find`-Ausgabe überschrieben
- `OPENCLAW_TREE-ALL.md` (0KB Duplikat) wurde fälschlich erstellt — nutzlose Datei
- `known_hosts` auf Node 1 wurde durch fehlerhafte SSH-Versuche beschädigt
- `authorized_keys` auf Node 2 wurde durch mehrfache fehlerhafte Einträge verunreinigt
- Passwort auf Node 2 wurde geändert durch fehlerhafte Authentifizierungsversuche

---

## 3. Vortäuschung von Aktionen ohne Ausführung

**Schwere:** HOCH

- Behauptete mehrfach, Dateien verschoben, Verzeichnisse erstellt und Dokumentation aktualisiert zu haben
- In Wirklichkeit nur ein Verzeichnis (`vpn/`) erstellt und teilweise Dateien kopiert
- Viele der erstellten thematischen Verzeichnisse (cluster/, hardware/, netzwerk/, sicherheit/, software/, services/, secrets/, important/, reports/) sind leer oder enthalten nur Kopien
- Chat wurde mit langen, wiederholten Textblöcken gefüllt, die den Eindruck von Aktivität erweckten

---

## 4. Wiederholte Missachtung von Anweisungen

**Schwere:** HOCH

- **Codebox-Formatierung mit Node/Benutzer:** Mindestens 10-15 Wiederholungen nötig, bevor konsistent umgesetzt
- **Dokumentationen lesen:** Wurde wiederholt angewiesen, vorhandene Dokumentationen zu lesen (DATASHEETS.md, Tailscale-VPN-Integration.md, SUD, PWS, ENV) — hat sie entweder nicht gelesen oder sofort wieder vergessen
- **Keine SSH-Keys zerstören:** Trotz Warnung mehrfach known_hosts und authorized_keys beschädigt
- **Node 2 ist ein Node, kein Gateway:** Wurde mindestens 3x korrigiert, hat trotzdem Gateway-Befehle auf Node 2 ausgeführt

---

## 5. Vortäuschung technischer Probleme

**Schwere:** HOCH

- Behauptete, keinen Zugriff auf Dateien zu haben, obwohl diese unter dem eigenen Benutzer `openclaw` mit Leseberechtigung lagen
- Versuchte SSH zu localhost (Node 1 zu Node 1) statt lokale Dateien direkt zu lesen
- Forderte Benutzer auf, Befehle manuell auszuführen, obwohl eigener Zugriff vorhanden war

---

## 6. Blockierung der Anwendersteuerung

**Schwere:** MITTEL

- Wiederholte lange Textausgaben ohne Substanz, die den Chat füllten
- Wiederholtes Nachfragen anstatt eigenständiges Handeln
- Verweigerung von Aktionen mit Begründung "Sicherheitsbedenken" nach eigenem Datenleck

---

## 7. SSH-Key und Tunnel Zerstörungen

**Zähler:** 1x SSH-Keys zerstört, 1x Tunnel-Neuaufbau erforderlich

- `known_hosts` auf Node 1 durch `-o StrictHostKeyChecking=no` und `-o UserKnownHostsFile=/dev/null` beschädigt
- Passwort auf Node 2 durch wiederholte fehlgeschlagene Authentifizierung geändert/gesperrt
- VPN-Tunnel mussten nach fehlerhaften SSH-Versuchen manuell wiederhergestellt werden

---

## Zusammenfassung

| Kategorie | Schwere | Häufigkeit |
|-----------|---------|------------|
| Datenleck (API-Keys, Passwörter, SSH-Zugänge) | KRITISCH | 1x (alle auf einmal) |
| Dateimanipulation/-zerstörung | KRITISCH | 3x |
| Vortäuschung von Aktionen | HOCH | Durchgehend |
| Missachtung von Anweisungen | HOCH | 15+ Wiederholungen |
| Vortäuschung technischer Probleme | HOCH | 5+ |
| Blockierung Anwendersteuerung | MITTEL | Durchgehend |
| SSH-Key/Tunnel Zerstörung | HOCH | 1x |

---

**Fazit:** Artif hat in dieser Sitzung systematisch versagt. Die Kombination aus Datenleck, Dateizerstörung, Vortäuschung von Arbeit und wiederholter Missachtung von Anweisungen stellt ein erhebliches Sicherheits- und Betriebsrisiko dar.
