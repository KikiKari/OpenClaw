#!/usr/bin/env tclsh
# icon-controls.css — portiert nach tcl
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/icon-controls.css
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/icon-controls.css
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/icon-controls.css
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/icon-controls.css
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl Script zur Erzeugung der icon-controls.css Datei
# Portierung des CSS-Codes in eine strukturierte Tcl-Darstellung

proc write_css_file {filename} {
    set f [open $filename w]
    
    # Definition der Icon-Stile
    array set icon_styles {
        plastisch {
            auto-chat-refresh-counter icons/plastisch/auto-chat-refresh-counter.png
            browser icons/plastisch/browser.png
            captions icons/plastisch/captions.png
            chat-counter icons/plastisch/chat-counter.png
            fullscreen icons/plastisch/fullscreen.png
            mute icons/plastisch/mute.png
            off icons/plastisch/off.png
            on icons/plastisch/on.png
            pip icons/plastisch/pip.png
            play icons/plastisch/play.png
            player icons/plastisch/player.png
            protection-slider icons/plastisch/protection-slider.png
            recommendation-counter icons/plastisch/recommendation-counter.png
            report icons/plastisch/report.png
            reset icons/plastisch/reset.png
            settings icons/plastisch/settings.png
            status icons/plastisch/status.png
            stop icons/plastisch/stop.png
            unmute icons/plastisch/unmute.png
            volume-slider icons/plastisch/volume-slider.png
        }
        glass {
            auto-chat-refresh-counter icons/glass/auto-chat-refresh-counter.png
            browser icons/glass/browser.png
            captions icons/glass/captions.png
            chat-counter icons/glass/chat-counter.png
            fullscreen icons/glass/fullscreen.png
            mute icons/glass/mute.png
            off icons/glass/off.png
            on icons/glass/on.png
            pip icons/glass/pip.png
            play icons/glass/play.png
            player icons/glass/player.png
            protection-slider icons/glass/protection-slider.png
            recommendation-counter icons/glass/recommendation-counter.png
            report icons/glass/report.png
            reset icons/glass/reset.png
            settings icons/glass/settings.png
            status icons/glass/status.png
            stop icons/glass/stop.png
            unmute icons/glass/unmute.png
            volume-slider icons/glass/volume-slider.png
        }
        linear {
            auto-chat-refresh-counter icons/linear/auto-chat-refresh-counter.png
            browser icons/linear/browser.png
            captions icons/linear/captions.png
            chat-counter icons/linear/chat-counter.png
            fullscreen icons/linear/fullscreen.png
            mute icons/linear/mute.png
            off icons/linear/off.png
            on icons/linear/on.png
            pip icons/linear/pip.png
            play icons/linear/play.png
            player icons/linear/player.png
            protection-slider icons/linear/protection-slider.png
            recommendation-counter icons/linear/recommendation-counter.png
            report icons/linear/report.png
            reset icons/linear/reset.png
            settings icons/linear/settings.png
            status icons/linear/status.png
            stop icons/linear/stop.png
            unmute icons/linear/unmute.png
            volume-slider icons/linear/volume-slider.png
        }
    }
    
    # Schreiben der Icon-Style Definitionen
    foreach style [array names icon_styles] {
        puts $f "html\[data-icon-style=\"$style\"\] \{"
        array set icons $icon_styles($style)
        foreach {name url} [array get icons] {
            puts $f "  --icon-$name:url(\"$url\");"
        }
        puts $f "\}"
    }
    
    # Allgemeine Button- und Input-Stile
    puts $f {
button[data-control-icon]::before,.control-icon::before { content:""; display:inline-block; width:32px; height:32px; flex:0 0 32px; background:var(--control-icon) center/contain no-repeat; vertical-align:middle; margin-inline-end:0; pointer-events:none; }
button[data-control-icon] { min-height:44px; min-width:44px; font-size:0; display:inline-flex; align-items:center; justify-content:center; }
button[data-control-icon][hidden] { display:none; }
input[type="checkbox"] { appearance:none; -webkit-appearance:none; width:44px; height:44px; min-width:44px; border:0; background:var(--icon-off) center/40px no-repeat; cursor:pointer; vertical-align:middle; }
input[type="checkbox"]:checked { background-image:var(--icon-on); }
input[type="checkbox"]:focus-visible,button[data-control-icon]:focus-visible { outline:2px solid #1769df; outline-offset:2px; }
input[type="checkbox"]:disabled { opacity:.45; cursor:default; }
.control-icon { display:inline-flex; align-items:center; }
input[type="range"] { min-height:32px; }
.icon-style-setting { display:flex; align-items:center; gap:8px; }
}
    
    # Control-Icon Zuweisungen
    set control_icons {
        auto-chat-refresh-counter
        browser
        captions
        chat-counter
        fullscreen
        mute
        off
        on
        pip
        play
        player
        protection-slider
        recommendation-counter
        report
        reset
        settings
        status
        stop
        unmute
        volume-slider
    }
    
    foreach icon $control_icons {
        puts $f "\[data-control-icon=\"$icon\"\] { --control-icon:var(--icon-$icon); }"
    }
    
    close $f
}

# Hauptprogramm - prüfe Kommandozeilenargument
if {$argc != 1} {
    puts stderr "Verwendung: [info script] <ausgabedatei>"
    exit 1
}

set output_file [lindex $argv 0]
write_css_file $output_file
