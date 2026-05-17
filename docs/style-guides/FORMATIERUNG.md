# FORMATIERUNG — Technische Darstellung

**Stand:** 2026-04-09
**Grund:** Falsch formatierte Codeboxen haben Cluster beschädigt

---

## VERBOTENE FORMATIERUNGEN

### ❌ Codeboxen mit ausführbarem Inhalt
```bash
# VERBOTEN — Kann direkt kopiert/ausgeführt werden
chmod 400 /home/openclaw/.config/openclaw/pws
```

### ❌ Implizite Annahmen
```bash
# VERBOTEN — Keine Node/Benutzer-Angabe
ssh root@10.10.0.2
```

### ❌ Relative Pfade
```bash
# VERBOTEN — Nicht eindeutig
~/.ssh/config
```

---

## ERLAUBTE FORMATIERUNGEN

### ✅ Beschreibende Text-Blöcke

**NODE:** Gateway (v2202604104722446711)  
**Benutzer:** openclaw  
**Aktion:** Setze Lese-Rechte auf Passwort-Datei  
**Pfad:** /home/openclaw/.config/openclaw/pws  
**Ziel-Rechte:** 400 (nur Owner lesbar)

---

### ✅ Tabellen für Übersichten

- Node-Topologie & Fail2Ban-Status (Node 1/2/3)

| Node | Benutzer | Pfad | Rechte | Zweck |
|------|----------|------|--------|-------|
| Gateway | openclaw | /home/openclaw/.config/openclaw/pws | 400 | Passwort-Schutz |

---

### ✅ Aufzählungen mit Kontext

**System:** Node 2 (Netcup VPS)  
**Aufgabe:** Xvfb installieren  
**Schritte:**
1. Package-Liste aktualisieren
2. Xvfb Package installieren
3. Service starten  
**KEINE konkreten Befehle — nur Beschreibungen**

---

## PFLICHTELEMENTE

Jede technische Empfehlung MUSS enthalten:

1. **NODE** — Vollständiger Hostname oder ID
2. **BENUTZER** — Unter welchem User ausgeführt
3. **ABSOLUTER PFAD** — Keine Tilden (~), keine Umgebungsvariablen
4. **BESCHREIBUNG** — Was soll passieren, nicht wie
5. **RISIKO** — Was könnte schiefgehen

---

## BEISPIELE

### Beispiel 1: Rechte ändern

**FALSCH:**
```
chmod 400 ~/.config/openclaw/pws
```

**RICHTIG:**
**NODE:** Gateway  
**Benutzer:** openclaw  
**Datei:** /home/openclaw/.config/openclaw/pws  
**Aktuelle Rechte:** 600  
**Ziel-Rechte:** 400 (nur Lesen für Owner)  
**Grund:** Schutz vor unautorisierten Änderungen  
**Risiko:** Danach keine automatischen Updates möglich

---

### Beispiel 2: SSH-Verbindung

**FALSCH:**
```
ssh root@10.10.0.2
```

**RICHTIG:**
**NODE:** Gateway → Node 2  
**Quell-Benutzer:** openclaw  
**Ziel-Benutzer:** root  
**IP:** 10.10.0.2  
**Auth-Methode:** SSH-Key  
**Key-Datei:** /home/openclaw/.ssh/id_ed25519

---

## STRUKTUR-VORLAGEN

### Für Datei-Operationen:
```
NODE: [Name]
Benutzer: [User]
Datei: [absoluter Pfad]
Aktion: [beschreibung]
Grund: [warum]
Risiko: [was kann schiefgehen]
```

### Für Netzwerk-Operationen:
```
QUELLE: [Node] / [Benutzer]
ZIEL: [Node] / [IP] / [Port]
Protokoll: [ssh/tls/wireguard]
Zweck: [beschreibung]
```

### Für Installations-Anweisungen:
```
SYSTEM: [Node]
Paket: [Name]
Schritte: [1, 2, 3...]
Hinweis: [wichtige Details]
```

---

**Letzte Aktualisierung:** 2026-04-09
**Diese Formatierung gilt ab sofort.**
