# DataSheet: Node 4 (Webhosting)

## Übersicht
**Typ:** Webhosting 1000 SE a1 (Shared Hosting, nicht VPS)  
**Provider:** Netcup  
**Standort:** Nürnberg  
**Produkt-ID:** hosting130844

---

## Netzwerk & Domains

### Webserver
| Attribut | Wert |
|----------|------|
| **Hostname** | a2e16.netcup.net |
| **IPv4** | 91.204.46.22 |
| **IPv6** | 2a03:4000:30:77a2::13:844 |

### MySQL-Server
| Attribut | Wert |
|----------|------|
| **Hostname** | mysql2e17.netcup.net |
| **IPv4 (extern)** | 91.204.46.23 |
| **IPv4 (intern)** | 10.35.46.23 |

### Mail-Server (MX)
| Attribut | Wert |
|----------|------|
| **Hostname** | mx2e18.netcup.net |
| **IPv4** | 91.204.46.24 |
| **Protokolle** | SMTP/S, IMAP/S, POP3/S |

---

## Domain: xstoragex.de

| Attribut | Wert |
|----------|------|
| **Hosting-Typ** | Webseite |
| **Dokumentenstamm** | /cache |
| **Bevorzugte Domain** | xstoragex.de |
| **IP-Adresse** | 91.204.46.22 |
| **Systembenutzer** | hosting130844 |

**Mögliche Verwendung:**  
Datei-Download-Seite für /home/share (Node 3) - Verknüpfung zwischen Node 3 (VPS) und Node 4 (Webhosting) für File-Storage/Sharing.

---

## Technische Spezifikationen

### PHP
| Attribut | Wert |
|----------|------|
| **Versionen** | 7.2 / 7.3 / 7.4 / 8.0 |
| **Memory Limit** | 128 MB |
| **Upload Filesize** | 8 MB |
| **Execution Time** | 180 s |
| **Fast-CGI** | Ja |
| **Opcode-Cache** | Ja |

### Speicher & Limits
| Attribut | Wert |
|----------|------|
| **Web-Speicher** | 25 GB SSD |
| **Mail-Speicher** | 25 GB SSD |
| **Traffic** | Kostenlos (unbegrenzt) |
| **Datenbanken** | 1 |
| **Cronjobs** | 1 |

### E-Mail
| Attribut | Wert |
|----------|------|
| **E-Mail Adressen** | 100 |
| **E-Mail Weiterleitungen** | 100 |
| **Autoresponder** | Ja |
| **Catchall** | Ja |
| **Spamfilter** | Ja |
| **Virenfilter** | Ja |
| **Webmail mit Sieve** | Ja |

### Domains & DNS
| Attribut | Wert |
|----------|------|
| **Inklusivdomains** | 1 x .de |
| **Subdomains** | 100 |
| **Externe Domains** | 1 |
| **Wildcard Subdomains** | Ja |
| **DNS Records** | A, AAAA, MX, CNAME, TXT, SRV, NS |
| **DNSSEC** | Ja (wenn TLD unterstützt) |
| **Eigene IPv6** | Ja |

### Features
| Feature | Verfügbar |
|---------|-----------|
| FTP / FTPES / SSH | ✅ Ja |
| Web-Dateimanager | ✅ Ja |
| Individuelle Fehlerseiten | ✅ Ja |
| Logdateien-Zugriff | ✅ Ja |
| Git | ✅ Ja |
| SSL-Zertifikate (Let's Encrypt) | ✅ unbegrenzt |
| nginx-Proxy | ✅ Wahlweise |
| Document-Root anpassen | ✅ Ja |

### Nicht verfügbar (Upgrade nötig)
| Feature | Benötigt |
|---------|----------|
| **Python** | Webhosting 4000+ |
| **NodeJS** | Webhosting 4000+ |
| **Ruby on Rails** | Webhosting 4000+ |
| **Parallele App-Installationen** | Webhosting 2000+ |

---

## Verwaltung

### Plesk Panel
- **URL:** via Netcup Kundenpanel
- **Zugriff:** Domain-Auswahl → Verwaltung

### Verfügbare Domains im Panel
- xstoragex.de

---

## Verbindung zu Node 3

**Szenario:** Node 3 (VPS) bietet /home/share für Datei-Uploads  
**Idee:** Node 4 (Webhosting) als Download-Frontend via xstoragex.de

**Umsetzungsoptionen:**
1. **SFTP/SSH:** Node 4 → Node 3 (automatisiert)
2. **rsync:** Dateien spiegeln
3. **API:** Eigene Download-Oberfläche

**HTTPS-Proxy zu Node 1 (Geplant):**
Möglich via nginx Reverse Proxy (wenn Upgrade auf Webhosting 4000+):
```
[User] → https://xstoragex.de → [Node 4 nginx] → [WireGuard] → [Node 1 Gateway]
```

---

## Status
| Komponente | Status |
|------------|--------|
| **Webserver** | ✅ Aktiv |
| **MySQL** | ✅ Aktiv |
| **Mail** | ✅ Aktiv |
| **Domain xstoragex.de** | ✅ Aktiv |
| **SSL** | ✅ Let's Encrypt |

---

**Zuletzt aktualisiert:** 2026-04-10 (Node-Nummer korrigiert: 4 ← 5)
