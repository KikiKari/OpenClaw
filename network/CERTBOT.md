# SSL / HTTPS Konfiguration für OpenClaw Gateway

**Stand:** 2026-04-10  
**Node:** Node 1 (Gateway, Hetzner)  
**Zweck:** HTTPS/WSS-Zugriff für OpenClaw Clients

---

## Übersicht

| Komponente | Status |
|------------|--------|
| **certbot** | ✅ Installiert (v2.9.0) |
| **nginx** | ✅ Installiert & aktiv |
| **Ports** | ✅ 80/443 in UFW freigegeben |
| **Domain** | ⏳ Zuweisen / DNS A-Record |

---

## Voraussetzungen

**1. Domain auf Node 1 zeigen lassen**
```bash
# Bei deinem DNS-Provider (z.B. Cloudflare, Netcup):
A-Record: openclaw.lan  →  152.53.145.65
# oder
A-Record: ai.xstoragex.de  →  152.53.145.65
```

**2. DNS-Verifikation**
```bash
dig +short openclaw.lan
# Sollte zurückgeben: 152.53.145.65
```

---

## Automatische SSL-Einrichtung (Certbot)

**Schritt 1: Nginx-Site für OpenClaw erstellen**

```bash
sudo tee /etc/nginx/sites-available/openclaw-gateway << 'EOF'
server {
    listen 80;
    server_name openclaw.lan ai.xstoragex.de;  # Deine Domain(s)

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name openclaw.lan ai.xstoragex.de;

    # SSL-Zertifikate (werden von Certbot eingefügt)
    # ssl_certificate /etc/letsencrypt/live/openclaw.lan/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/openclaw.lan/privkey.pem;

    # SSL-Einstellungen
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;

    # WebSocket Proxy zu OpenClaw Gateway
    location / {
        proxy_pass http://127.0.0.1:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # Health-Check (optional)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
```

**Schritt 2: Site aktivieren**
```bash
sudo ln -sf /etc/nginx/sites-available/openclaw-gateway /etc/nginx/sites-enabled/
sudo mkdir -p /var/www/certbot
sudo nginx -t && sudo systemctl reload nginx
```

**Schritt 3: Zertifikat anfordern**
```bash
# Erstes Zertifikat (interaktiv)
sudo certbot --nginx -d openclaw.lan -d ai.xstoragex.de

# oder für Testing (Staging)
sudo certbot --nginx --staging -d openclaw.lan
```

**Schritt 4: Auto-Renewal testen**
```bash
sudo certbot renew --dry-run
```

---

## Manuelle Let's Encrypt (ohne nginx Plugin)

**Alternativ für mehr Kontrolle:**
```bash
# Standalone (nginx muss kurz gestoppt werden)
sudo certbot certonly --standalone -d openclaw.lan

# Webroot (nginx läuft weiter)
sudo certbot certonly --webroot -w /var/www/certbot -d openclaw.lan
```

---

## WebSocket-Proxy (WSS → WS)

**Wichtig für Mobile Clients:**
- Extern: `wss://openclaw.lan:443` (SSL/TLS)
- Intern: `ws://127.0.0.1:18789` (unverschlüsselt)

**Client-Konfiguration:**
```javascript
// Für Browser/Apps
const ws = new WebSocket('wss://openclaw.lan');

// Für Mobile (Fallback)
const ws = new WebSocket('wss://ai.xstoragex.de');
```

---

## Cron-Job für Auto-Renewal

**Certbot erstellt automatisch:**
```bash
cat /etc/cron.d/certbot
# oder
systemctl list-timers | grep certbot
```

**Manueller Test:**
```bash
sudo certbot renew --dry-run
```

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| `Connection refused` auf 443 | `sudo ufw allow 443/tcp` |
| Certbot: `Failed authorization` | DNS-Propagation abwarten (5-60 Min) |
| nginx: `bind() failed` | Port 80 bereits belegt → `sudo lsof -i :80` |
| Zertifikat abgelaufen | `sudo certbot renew --force-renewal` |
| WebSocket nicht verbunden | nginx `proxy_set_header Connection "upgrade";` prüfen |

---

## Sicherheit

**Empfohlene Headers (in nginx-Server-Block):**
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;

# HSTS (nach erfolgreichem SSL-Test)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

---

## DNS-Empfehlungen

**Cloudflare (empfohlen für DDoS-Schutz):**
- Proxy-Mode: Orange Cloud (schützt IP)
- SSL/TLS: Full (strict)
- WebSocket: Automatisch unterstützt

**Netcup DNS:**
- Eigene DNS-Server nutzen
- A-Record direkt auf 152.53.145.65

---

## Zertifikat-Status prüfen

```bash
# Alle Zertifikate
sudo certbot certificates

# Ablaufdatum
openssl x509 -in /etc/letsencrypt/live/openclaw.lan/cert.pem -noout -dates

# TLS-Handshake testen
echo | openssl s_client -connect openclaw.lan:443 2>/dev/null | openssl x509 -noout -subject -dates
```

---

## Einbetten in Systemd

**nginx Service sicherstellen:**
```bash
sudo systemctl enable nginx
sudo systemctl status nginx
```

**OpenClaw Gateway nach nginx starten:**
```bash
# In /etc/systemd/system/openclaw-gateway.service
[Unit]
Description=OpenClaw Gateway
After=network-online.target nginx.service
Requires=nginx.service

[Service]
ExecStart=/usr/local/bin/openclaw gateway run
Restart=always
User=openclaw

[Install]
WantedBy=multi-user.target
```

---

## 📝 Offene Schritte / TODO

| Schritt | Beschreibung | Status | Blockiert durch |
|---------|--------------|--------|-----------------|
| 1 | **Domain festlegen** | ⏳ Offen | Entscheidung: `ai.xstoragex.de`, `openclaw.lan` oder andere? |
| 2 | **DNS A-Record setzen** | ⏳ Blockiert | Domain muss zuerst festgelegt werden |
| 3 | **DNS-Propagation prüfen** | ⏳ Blockiert | `dig +short <domain>` muss `152.53.145.65` zurückgeben |
| 4 | **Nginx-Site erstellen** | 📋 Ready | Template vorhanden (siehe oben) |
| 5 | **Certbot ausführen** | 📋 Ready | `sudo certbot --nginx -d <domain>` |
| 6 | **Auto-Renewal testen** | 📋 Ready | `sudo certbot renew --dry-run` |
| 7 | **WebSocket-Test** | 📋 Ready | Mobile App/Web-Client verbinden |

**Nächster Schritt:** Domain-Entscheidung treffen

---

## 🚫 Interne TLS-Lösungen (Keine Alternative)

**Entscheidung:** Keine Self-Signed oder Tailscale-HTTPS-Zertifikate einsetzen.

**Begründung:**
- Self-Signed = Browser-Warnungen auf allen Clients
- Private CA = CA-Verteilung an alle Clients notwendig
- Tailscale HTTPS = Nur innerhalb Tailnet nutzbar, mobile Clients außerhalb nicht erreichbar

**Gewählter Weg:** Warten bis öffentliche Domain verfügbar ist → Let's Encrypt mit gültigem, global vertrautem Zertifikat.

---

## 🔄 OpenClaw Gateway Update Status

| Komponente | Version | Status |
|------------|---------|--------|
| Gateway (Node 1) | 2026.4.8 | Installiert |
| Verfügbar | 2026.4.9 | ⏳ Update ausstehend |
| Node 2 | 2026.4.8 | Installiert |
| Node 3 | 2026.4.8 | Installiert |

**Update-Log:**

| Timestamp | Node | Aktion | Status |
|-----------|------|--------|--------|
| 2026-04-10 05:43 | Node 1 (Gateway) | Update 2026.4.8 → 2026.4.9 | ✅ Erfolgreich |
| 2026-04-10 05:50 | Node 2 (Netcup) | Update 2026.4.8 → 2026.4.9 | ✅ Erfolgreich |
| 2026-04-10 05:58 | Node 3 (xNetX) | Update 2026.4.8 → 2026.4.9 | ✅ Erfolgreich |

**Update-Befehle:**
```bash
# Gateway
sudo npm install -g openclaw@2026.4.9

# Nodes (via SSH)
ssh root@<node-ip> "npm install -g openclaw@2026.4.9"
```

**Aktueller Cluster-Status:**
```
Node 1 (Gateway):  OpenClaw 2026.4.9 (0512059) ✅
Node 2 (Netcup):   OpenClaw 2026.4.9 (0512059) ✅
Node 3 (xNetX):    OpenClaw 2026.4.9 (0512059) ✅
```

---

**Dokumentation erstellt:** 2026-04-10  
**Letzte Aktualisierung:** 2026-04-10  
**Zugehörig:** Node 1 Gateway, Certbot, Let's Encrypt
