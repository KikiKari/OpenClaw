# OpenClaw Node Autostart für Termux (Node 5 - Redmi)

**Stand:** 2026-04-10  
**Gerät:** Redmi Note 11 (Node 5)  
**Zweck:** Automatischer Start von `openclaw node run` nach Termux-Boot

---

## Installation (auf dem Handy ausführen)

### Schritt 1: Boot-Skript-Verzeichnis erstellen

```bash
mkdir -p ~/.termux/boot
```

### Schritt 2: Skript kopieren

Das Skript liegt auf dem Gateway unter:
```
/home/openclaw/.openclaw/workspace/scripts/openclaw-node-autostart-termux.sh
```

**Option A - Über SCP (vom Gateway):**
```bash
# Auf Node 1 (Gateway) ausführen:
scp /home/openclaw/.openclaw/workspace/scripts/openclaw-node-autostart-termux.sh root@10.10.0.5:/data/data/com.termux/files/home/.termux/boot/openclaw-node.sh
```

**Option B - Manuell kopieren:**
1. Dateiinhalt unten kopieren
2. In Termux: `nano ~/.termux/boot/openclaw-node.sh`
3. Einfügen und speichern (Ctrl+O, Ctrl+X)

### Schritt 3: Skript ausführbar machen

```bash
chmod +x ~/.termux/boot/openclaw-node.sh
```

### Schritt 4: Testen

```bash
# Skript manuell starten
~/.termux/boot/openclaw-node.sh

# tmux Session anschauen
tmux attach -t openclaw-node

# Aus tmux herauskommen: Ctrl+B, dann D (detach)
```

### Schritt 5: Autostart aktivieren

**Termux:Boot App installieren (wichtig!):**
```
Google Play Store oder F-Droid:
→ "Termux:Boot" installieren
```

**Ohne Termux:Boot App** funktioniert der Autostart NICHT nach einem Neustart.

---

## Verwaltung

| Befehl | Beschreibung |
|--------|--------------|
| `tmux attach -t openclaw-node` | Live-Log ansehen |
| `tmux detach` | Aus tmux raus (Ctrl+B D) |
| `tmux kill-session -t openclaw-node` | Stoppen |
| `~/.termux/boot/openclaw-node.sh` | Manuell starten |
| `cat ~/.openclaw/node.log` | Log ansehen |

---

## Log-Datei

```bash
# Letzte Zeilen ansehen
tail -f ~/.openclaw/node.log

# Ganze Log-Datei
cat ~/.openclaw/node.log
```

---

## Skript-Inhalt (zum Kopieren)

```bash
#!/data/data/com.termux/files/usr/bin/bash
# OpenClaw Node Mode Autostart für Termux

SESSION="openclaw-node"
LOGFILE="$HOME/.openclaw/node.log"
GATEWAY="10.10.0.1"
PORT="18789"

mkdir -p "$HOME/.openclaw"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[$(date)] Bereits aktiv" >> "$LOGFILE"
    exit 0
fi

tmux new-session -d -s "$SESSION" -n "node" "
    while true; do
        echo '[$(date)] Starte OpenClaw Node...' | tee -a '$LOGFILE'
        
        if ! ping -c 1 -W 3 $GATEWAY >/dev/null 2>&1; then
            echo '[$(date)] WireGuard nicht erreichbar' | tee -a '$LOGFILE'
            sleep 10
            continue
        fi
        
        openclaw node run --host $GATEWAY --port $PORT 2>&1 | tee -a '$LOGFILE'
        echo '[$(date)] Neustart in 5s...' | tee -a '$LOGFILE'
        sleep 5
    done
"
```

---

## Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| `tmux: command not found` | `pkg install tmux` |
| `openclaw: command not found` | `npm install -g openclaw` |
| `ping: permission denied` | `termux-wake-lock` aktivieren |
| Autostart funktioniert nicht | Termux:Boot App installiert? |
| WireGuard nicht erreichbar | VPN manuell in Android aktivieren |

---

**Erstellt:** 2026-04-10  
**Pfad:** `scripts/openclaw-node-autostart-termux.sh`
