# Himalaya Email CLI Skill

**Name:** himalaya-email  
**Beschreibung:** E-Mail-Verwaltung via IMAP/SMTP mit dem Himalaya CLI  
**Version:** 1.0.0  
**Autor:** ops-hub  

---

## 🎯 Zweck

Dieser Skill ermöglicht das Abrufen, Lesen, Schreiben und Verwalten von E-Mails über das Terminal mittels Himalaya CLI. Unterstützt GMX und andere IMAP/SMTP-Anbieter.

---

## 📋 Voraussetzungen

- Himalaya CLI installiert (`himalaya --version`)
- Konfigurationsdatei unter `~/.config/himalaya/config.toml`
- IMAP/SMTP-Zugangsdaten konfiguriert

---

## 🔧 Konfiguration

Die Konfiguration liegt unter `~/.config/himalaya/config.toml`:

```toml
[accounts.gmx]
email = "deine-email@gmx.de"
display-name = "Dein Name"
default = true

backend.type = "imap"
backend.host = "imap.gmx.net"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "deine-email@gmx.de"
backend.auth.type = "password"
backend.auth.cmd = "pass show email/gmx-imap"

message.send.backend.type = "smtp"
message.send.backend.host = "mail.gmx.net"
message.send.backend.port = 587
message.send.backend.encryption.type = "start-tls"
message.send.backend.login = "deine-email@gmx.de"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "pass show email/gmx-smtp"
```

---

## 📝 Befehle

### Grundlegende Operationen

| Befehl | Beschreibung | Beispiel |
|--------|--------------|----------|
| `himalaya --version` | Version anzeigen | - |
| `himalaya account list` | Konfigurierte Accounts anzeigen | - |
| `himalaya folder list` | Verfügbare Ordner auflisten | - |

### E-Mails abrufen

| Befehl | Beschreibung | Optionen |
|--------|--------------|----------|
| `himalaya envelope list` | E-Mails im INBOX anzeigen | `--page-size 5` |
| `himalaya envelope list --folder "Gesendet"` | E-Mails in bestimmtem Ordner | `--folder NAME` |
| `himalaya envelope list from:absender@domain.com` | Nach Absender filtern | Suchparameter |

### E-Mails lesen

| Befehl | Beschreibung | Optionen |
|--------|--------------|----------|
| `himalaya message read <ID>` | E-Mail lesen (Plain Text) | `<ID> = Nummer aus envelope list` |
| `himalaya message read <ID> --full` | Vollständige E-Mail mit Headern | `--full` |
| `himalaya message export <ID>` | E-Mail als MIME exportieren | - |

### E-Mails schreiben

| Befehl | Beschreibung | Hinweis |
|--------|--------------|---------|
| `himalaya message write` | Neue E-Mail schreiben | Öffnet $EDITOR |
| `himalaya message reply <ID>` | Auf E-Mail antworten | `--all` für Reply-All |
| `himalaya message forward <ID>` | E-Mail weiterleiten | - |

### E-Mails verwalten

| Befehl | Beschreibung | Beispiel |
|--------|--------------|----------|
| `himalaya message move <ID> "Ordner"` | E-Mail verschieben | `move 42 "Archiv"` |
| `himalaya message copy <ID> "Ordner"` | E-Mail kopieren | `copy 42 "Wichtig"` |
| `himalaya message delete <ID>` | E-Mail löschen | - |
| `himalaya flag add <ID> --flag seen` | Flag setzen | `seen`, `flagged`, etc. |

### Anhänge

| Befehl | Beschreibung | Optionen |
|--------|--------------|----------|
| `himalaya attachment list <ID>` | Anhänge einer E-Mail auflisten | - |
| `himalaya attachment download <ID>` | Anhänge herunterladen | `--dir ~/Downloads` |

---

## 📊 Output-Formate

Die meisten Befehle unterstützen verschiedene Ausgabeformate:

```bash
himalaya envelope list --output json    # JSON-Format
himalaya envelope list --output plain   # Plain-Text (Standard)
himalaya envelope list --output table   # Tabellenformat
```

---

## 🔍 Beispiele

### Tägliche E-Mail-Überprüfung

```bash
# Alle Accounts anzeigen
himalaya account list

# Letzte 5 E-Mails im Posteingang
himalaya envelope list --page-size 5

# E-Mail mit ID 13892 lesen
himalaya message read 13892
```

### Automatisierung

```bash
# Ungelesene E-Mails zählen (JSON-Output parsen)
himalaya envelope list --output json | jq '.[] | select(.flags | contains("seen") | not)' | wc -l

# Letzte E-Mail exportieren
LATEST=$(himalaya envelope list --page-size 1 --output json | jq -r '.[0].id')
himalaya message export $LATEST > letzte_email.eml
```

### Mehrere Accounts

```bash
# Account 'arbeit' verwenden
himalaya --account arbeit envelope list

# Account 'privat' verwenden
himalaya --account privat envelope list
```

---

## 🐛 Debuggen

Bei Problemen:

```bash
# Debug-Logging aktivieren
RUST_LOG=debug himalaya envelope list

# Vollständiger Trace mit Backtrace
RUST_LOG=trace RUST_BACKTRACE=1 himalaya envelope list
```

---

## 🔒 Sicherheit

- Passwörter werden **niemals** im Klartext in der Config gespeichert
- Nutze `pass` (Password Store) oder Keyring: `backend.auth.cmd = "pass show email/imap"`
- Config-Datei-Berechtigungen: `chmod 600 ~/.config/himalaya/config.toml`

---

## 📚 Weiterführende Links

- [Himalaya GitHub](https://github.com/pimalaya/himalaya)
- [MML Syntax für E-Mail-Komposition](./references/message-composition.md)
- [Konfigurationsreferenz](./references/configuration.md)

---

*Skill erstellt: 2026-04-17*  
*Zuständig: ops-hub Agent*
