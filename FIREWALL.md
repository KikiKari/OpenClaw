# Firewall Konfiguration (UFW)

**Letzte Aktualisierung:** 2026-04-06
**Status:** ✅ Aktiv

---

## UFW Status

```bash
sudo ufw status verbose
```

### Eingehend (Incoming)

| Port | Protokoll | Aktion | Beschreibung |
|------|-----------|--------|--------------|
| 22/tcp | TCP | ALLOW | SSH |
| 80/tcp | TCP | ALLOW | HTTP |
| 443/tcp | TCP | ALLOW | HTTPS |
| 993/tcp | TCP | ALLOW | IMAPS |
| 51820/udp | UDP | ALLOW | WireGuard VPN |
| 18789/tcp | TCP | ALLOW | OpenClaw Gateway |

### Ausgehend (Outgoing)

| Port | Protokoll | Aktion | Beschreibung |
|------|-----------|--------|--------------|
| 53/tcp | TCP | ALLOW | DNS |
| 53/udp | UDP | ALLOW | DNS |
| 80/tcp | TCP | ALLOW | HTTP |
| 123/udp | UDP | ALLOW | NTP |
| 443/tcp | TCP | ALLOW | HTTPS |
| 587/tcp | TCP | ALLOW | SMTP |
| 853/tcp | TCP | ALLOW | DNS-over-TLS |

---

## TikTok/Playwright Anforderungen (2026-06-21)

Der aktive Dispatcher öffnet keinen TikTok-API-Port. Gateway und ausführende Nodes benötigen lediglich DNS sowie ausgehendes HTTPS zu TikTok- und TikTok-CDN-Hosts. Port 80 kann für normale HTTP-Weiterleitungen erlaubt bleiben; 8080/8443 sind keine TikTok-Laufzeitanforderung.

Node-Aufträge laufen über die bestehende OpenClaw-Verbindung (`exec host=node`), nicht über zusätzliche TikTok-Tunnel oder eingehende Ports.

---

## Standardregeln

```bash
Default: deny (incoming), allow (outgoing), deny (routed)
```

---

## Nützliche Befehle

```bash
# Status prüfen
sudo ufw status verbose

# Regel hinzufügen
sudo ufw allow <port>/<proto>

# Regel entfernen
sudo ufw delete allow <port>/<proto>

# UFW deaktivieren (Vorsicht!)
sudo ufw disable

# UFW aktivieren
sudo ufw enable
```

---

## Referenzen

- `INFRASTRUCTURE.md` — Netzwerk-Übersicht
- `SYSTEM.md` — System-Dokumentation
- `skills/tiktok-live/references/TIKTOK.md` — TikTok-Laufzeit und Netzwerk
