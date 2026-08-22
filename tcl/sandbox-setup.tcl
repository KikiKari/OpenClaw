#!/usr/bin/env tclsh
# sandbox-setup.sh — portiert nach tcl
# Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Provisioniert die Claude-Code-Sandbox (Remote-Umgebung) reproduzierbar:
#   - Node-Dependencies (Frontend, npm)
#   - Python-Dependencies (Backend inkl. pytest)
#   - Medien-Tools: ffmpeg, ImageMagick, GIMP, Blender headless (apt) —
#     Fehlschlag blockiert die Session nicht; --skip-heavy laesst GIMP/Blender aus
# Idempotent: bereits Vorhandenes wird uebersprungen; der Container-Cache der
# Umgebung macht die apt-Installation zum Einmal-Aufwand.

proc log {msg} {
    puts "\[sandbox-setup\] $msg"
}

proc execute {cmd} {
    if {[catch {exec {*}$cmd} result]} {
        return -code error $result
    }
    return $result
}

proc fileExists {filepath} {
    return [file exists $filepath]
}

proc commandExists {cmd} {
    set paths [split $::env(PATH) ":"]
    foreach path $paths {
        set fullpath [file join $path $cmd]
        if {[file executable $fullpath]} {
            return 1
        }
    }
    return 0
}

# Argument parsing
set skipHeavy 0
if {[llength $argv] > 0 && [lindex $argv 0] eq "--skip-heavy"} {
    set skipHeavy 1
}

# Change to parent directory of script
set scriptDir [file dirname [info script]]
cd [file dirname $scriptDir]

log "Node-Dependencies (npm install) ..."
if {[catch {exec npm install --no-audit --no-fund} result]} {
    log "FEHLER: npm install fehlgeschlagen"
    exit 1
}

log "Python-Dependencies (backend/requirements-dev.txt) ..."
if {[catch {exec pip3 install --quiet -r backend/requirements-dev.txt} result]} {
    log "FEHLER: pip install fehlgeschlagen"
    exit 1
}

proc aptInstall {pkg bin} {
    if {[commandExists $bin]} {
        if {[catch {execute [list $bin -version]} versionOutput]} {
            set versionInfo "unknown version"
        } else {
            set versionLine [lindex [split $versionOutput "\n"] 0]
            set versionInfo $versionLine
        }
        log "$pkg bereits vorhanden ($versionInfo)"
        return
    }
    
    log "Installiere $pkg ..."
    
    # Check if APT_UPDATED environment variable exists, default to 0
    set aptUpdated [expr {[info exists ::env(APT_UPDATED)] ? $::env(APT_UPDATED) : 0}]
    
    if {$aptUpdated == 0} {
        if {[catch {execute {sh -c {DEBIAN_FRONTEND=noninteractive apt-get update -qq}}}]} {
            log "WARNUNG: apt-get update fehlgeschlagen"
            return
        }
        set ::env(APT_UPDATED) 1
    }
    
    if {[catch {execute sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkg >/dev/null 2>&1"} result]} {
        log "WARNUNG: $pkg konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt"
    }
}

aptInstall ffmpeg ffmpeg
aptInstall imagemagick convert

if {!$skipHeavy} {
    aptInstall gimp gimp
    aptInstall blender blender
}

# Visual QA tools
aptInstall xvfb Xvfb
aptInstall x11-utils xdpyinfo
aptInstall libnss3-tools certutil

if {![commandExists google-chrome-stable]} {
    log "Installiere Google Chrome Stable ..."
    if {[catch {execute mktemp -s .deb} tmpDeb]} {
        set tmpDeb "/tmp/chrome.deb"
    }
    
    set chromeUrl "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    if {[catch {execute curl -fsSL -o $tmpDeb $chromeUrl}]} {
        log "WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)"
    } else {
        if {[catch {execute sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $tmpDeb >/dev/null 2>&1"}]} {
            log "WARNUNG: Chrome-Installation fehlgeschlagen"
        } else {
            if {[catch {execute google-chrome-stable --version} version]} {
                log "Chrome installiert: unknown version"
            } else {
                log "Chrome installiert: $version"
            }
        }
    }
    catch {execute rm -f $tmpDeb}
}

# Proxy-CA import into Chrome NSS database
if {[commandExists certutil] && [fileExists /root/.ccr/ca-bundle.crt]} {
    set nssDbDir "$::env(HOME)/.pki/nssdb"
    file mkdir $nssDbDir
    
    catch {execute certutil -d "sql:$nssDbDir" -N --empty-password}
    
    if {[catch {execute certutil -d "sql:$nssDbDir" -L} certList]} {
        set certInStore 0
    } else {
        if {[string first "ccr-proxy-ca" $certList] != -1} {
            set certInStore 1
        } else {
            set certInStore 0
        }
    }
    
    if {!$certInStore} {
        if {[catch {execute certutil -d "sql:$nssDbDir" -A -t "C,," -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt}]} {
            # Silent failure
        } else {
            log "Proxy-CA in Chrome-NSS-Store importiert"
        }
    }
}

# Playwright installation
if {[fileExists "node_modules"] && ![fileExists "node_modules/playwright"]} {
    if {[commandExists npm]} {
        if {[catch {execute npm install --no-audit --no-fund --no-save playwright}]} {
            log "WARNUNG: Playwright-npm-Install fehlgeschlagen"
        } else {
            log "Playwright (Node) installiert"
        }
    }
}

# Git push configuration
if {[catch {execute git rev-parse --is-inside-work-tree}]} {
    # Not in a git repository, skip git configuration
} else {
    set credentialHelper "[pwd]/.claude/git-credential-pat.sh"
    catch {execute git config credential.https://x-access-token@github.com.helper "!$credentialHelper"}
    catch {execute git remote set-url --push origin "https://x-access-token@github.com/KikiKari/Onboarding.git"}
    log "Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)"
}

# Docker daemon setup
if {[commandExists dockerd] && [catch {execute docker info}]} {
    log "Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) ..."
    file mkdir "/etc/docker"
    
    set daemonJson "/etc/docker/daemon.json"
    if {![fileExists $daemonJson]} {
        set fp [open $daemonJson w]
        puts $fp "{\"registry-mirrors\":[\"https://mirror.gcr.io\"]}"
        close $fp
    }
    
    # Start dockerd in background
    if {[catch {exec dockerd > /tmp/dockerd.log 2>@1 &}]} {
        log "WARNUNG: Konnte Docker-Daemon nicht starten"
    } else {
        # Wait for docker to start (max 15 seconds)
        set started 0
        for {set i 1} {$i <= 15} {incr i} {
            if {![catch {execute docker info}]} {
                set started 1
                break
            }
            after 1000
        }
        
        if {$started} {
            log "Docker-Daemon laeuft"
        } else {
            log "WARNUNG: Docker-Daemon nicht gestartet"
        }
    }
}

log "Fertig. Versionen:"
if {[catch {execute node --version} version]} {
    set version "unknown"
}
log "  node $version"

if {[catch {execute python3 --version} version]} {
    set version "unknown"
}
log "  $version"

if {[commandExists ffmpeg]} {
    if {[catch {execute sh -c "ffmpeg -version 2>/dev/null | head -1"} version]} {
        set version "unknown"
    }
    log "  $version"
}

if {[commandExists convert]} {
    if {[catch {execute sh -c "convert -version 2>/dev/null | head -1"} version]} {
        set version "unknown"
    }
    log "  $version"
}

if {[commandExists gimp]} {
    if {[catch {execute sh -c "gimp --version 2>/dev/null | head -1"} version]} {
        set version "unknown"
    }
    log "  $version"
}

if {[commandExists blender]} {
    if {[catch {execute sh -c "blender --version 2>/dev/null | head -1"} version]} {
        set version "unknown"
    }
    log "  $version"
}

exit 0
