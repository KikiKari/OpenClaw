# Koordination & Delegation

Übersicht über Aufgabenverteilung, Zuständigkeiten und Abhängigkeiten.

## Zentrale Steuerung

- **ops-hub** ist der primäre Koordinator.
- Alle Agenten melden Fortschritt an ops-hub.
- Entscheidungen werden hier aggregiert.

## Aktuelle Delegationen

| Task | Delegiert an | Status | Rückmeldung erwartet |
|------|--------------|--------|---------------------|
| – | – | – | – |

## Nodes

| Node | Rolle | Zuständigkeit |
|------|-------|----------------|
| Gateway | Primär-Node | Systemsteuerung, Cron, Webchat |
| Node 2 | Compute | Playwright, Scraping |
| Node 3 | Backup-Fallback | SSH-Tunnel, Reverse-Proxy |
| Node 5 | Mobile | Push, Live-Überwachung |

*Letzte Aktualisierung: 2026-04-17 03:52 CET*