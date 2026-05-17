# Himalaya E-Mail CLI - Verwendungsanleitung

**Dokument:** Workspace-Handbuch  
**Erstellt:** 2026-04-17  
**Gültig für:** OpenClaw System mit GMX-Account  

---

## 🚀 Schnellstart

### 1. Verbindung testen

```bash
# Version prüfen
himalaya --version

# Account-Übersicht
himalaya account list
```

### 2. E-Mails anzeigen

```bash
# Letzte 10 E-Mails im Posteingang
himalaya envelope list --page-size 10

# In bestimmtem Ordner
himalaya envelope list --folder "Gesendet"
```

### 3. E-Mail lesen

```bash
# ID aus der envelope list verwenden
himalaya message read 13892
```

---

## 📋 Ordnerstruktur (GMX)

| Ordner | Beschreibung | CLI-Name |
|--------|--------------|----------|
| Posteingang | Hauptordner | `INBOX` |
| Entwürfe | Ungesendete E-Mails | `Entwürfe` |
| Gesendet | Versandte E-Mails | `Gesendet` |
| Gelöscht | Papierkorb | `Gelöscht` |
| Spamverdacht | Junk-E-Mails | `Spamverdacht` |
| OUTBOX | Ausgang | `OUTBOX` |

---

## 🔍 Nützliche Workflows

### Workflow 1: Tägliche E-Mail-Prüfung

```bash
#!/bin/bash
# email-check.sh - Tägliche E-Mail-Überprüfung

echo "📧 Neue E-Mails:"
himalaya envelope list --page-size 5 --output table

UNREAD=$(himalaya envelope list --output json | jq -r '.[] | select(.flags | contains("seen") | not) | .id' | wc -l)
echo "Ungelesene E-Mails: $UNREAD"
```

### Workflow 2: E-Mail-Suche

```bash
# Nach Absender suchen
himalaya envelope list from:slack.com

# Nach Betreff filtern
himalaya envelope list subject:"Bestätigung"
```

### Workflow 3: E-Mail archivieren

```bash
# E-Mail in Archiv verschieben
himalaya message move 13892 "Archiv"
```

---

## ⚙️ Automatisierung

### Cron-Job: Alle 3 Stunden E-Mails prüfen

```bash
# In crontab -e eintragen
0 */3 * * * /usr/local/bin/himalaya envelope list --page-size 1 >> /var/log/mail-check.log 2>&1
```

### Heartbeat-Integration

```bash
# Für OpenClaw Heartbeat
himalaya envelope list --page-size 5 --output json | jq '. | length'
# Ausgabe: Anzahl der letzten E-Mails
```

---

## 📊 Integration mit ops-hub

### E-Mail-Reports

Die E-Mail-Funktionalität kann in ops-hub für folgende Aufgaben genutzt werden:

- **Alert-Benachrichtigungen** bei Systemproblemen
- **Tägliche Zusammenfassungen** der Cluster-Reports
- **Authentifizierungs-Codes** auslesen (Slack, OpenRouter, etc.)

### Beispiel: Alert-E-Mail senden

```bash
# Automatische Alert-E-Mail bei Node-Ausfall
echo "Subject: Alert - Node Offline
From: monitoring@system.local
To: admin@example.com

Node X ist offline seit $(date)" | himalaya template send
```

---

## 🆘 Troubleshooting

### Fehler: "Connection refused"
- Prüfen: `himalaya account list` zeigt Account an?
- Lösung: Config unter `~/.config/himalaya/config.toml` überprüfen

### Fehler: "Authentication failed"
- Passwort mit `pass` aktualisieren: `pass insert email/gmx-imap`
- Config neu laden: `himalaya account configure`

### Fehler: "Folder not found"
- Ordnernamen sind case-sensitive
- Verfügbare Ordner: `himalaya folder list`

---

## 🔗 Verwandte Dokumente

- [Skill-Dokumentation](../.openclaw/skills/himalaya/SKILL.md)
- [ops-hub Dokumentation](docs/ops-hub/ops-hub.md)
- [System-Dateien Überwachung](docs/ops-hub/system-files.md)

---

*Letzte Aktualisierung: 2026-04-17*  
*Verantwortlich: ops-hub Agent*
