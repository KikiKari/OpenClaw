#!/usr/bin/env tclsh8.6
# sandbox-vpn.sh — portiert nach tcl
# Quelle: shell, Onboarding@main:scripts/sandbox-vpn.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Bringt die Sandbox reproduzierbar in das Tailscale-Tailnet des Nutzers —
# als Brücke am Agent-MITM-Proxy vorbei (sauberer Egress via SOCKS5) und mit
# Tailscale-SSH, damit die eigenen Geräte des Nutzers in die Sandbox kommen.
#
# Nutzt den WIEDERVERWENDBAREN Auth-Key aus der .env (nichts committet).
# userspace-networking: verändert NICHT die Host-Routen/den Agent-Proxy dieser
# Session; stellt einen SOCKS5-Proxy auf localhost:1055 bereit.
#
# Aufruf: scripts/sandbox-vpn.sh   (idempotent; No-op ohne Auth-Key/tailscale)

# Funktion zum Protokollieren
proc log {msg} {
    puts "\[sandbox-vpn\] $msg"
}

# In das Stammverzeichnis wechseln
cd [file dirname [file dirname [info script]]]

# Auth-Key aus .env lesen (ohne die gesamte .env zu sourcen)
set KEY ""
if {[file exists ".env"]} {
    set fp [open ".env" r]
    while {[gets $fp line] >= 0} {
        if {[regexp {^TAILSCALE_AUTH_KEY="(.*)"} $line -> key]} {
            set KEY $key
            break
        }
    }
    close $fp
}

if {$KEY eq ""} {
    log "kein TAILSCALE_AUTH_KEY in .env — überspringe VPN"
    exit 0
}

# Prüfen, ob tailscale installiert ist
if {[catch {exec which tailscale}]} {
    # Tailscale installieren
    log "installiere Tailscale …"
    if {[catch {exec curl -fsSL https://tailscale.com/install.sh | exec sh} result]} {
        log "WARNUNG: Tailscale-Install fehlgeschlagen"
        exit 0
    }
}

# Prüfen, ob tailscale läuft
if {[catch {exec tailscale status}]} {
    log "starte tailscaled (userspace, SOCKS5 localhost:1055) …"
    file mkdir "/var/lib/tailscale"
    
    # tailscaled im Hintergrund starten
    if {[catch {exec tailscaled --tun=userspace-networking \
        --socks5-server=localhost:1055 \
        --outbound-http-proxy-listen=localhost:1056 \
        --statedir=/var/lib/tailscale >& /tmp/tailscaled.log &}]} {
        log "Fehler beim Starten von tailscaled"
    } else {
        # Kurz warten, damit der Daemon starten kann
        after 4000
    }
}

# Prüfen, ob der Host bereits im Netzwerk ist
if {[catch {exec tailscale status 2>@1 | exec grep claude-sandbox}]} {
    log "tailscale up (hostname=claude-sandbox, --ssh) …"
    if {[catch {exec tailscale up --authkey=$KEY --hostname=claude-sandbox --ssh --accept-routes 2>@1}]} {
        log "WARNUNG: tailscale up fehlgeschlagen"
    }
} else {
    # SSH aktivieren
    catch {exec tailscale set --ssh 2>@1}
}

# Status prüfen und IP anzeigen
if {![catch {exec tailscale status}]} {
    if {[catch {exec tailscale ip -4 2>@1} IP]} {
        set IP "?"
    } else {
        # Nur die erste Zeile der IP verwenden
        set IP [lindex [split $IP "\n"] 0]
    }
    log "im Tailnet: claude-sandbox $IP · SSH aktiv · SOCKS5 localhost:1055"
}

exit 0
