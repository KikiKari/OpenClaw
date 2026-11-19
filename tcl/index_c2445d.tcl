#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "405c7a81b2990f7d8f530d3b605f6b68ea0ceed407e270e92bf7c8093aabff6c", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "tcl"}
# index.html — portiert nach tcl
# Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc generate_index_html {filename} {
    set fp [open $filename w]
    
    puts $fp {<!doctype html>}
    puts $fp {<html lang="en">}
    puts $fp {  <head>}
    puts $fp {    <meta charset="UTF-8" />}
    puts $fp {    <meta name="viewport" content="width=device-width, initial-scale=1.0" />}
    puts $fp {    <title>OpenClaw Control</title>}
    puts $fp {    <meta name="color-scheme" content="dark light" />}
    puts $fp {    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />}
    puts $fp {    <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png" />}
    puts $fp {    <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />}
    puts $fp {    <script>}
    puts $fp {      (function () \{}
    puts $fp {        var THEMES = \{ claw: 1, knot: 1, dash: 1 \};}
    puts $fp {        var MODES = \{ system: 1, light: 1, dark: 1 \};}
    puts $fp {        var LEGACY = \{}
    puts $fp {          dark: "claw:dark",}
    puts $fp {          light: "claw:light",}
    puts $fp {          openknot: "knot:dark",}
    puts $fp {          fieldmanual: "dash:dark",}
    puts $fp {          clawdash: "dash:light",}
    puts $fp {          system: "claw:system",}
    puts $fp {        \};}
    puts $fp {        try \{}
    puts $fp {          var keys = Object.keys(localStorage);}
    puts $fp {          var raw;}
    puts $fp {          for (var i = 0; i < keys.length; i++) \{}
    puts $fp {            if (keys[i].indexOf("openclaw.control.settings.v1") === 0) \{}
    puts $fp {              raw = localStorage.getItem(keys[i]);}
    puts $fp {              if (raw) break;}
    puts $fp {            \}}
    puts $fp {          \}}
    puts $fp {          if (!raw) return;}
    puts $fp {          var s = JSON.parse(raw);}
    puts $fp {          var t = s && s.theme;}
    puts $fp {          var m = s && s.themeMode;}
    puts $fp {          if (typeof t !== "string") t = "";}
    puts $fp {          if (typeof m !== "string") m = "";}
    puts $fp {          var legacy = LEGACY[t];}
    puts $fp {          var theme = THEMES[t] ? t : legacy ? legacy.split(":")[0] : "claw";}
    puts $fp {          var mode = MODES[m] ? m : legacy ? legacy.split(":")[1] : "system";}
    puts $fp {          if (mode === "system") \{}
    puts $fp {            mode = window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";}
    puts $fp {          \}}
    puts $fp {          var resolved =}
    puts $fp {            theme === "knot"}
    puts $fp {              ? mode === "light"}
    puts $fp {                ? "openknot-light"}
    puts $fp {                : "openknot"}
    puts $fp {              : theme === "dash"}
    puts $fp {                ? mode === "light"}
    puts $fp {                  ? "dash-light"}
    puts $fp {                  : "dash"}
    puts $fp {                : mode === "light"}
    puts $fp {                  ? "light"}
    puts $fp {                  : "dark";}
    puts $fp {          document.documentElement.setAttribute("data-theme", resolved);}
    puts $fp {          document.documentElement.setAttribute(}
    puts $fp {            "data-theme-mode",}
    puts $fp {            resolved.indexOf("light") !== -1 ? "light" : "dark",}
    puts $fp {          );}
    puts $fp {        \} catch (e) \{\}}
    puts $fp {      \})();}
    puts $fp {    </script>}
    puts $fp {  </head>}
    puts $fp {  <body>}
    puts $fp {    <openclaw-app></openclaw-app>}
    puts $fp {    <script type="module" src="/src/main.ts"></script>}
    puts $fp {  </body>}
    puts $fp {</html>}
    
    close $fp
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set output_file [lindex $argv 0]
generate_index_html $output_file
