#!/usr/bin/env tclsh8.6
# browser-session.mjs — portiert nach tcl
# Quelle: javascript, Onboarding@main:scripts/browser-session.mjs
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Persistente Browser-Sitzung der Sandbox.
#
# Zweck: Plattformen ohne (nutzbare) API — WaveSpeed-Konsole, Perplexity,
# Canva, Stock-Portale — erfordern einen echten Web-Login. Diese Sitzung
# speichert Cookies/LocalStorage DAUERHAFT in einem user-data-dir, akzeptiert
# Cookie-Banner automatisch und bleibt über Skript-Läufe hinweg angemeldet.
#
# Profil-Verzeichnis: <repo>/.browser-profile (gitignored — enthält Secrets).
#
# Nutzung (immer unter Xvfb, damit echtes Chrome mit Codecs läuft):
#   xvfb-run -a tclsh8.6 scripts/browser-session.tcl open <URL>          # öffnen, Cookies akzeptieren, Screenshot
#   xvfb-run -a tclsh8.6 scripts/browser-session.tcl login <URL> [--user-field ..] [--pass-field ..] [--env-user X] [--env-pass Y]
#   xvfb-run -a tclsh8.6 scripts/browser-session.tcl shot <URL> [--out file.png] [--wait ms] [--full]
#   xvfb-run -a tclsh8.6 scripts/browser-session.tcl state                 # gespeicherte Cookies auflisten (Domains)
#
# Die Sitzung wird NICHT geschlossen-und-verworfen: das Profil bleibt auf Platte.

package require Tcl 8.6
package require fileutil
package require json

# Globale Variablen
set REPO [file normalize [file dirname [file dirname [info script]]]]
set PROFILE [expr {[info exists ::env(BROWSER_PROFILE_DIR)] ? $::env(BROWSER_PROFILE_DIR) : [file join $REPO ".browser-profile"]}]

# CHROME-Pfad finden
set CHROME ""
foreach path {"/usr/bin/google-chrome-stable" "/usr/bin/google-chrome"} {
    if {[file exists $path]} {
        set CHROME $path
        break
    }
}

# Argumente verarbeiten
lassign $argv cmd target rest
set rest [lassign $argv _ _]

proc flag {n d} {
    global rest
    set idx [lsearch -exact $rest "--$n"]
    if {$idx >= 0 && $idx+1 < [llength $rest]} {
        return [lindex $rest [expr {$idx+1}]]
    }
    return $d
}

proc has {n} {
    global rest
    return [expr {[lsearch -exact $rest "--$n"] != -1}]
}

# .env laden (nur für login-Credentials; nichts wird geloggt)
proc loadEnv {} {
    global REPO
    set f [file join $REPO ".env"]
    if {![file exists $f]} {
        return [dict create]
    }
    set out [dict create]
    set fd [open $f r]
    while {[gets $fd line] >= 0} {
        if {[regexp {^\s*([A-Z0-9_]+)\s*=\s*"?([^"]*)"?\s*$} $line _ key value]} {
            dict set out $key $value
        }
    }
    close $fd
    return $out
}

# Häufige Cookie-Consent-Buttons klicken (mehrsprachig, best effort)
proc acceptCookies {page} {
    set labels {
        "Accept all" "Accept All" "Alle akzeptieren" "Accept all cookies"
        "Alle Cookies akzeptieren" "I agree" "Ich stimme zu" "Zustimmen"
        "Allow all" "Akzeptieren" "Accept" "Got it" "Agree"
    }
    foreach name $labels {
        if {[catch {exec playwright click --page $page --role button --name $name --timeout 1500}]} {
            continue
        } else {
            return $name
        }
    }
    # Generische Consent-IDs
    set selectors {
        "#onetrust-accept-btn-handler"
        "[aria-label*='accept' i]"
        "button[title*='accept' i]"
    }
    foreach sel $selectors {
        if {[catch {exec playwright click --page $page --selector $sel --timeout 1500}]} {
            continue
        } else {
            return $sel
        }
    }
    return ""
}

# Verzeichnis erstellen
file mkdir $PROFILE

# Proxy-Einstellungen
set SOCKS [flag socks ""]
if {$SOCKS ne ""} {
    set PROXY "socks5://$SOCKS"
} else {
    set PROXY [expr {[info exists ::env(HTTPS_PROXY)] ? $::env(HTTPS_PROXY) : [expr {[info exists ::env(https_proxy)] ? $::env(https_proxy) : ""}] }]
}

# Browser-Kontext starten
set args [list --no-sandbox --autoplay-policy=no-user-gesture-required --disable-blink-features=AutomationControlled]
if {$PROXY ne ""} {
    lappend args --ssl-version-max=tls1.2
}

# Playwright-Kontext erstellen
set ctx [exec playwright launch-persistent-context $PROFILE \
    --headless false \
    --executable-path $CHROME \
    --viewport-width 1440 \
    --viewport-height 900 \
    --accept-downloads \
    --ignore-https-errors [has insecure] \
    --proxy-server $PROXY \
    --proxy-bypass "localhost,127.0.0.1,::1" \
    {*}$args]

set page [exec playwright get-page $ctx]

# Hauptlogik
if {$cmd eq "state"} {
    set cookies [exec playwright get-cookies $ctx]
    set domains [lsort -unique [dict keys [dict get $cookies domains]]]
    puts "Profil: $PROFILE"
    puts "[dict size $cookies] Cookies über [llength $domains] Domains:"
    foreach d $domains {
        puts "  $d"
    }
} elseif {$cmd eq "open" || $cmd eq "shot"} {
    if {$target eq ""} {
        error "URL fehlt"
    }
    exec playwright goto $page $target --wait-until domcontentloaded --timeout 60000
    set wait_time [flag wait 2500]
    after $wait_time
    set accepted [acceptCookies $page]
    if {$accepted ne ""} {
        puts "Cookie-Consent bestätigt via: $accepted"
    }
    after 1000
    set out [flag out [file join "/tmp" "browser-[clock seconds].png"]]
    set full [has full]
    exec playwright screenshot $page --path $out --full-page $full
    puts "Screenshot: $out"
    set final_url [exec playwright get-url $page]
    puts "URL final: $final_url"
} elseif {$cmd eq "login"} {
    if {$target eq ""} {
        error "URL fehlt"
    }
    set env [loadEnv]
    set user [dict get $env [flag env-user ""] [flag user ""]]
    set pass [dict get $env [flag env-pass ""] [flag pass ""]]
    exec playwright goto $page $target --wait-until domcontentloaded --timeout 60000
    after 2500
    acceptCookies $page
    if {$user ne ""} {
        set uf [flag user-field "input[type=email], input[name=email], input[name=username], input[id*=email i]"]
        exec playwright fill $page $uf $user --timeout 8000
    }
    if {$pass ne ""} {
        set pf [flag pass-field "input[type=password]"]
        exec playwright fill $page $pf $pass --timeout 8000
    }
    set out [flag out [file join "/tmp" "login-[clock seconds].png"]]
    exec playwright screenshot $page --path $out
    puts "Login-Formular ausgefüllt (user=[expr {$user ne "" ? "gesetzt" : "-"}], pass=[expr {$pass ne "" ? "gesetzt" : "-"}]). Screenshot: $out"
    puts "Absenden bewusst NICHT automatisch — nächster Schritt nach Sichtprüfung."
} else {
    puts "Befehle: open <URL> | shot <URL> | login <URL> | state"
}

# Kontext schließen (Profil bleibt erhalten)
exec playwright close-context $ctx
