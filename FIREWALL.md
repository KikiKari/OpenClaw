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
| 5001 | TCP | ALLOW | 127.0.0.1 nur (TikTok API - DEFEKT) |
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
| 8080/tcp | TCP | ALLOW | HTTP alt (TikTok/Playwright) |
| 8443/tcp | TCP | ALLOW | HTTPS alt (TikTok/Playwright) |

---

## TikTok/Playwright Anforderungen

**Hinzugefügt 2026-04-06:**
```bash
sudo ufw allow out 80/tcp    # HTTP für TikTok
sudo ufw allow out 443/tcp   # HTTPS für TikTok
sudo ufw allow out 8080/tcp  # HTTP alt
sudo ufw allow out 8443/tcp  # HTTPS alt
```

**Warum:** Playwright/Chromium benötigt ausgehende HTTP/HTTPS-Verbindungen zu TikTok-CDN und Stream-Servern.

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
- `TIKTOK.md` — TikTok Firewall-Anforderungen
