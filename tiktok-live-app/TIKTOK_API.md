# TikTok Monitoring System

Übersicht über das TikTok Live-Monitoring System und die verfügbaren API-Endpunkte.

---

## API Endpoints (Node 1, Port 5001)

### Status-Abfragen

| Endpunkt | Methode | Beschreibung |
|----------|---------|--------------|
| `/tiktok/status/example_creator` | GET | Prüft ob der User "example_creator" live ist |
| `/tiktok/status/example_creator` | GET | Prüft ob der User "example_creator" live ist |

### Response Format

```json
{
  "live": true/false,
  "stream_url": "...",
  "vlc_links": [...]
}
```

**Felder:**
- `live` (boolean): Gibt an, ob der User aktuell live streamt
- `stream_url` (string): Direkte Stream-URL (falls live)
- `vlc_links` (array): Liste der extrahierten VLC-kompatiblen Links

**Beispiel - Live:**
```json
{
  "live": true,
  "stream_url": "https://pull-flv...tiktokcdn.com/...",
  "vlc_links": [
    "https://pull-flv-f1...tiktokcdn.com/stage/stream-1234.flv"
  ]
}
```

**Beispiel - Offline:**
```json
{
  "live": false,
  "stream_url": null,
  "vlc_links": []
}
```

---

## VLC Link Extraktion

### Automatische Extraktion

- Stream URLs werden automatisch extrahiert, wenn ein User live geht
- Unterstützte Formate: FLV, HLS

### Speicherung

Extrahierte VLC-Links werden gespeichert in:

```
memory/vlc-links-YYYY-MM-DD.md
```

**Format:**
```markdown
## VLC Links - 2026-04-03

### example_creator
- Zeit: 19:30
- Link: https://pull-flv-f1...tiktokcdn.com/...

### example_creator
- Zeit: 20:15
- Link: https://pull-flv-f2...tiktokcdn.com/...
```

---

## HEARTBEAT Integration

Das System prüft automatisch alle 30 Minuten den Live-Status der überwachten TikTok-Accounts.

### Ablauf

1. **Alle 30 Minuten:** Prüfe Live-Status aller konfigurierten User
2. **Bei `live=true`:**
   - Extrahiere VLC-kompatible Stream-Links
   - Speichere Ergebnisse in `memory/vlc-links-YYYY-MM-DD.md`
   - Optional: Sende Benachrichtigung

### Monitoring-Logik

```
┌─────────────────┐
│   HEARTBEAT     │ (alle 30 Min)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GET /tiktok/    │
│ status/{user}   │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
 live=true  live=false
    │         │
    ▼         │
┌────────┐    │
│Extrahie│    │
│ VLC    │    │
│ Links  │    │
└───┬────┘    │
    │         │
    ▼         │
┌────────┐    │
│Speicher│◄───┘
│ in MD  │
└────────┘
```

---

## Technische Details

### Python Flask App

| Eigenschaft | Wert |
|-------------|------|
| **Dateipfad** | `/opt/tiktok-api/app.py` |
| **Framework** | Flask |
| **Port** | 5001 |
| **Node** | Node 1 |

### Prozess-Status prüfen

```bash
ps aux | grep app.py
```

Ergebnis sollte zeigen:
```
openclaw  12345  0.0  1.2  98765 12345 ?  S  19:00   0:01 python /opt/tiktok-api/app.py
```

### Autostart-Konfiguration

#### Option 1: systemd Service

Datei: `/etc/systemd/system/tiktok-api.service`

```ini
[Unit]
Description=TikTok Monitoring API
After=network.target

[Service]
Type=simple
User=openclaw
WorkingDirectory=/opt/tiktok-api
ExecStart=/usr/bin/python3 /opt/tiktok-api/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Aktivierung:**
```bash
sudo systemctl enable tiktok-api
sudo systemctl start tiktok-api
```

#### Option 2: Cron @reboot

```bash
@reboot /usr/bin/python3 /opt/tiktok-api/app.py >> /var/log/tiktok-api.log 2>&1
```

### API-Test

```bash
# Teste example_creator
curl http://localhost:5001/tiktok/status/example_creator

# Teste example_creator
curl http://localhost:5001/tiktok/status/example_creator
```

---

## Server-Details

| Server | URL | Port |
|--------|-----|------|
| Node 1 | http://<node1-ip> | 5001 |
| Local | http://localhost | 5001 |

---

*Letzte Aktualisierung: 2026-04-03*
