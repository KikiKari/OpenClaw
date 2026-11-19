#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "64efa8d74e36e69d64c2cad4ad180d9598d2391c185416eb384b09fb2a92afb9", "source_sha256": "50a5fc7035b85cbf01f8124bc348dfb04553256c185469e38845db8f79a95a89", "target_language": "tcl"}
# index.html — portiert nach tcl
# Quelle: html, workspace@local:skills/github-clones/openclaw/src/canvas-host/a2ui/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc generateHTML {} {
    set html {}

    # doctype
    lappend html {<!doctype html>}

    # html start tag
    lappend html {<html>}

    # head section
    lappend html {  <head>}
    lappend html {    <meta charset="utf-8" />}
    lappend html {    <meta name="viewport" content="width=device-width, initial-scale=1" />}
    lappend html {    <title>OpenClaw Canvas</title>}

    # First script block
    lappend html {    <script>}
    lappend html {      (() => \{}
    lappend html {        const normalizeLower = (value) => \{}
    lappend html {          const trimmed = String(value || "").trim();}
    lappend html {          return trimmed.toLocaleLowerCase();}
    lappend html {        \};}
    lappend html {        try \{}
    lappend html {          const params = new URLSearchParams(window.location.search);}
    lappend html {          const platform = normalizeLower(params.get("platform"));}
    lappend html {          if (platform) \{}
    lappend html {            document.documentElement.dataset.platform = platform;}
    lappend html {            return;}
    lappend html {          \}}
    lappend html {          if (/android/i.test(navigator.userAgent || "")) \{}
    lappend html {            document.documentElement.dataset.platform = "android";}
    lappend html {          \}}
    lappend html {        \} catch (_) \{\}}
    lappend html {      \})();}
    lappend html {    </script>}

    # style section
    lappend html {    <style>}
    lappend html {      :root \{}
    lappend html {        color-scheme: dark;}
    lappend html {      \}}
    lappend html {      @media (prefers-reduced-motion: reduce) \{}
    lappend html {        body::before,}
    lappend html {        body::after \{}
    lappend html {          animation: none !important;}
    lappend html {        \}}
    lappend html {      \}}
    lappend html {      html,}
    lappend html {      body \{}
    lappend html {        height: 100%;}
    lappend html {        margin: 0;}
    lappend html {      \}}
    lappend html {      body \{}
    lappend html {        font:}
    lappend html {          14px system-ui,}
    lappend html {          -apple-system,}
    lappend html {          BlinkMacSystemFont,}
    lappend html {          "Roboto",}
    lappend html {          sans-serif;}
    lappend html {        background:}
    lappend html {          radial-gradient(1200px 900px at 15% 20%, rgba(42, 113, 255, 0.18), rgba(0, 0, 0, 0) 55%),}
    lappend html {          radial-gradient(900px 700px at 85% 30%, rgba(255, 0, 138, 0.14), rgba(0, 0, 0, 0) 60%),}
    lappend html {          radial-gradient(1000px 900px at 60% 90%, rgba(0, 209, 255, 0.1), rgba(0, 0, 0, 0) 60%),}
    lappend html {          #000;}
    lappend html {        color: #e5e7eb;}
    lappend html {        overflow: hidden;}
    lappend html {      \}}
    lappend html {      :root[data-platform="android"] body \{}
    lappend html {        background:}
    lappend html {          radial-gradient(1200px 900px at 15% 20%, rgba(42, 113, 255, 0.62), rgba(0, 0, 0, 0) 55%),}
    lappend html {          radial-gradient(900px 700px at 85% 30%, rgba(255, 0, 138, 0.52), rgba(0, 0, 0, 0) 60%),}
    lappend html {          radial-gradient(1000px 900px at 60% 90%, rgba(0, 209, 255, 0.48), rgba(0, 0, 0, 0) 60%),}
    lappend html {          #0b1328;}
    lappend html {      \}}
    lappend html {      body::before \{}
    lappend html {        content: "";}
    lappend html {        position: fixed;}
    lappend html {        inset: -20%;}
    lappend html {        background:}
    lappend html {          repeating-linear-gradient(}
    lappend html {            0deg,}
    lappend html {            rgba(255, 255, 255, 0.03) 0,}
    lappend html {            rgba(255, 255, 255, 0.03) 1px,}
    lappend html {            transparent 1px,}
    lappend html {            transparent 48px}
    lappend html {          ),}
    lappend html {          repeating-linear-gradient(}
    lappend html {            90deg,}
    lappend html {            rgba(255, 255, 255, 0.03) 0,}
    lappend html {            rgba(255, 255, 255, 0.03) 1px,}
    lappend html {            transparent 1px,}
    lappend html {            transparent 48px}
    lappend html {          );}
    lappend html {        transform: translate3d(0, 0, 0) rotate(-7deg);}
    lappend html {        will-change: transform, opacity;}
    lappend html {        -webkit-backface-visibility: hidden;}
    lappend html {        backface-visibility: hidden;}
    lappend html {        opacity: 0.45;}
    lappend html {        pointer-events: none;}
    lappend html {        animation: openclaw-grid-drift 140s ease-in-out infinite alternate;}
    lappend html {      \}}
    lappend html {      :root[data-platform="android"] body::before \{}
    lappend html {        opacity: 0.8;}
    lappend html {      \}}
    lappend html {      body::after \{}
    lappend html {        content: "";}
    lappend html {        position: fixed;}
    lappend html {        inset: -35%;}
    lappend html {        background:}
    lappend html {          radial-gradient(900px 700px at 30% 30%, rgba(42, 113, 255, 0.16), rgba(0, 0, 0, 0) 60%),}
    lappend html {          radial-gradient(800px 650px at 70% 35%, rgba(255, 0, 138, 0.12), rgba(0, 0, 0, 0) 62%),}
    lappend html {          radial-gradient(900px 800px at 55% 75%, rgba(0, 209, 255, 0.1), rgba(0, 0, 0, 0) 62%);}
    lappend html {        filter: blur(28px);}
    lappend html {        opacity: 0.52;}
    lappend html {        will-change: transform, opacity;}
    lappend html {        -webkit-backface-visibility: hidden;}
    lappend html {        backface-visibility: hidden;}
    lappend html {        transform: translate3d(0, 0, 0);}
    lappend html {        pointer-events: none;}
    lappend html {        animation: openclaw-glow-drift 110s ease-in-out infinite alternate;}
    lappend html {      \}}
    lappend html {      :root[data-platform="android"] body::after \{}
    lappend html {        opacity: 0.85;}
    lappend html {      \}}
    lappend html {      @supports (mix-blend-mode: screen) \{}
    lappend html {        body::after \{}
    lappend html {          mix-blend-mode: screen;}
    lappend html {        \}}
    lappend html {      \}}
    lappend html {      @supports not (mix-blend-mode: screen) \{}
    lappend html {        body::after \{}
    lappend html {          opacity: 0.7;}
    lappend html {        \}}
    lappend html {      \}}
    lappend html {      @keyframes openclaw-grid-drift \{}
    lappend html {        0% \{}
    lappend html {          transform: translate3d(-12px, 8px, 0) rotate(-7deg);}
    lappend html {          opacity: 0.4;}
    lappend html {        \}}
    lappend html {        50% \{}
    lappend html {          transform: translate3d(10px, -7px, 0) rotate(-6.6deg);}
    lappend html {          opacity: 0.56;}
    lappend html {        \}}
    lappend html {        100% \{}
    lappend html {          transform: translate3d(-8px, 6px, 0) rotate(-7.2deg);}
    lappend html {          opacity: 0.42;}
    lappend html {        \}}
    lappend html {      \}}
    lappend html {      @keyframes openclaw-glow-drift \{}
    lappend html {        0% \{}
    lappend html {          transform: translate3d(-18px, 12px, 0) scale(1.02);}
    lappend html {          opacity: 0.4;}
    lappend html {        \}}
    lappend html {        50% \{}
    lappend html {          transform: translate3d(14px, -10px, 0) scale(1.05);}
    lappend html {          opacity: 0.52;}
    lappend html {        \}}
    lappend html {        100% \{}
    lappend html {          transform: translate3d(-10px, 8px, 0) scale(1.03);}
    lappend html {          opacity: 0.43;}
    lappend html {        \}}
    lappend html {      \}}
    lappend html {      canvas \{}
    lappend html {        position: fixed;}
    lappend html {        inset: 0;}
    lappend html {        display: block;}
    lappend html {        width: 100vw;}
    lappend html {        height: 100vh;}
    lappend html {        touch-action: none;}
    lappend html {        z-index: 1;}
    lappend html {      \}}
    lappend html {      :root[data-platform="android"] #openclaw-canvas \{}
    lappend html {        background:}
    lappend html {          radial-gradient(1100px 800px at 20% 15%, rgba(42, 113, 255, 0.78), rgba(0, 0, 0, 0) 58%),}
    lappend html {          radial-gradient(900px 650px at 82% 28%, rgba(255, 0, 138, 0.66), rgba(0, 0, 0, 0) 62%),}
    lappend html {          radial-gradient(1000px 900px at 60% 88%, rgba(0, 209, 255, 0.58), rgba(0, 0, 0, 0) 62%),}
    lappend html {          #141c33;}
    lappend html {      \}}
    lappend html {      #openclaw-status \{}
    lappend html {        position: fixed;}
    lappend html {        inset: 0;}
    lappend html {        display: none;}
    lappend html {        align-items: center;}
    lappend html {        justify-content: center;}
    lappend html {        flex-direction: column;}
    lappend html {        padding: 24px;}
    lappend html {        box-sizing: border-box;}
    lappend html {        pointer-events: none;}
    lappend html {        z-index: 3;}
    lappend html {      \}}
    lappend html {      #openclaw-status .card \{}
    lappend html {        width: min(560px, 88vw);}
    lappend html {        text-align: left;}
    lappend html {        padding: 14px 16px 12px;}
    lappend html {        border-radius: 16px;}
    lappend html {        background: linear-gradient(140deg, rgba(23, 24, 35, 0.78), rgba(18, 19, 28, 0.55));}
    lappend html {        border: 1px solid rgba(255, 255, 255, 0.12);}
    lappend html {        box-shadow:}
    lappend html {          0 16px 46px rgba(0, 0, 0, 0.52),}
    lappend html {          inset 0 1px 0 rgba(255, 255, 255, 0.06);}
    lappend html {        -webkit-backdrop-filter: blur(18px) saturate(140%);}
    lappend html {        backdrop-filter: blur(18px) saturate(140%);}
    lappend html {      \}}
    lappend html {      #openclaw-status .title \{}
    lappend html {        font:}
    lappend html {          600 12px/1.2 -apple-system,}
    lappend html {          BlinkMacSystemFont,}
    lappend html {          "SF Pro Text",}
    lappend html {          system-ui,}
    lappend html {          sans-serif;}
    lappend html {        letter-spacing: 0.45px;}
    lappend html {        text-transform: uppercase;}
    lappend html {        color: rgba(255, 255, 255, 0.7);}
    lappend html {      \}}
    lappend html {      #openclaw-status .subtitle \{}
    lappend html {        margin-top: 8px;}
    lappend html {        font:}
    lappend html {          500 13px/1.45 -apple-system,}
    lappend html {          BlinkMacSystemFont,}
    lappend html {          "SF Pro Text",}
    lappend html {          system-ui,}
    lappend html {          sans-serif;}
    lappend html {        color: rgba(255, 255, 255, 0.9);}
    lappend html {        white-space: pre-wrap;}
    lappend html {        overflow-wrap: anywhere;}
    lappend html {      \}}
    lappend html {      openclaw-a2ui-host \{}
    lappend html {        display: block;}
    lappend html {        height: 100%;}
    lappend html {        position: fixed;}
    lappend html {        inset: 0;}
    lappend html {        z-index: 4;}
    lappend html {        --openclaw-a2ui-inset-top: 28px;}
    lappend html {        --openclaw-a2ui-inset-right: 0px;}
    lappend html {        --openclaw-a2ui-inset-bottom: 0px;}
    lappend html {        --openclaw-a2ui-inset-left: 0px;}
    lappend html {        --openclaw-a2ui-scroll-pad-bottom: 0px;}
    lappend html {        --openclaw-a2ui-status-top: calc(50% - 18px);}
    lappend html {        --openclaw-a2ui-empty-top: 18px;}
    lappend html {      \}}
    lappend html {    </style>}
    lappend html {  </head>}

    # body section
    lappend html {  <body>}
    lappend html {    <canvas id="openclaw-canvas"></canvas>}
    lappend html {    <div id="openclaw-status" role="status" aria-live="polite">}
    lappend html {      <section class="card">}
    lappend html {        <div class="title" id="openclaw-status-title">Ready</div>}
    lappend html {        <div class="subtitle" id="openclaw-status-subtitle">Waiting for agent</div>}
    lappend html {      </section>}
    lappend html {    </div>}
    lappend html {    <openclaw-a2ui-host></openclaw-a2ui-host>}
    lappend html {    <script src="a2ui.bundle.js"></script>}

    # Second script block
    lappend html {    <script>}
    lappend html {      (() => \{}
    lappend html {        const canvas = document.getElementById("openclaw-canvas");}
    lappend html {        const ctx = canvas.getContext("2d");}
    lappend html {        const statusEl = document.getElementById("openclaw-status");}
    lappend html {        const titleEl = document.getElementById("openclaw-status-title");}
    lappend html {        const subtitleEl = document.getElementById("openclaw-status-subtitle");}
    lappend html {        const debugStatusEnabledByQuery = (() => \{}
    lappend html {          try \{}
    lappend html {            const params = new URLSearchParams(window.location.search);}
    lappend html {            const raw = params.get("debugStatus") ?? params.get("debug");}
    lappend html {            if (!raw) return false;}
    lappend html {            const normalized = normalizeLower(raw);}
    lappend html {            return normalized === "1" || normalized === "true" || normalized === "yes";}
    lappend html {          \} catch (_) \{}
    lappend html {            return false;}
    lappend html {          \}}
    lappend html {        \})();}
    lappend html {        let debugStatusEnabled = debugStatusEnabledByQuery;}
    lappend html {}
    lappend html {        function resize() \{}
    lappend html {          const dpr = window.devicePixelRatio || 1;}
    lappend html {          const w = Math.max(1, Math.floor(window.innerWidth * dpr));}
    lappend html {          const h = Math.max(1, Math.floor(window.innerHeight * dpr));}
    lappend html {          canvas.width = w;}
    lappend html {          canvas.height = h;}
    lappend html {          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);}
    lappend html {        \}}
    lappend html {}
    lappend html {        window.addEventListener("resize", resize);}
    lappend html {        resize();}
    lappend html {}
    lappend html {        const setDebugStatusEnabled = (enabled) => \{}
    lappend html {          debugStatusEnabled = !!enabled;}
    lappend html {          if (!statusEl) return;}
    lappend html {          if (!debugStatusEnabled) \{}
    lappend html {            statusEl.style.display = "none";}
    lappend html {          \}}
    lappend html {        \};}
    lappend html {}
    lappend html {        if (statusEl && !debugStatusEnabled) \{}
    lappend html {          statusEl.style.display = "none";}
    lappend html {        \}}
    lappend html {}
    lappend html {        window.__openclaw = \{}
    lappend html {          canvas,}
    lappend html {          ctx,}
    append html {          setDebugStatusEnabled,}\n
    lappend html {          setStatus: (title, subtitle) => \{}
    lappend html {            if (!statusEl || !debugStatusEnabled) return;}
    lappend html {            if (!title && !subtitle) \{}
    lappend html {              statusEl.style.display = "none";}
    lappend html {              return;}
    lappend html {            \}}
    lappend html {            statusEl.style.display = "flex";}
    lappend html {            if (titleEl && typeof title === "string") titleEl.textContent = title;}
    lappend html {            if (subtitleEl && typeof subtitle === "string") subtitleEl.textContent = subtitle;}
    lappend html {            if (!debugStatusEnabled) \{}
    lappend html {              clearTimeout(window.__statusTimeout);}
    lappend html {              window.__statusTimeout = setTimeout(() => \{}
    lappend html {                statusEl.style.display = "none";}
    lappend html {              \}, 3000);}
    lappend html {            \} else \{}
    lappend html {              clearTimeout(window.__statusTimeout);}
    lappend html {            \}}
    lappend html {          \},}
    lappend html {        \};}
    lappend html {      \})();}
    lappend html {    </script>}
    lappend html {  </body>}
    lappend html {</html>}

    return [join $html "\n"]
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set filename [lindex $argv 0]
set htmlContent [generateHTML]

if {[catch {open $filename w} fileId]} {
    puts stderr "Error: Could not open file '$filename' for writing"
    exit 1
}

puts $fileId $htmlContent
close $fileId

puts "HTML file generated successfully: $filename"
