# pplx-tools — Perplexity Pro im headless Codespace

Authentifiziert den Perplexity-MCP-Daemon im Codespace `verbose-waddle` als **Pro**,
ohne Browser-Login (der an Cloudflare auf der Datacenter-IP scheitert). Stattdessen
wird ein lokal exportierter Session-Cookie in den Vault injiziert.

> **Bewiesen:** Cloudflare blockt nur *unauthentifizierte* Calls von der Codespace-IP.
> Mit gültiger Session laufen `perplexity_search` & Co. über impit (HTTP) durch.

## Dateien
| Datei | Zweck |
|---|---|
| `pplx-refresh.sh` | **Hauptbefehl** — injiziert Cookie, triggert Reinit, verifiziert |
| `pplx-inject.mjs` | schreibt den Cookie in den Vault (von refresh aufgerufen) |
| `pplx-setup.sh` | installiert die zur Extension passende Chromium-Revision (idempotent) |
| `pplx-status.sh` | zeigt den aktuellen Auth-Status |

## Session erneuern (wenn der Cookie abläuft, ~monatlich)
1. **Lokaler Browser** auf perplexity.ai eingeloggt → F12 → **Application → Cookies →
   `https://www.perplexity.ai`** → Zeile `__Secure-next-auth.session-token` anklicken →
   unten „Cookie Value" (Häkchen *Show URL-decoded* AUS) → Rohwert (`eyJ…`) kopieren.
2. Wert in `~/pplx-cookies.txt` einfügen (nur den Wert), speichern.
3. Im Codespace:
   ```bash
   ~/pplx-tools/pplx-refresh.sh
   ```
   Erwartet: `✅ authenticated — tier: Pro`.
4. Danach kannst du `~/pplx-cookies.txt` löschen (enthält den Roh-Token):
   ```bash
   shred -u ~/pplx-cookies.txt 2>/dev/null || rm -f ~/pplx-cookies.txt
   ```

## Status prüfen
```bash
~/pplx-tools/pplx-status.sh
```

## Hinweise
- **„Sync All IDEs" nicht nötig** — der Codespace-Daemon wird direkt authentifiziert.
- Die Panel-Warnung *„Models refresh failed: Cloudflare challenge"* ist kosmetisch:
  Der periodische Models-Refresh nutzt den Browser-/Turnstile-Pfad (scheitert auf der
  Datacenter-IP). Suche & Auth funktionieren trotzdem.
- Passphrase wird nie geraten — sie wird zur Laufzeit aus der Umgebung des laufenden
  Daemons gelesen (`/proc/<pid>/environ`).
