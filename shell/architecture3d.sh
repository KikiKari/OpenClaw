#!/bin/bash
# architecture3d.css — portiert nach shell
# Quelle: css, Projects@TikTok-Live-Companion:site/src/architecture3d.css
# auch in: Projects@TikTok-Live-Companion-Android:site/src/architecture3d.css
# auch in: Projects@TikTok-Live-Companion-iOS:site/src/architecture3d.css
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Parameter prüfen
if [[ $# -ne 1 ]]; then
    echo "Aufruf: $0 <ausgabedatei>" >&2
    exit 1
fi

ausgabedatei="$1"

# CSS-Inhalt generieren
{
    echo ":root { color-scheme: light; }"
    echo ".architecture-3d-page { min-height: 100vh; overflow-x: hidden; background: #fffdf9; color: #14223c; padding-bottom: 48px; }"
    echo ".architecture-3d-header { min-height: 70px; display: flex; align-items: center; justify-content: space-between; gap: 20px; padding: 12px max(22px, calc((100vw - 1240px)/2)); border-bottom: 1px solid #d9e2ec; background: rgba(255,253,249,.96); }"
    echo ".architecture-3d-header a { color: #14223c; text-decoration: none; font-weight: 800; }"
    echo ".architecture-3d-header b { color: #e5384f; }"
    echo ".architecture-3d-header nav { display: flex; gap: 20px; }"
    echo ".architecture-3d-intro, .architecture-3d-workspace, .architecture-3d-legend, .architecture-3d-note { width: min(1240px, calc(100% - 36px)); margin-inline: auto; }"
    echo ".architecture-3d-intro { padding: 54px 0 26px; }"
    echo ".architecture-3d-intro h1 { margin: 5px 0 15px; font-size: clamp(2.35rem, 5vw, 4.3rem); line-height: 1.02; letter-spacing: -.05em; }"
    echo ".architecture-3d-intro > p:last-child { max-width: 820px; color: #526078; font-size: 1.05rem; line-height: 1.7; }"
    echo ".architecture-3d-eyebrow { margin: 0; color: #0c8f9d; font-size: .73rem; font-weight: 900; letter-spacing: .14em; }"
    echo ".architecture-3d-workspace { display: grid; grid-template-columns: minmax(0, 1fr) 290px; gap: 18px; }"
    echo ".architecture-3d-scene-shell { min-height: 650px; position: relative; overflow: hidden; border-radius: 16px; background: #0f1729; box-shadow: 0 20px 55px rgba(16,29,52,.22); }"
    echo ".architecture-3d-scene { position: absolute; inset: 0; opacity: 0; transition: opacity .18s ease; touch-action: pan-y; }"
    echo ".architecture-3d-scene.is-ready { opacity: 1; }"
    echo ".architecture-3d-scene canvas { display: block; width: 100%; height: 100%; }"
    echo ".architecture-3d-scene:focus-visible { outline: 3px solid #25c5d2; outline-offset: -5px; }"
    echo ".architecture-3d-fallback { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: contain; background: #0f1729; }"
    echo ".architecture-3d-controls { position: absolute; right: 14px; top: 14px; display: flex; gap: 8px; z-index: 4; }"
    echo ".architecture-3d-controls button, .architecture-3d-step button { min-height: 44px; border: 1px solid #60708a; border-radius: 9px; background: rgba(15,23,41,.88); color: white; padding: 9px 13px; font-weight: 800; cursor: pointer; }"
    echo ".architecture-3d-inspector { align-self: stretch; padding: 24px; border: 1px solid #d4dee8; border-radius: 16px; background: white; }"
    echo ".architecture-3d-inspector h2 { margin: 9px 0; font-size: 1.45rem; }"
    echo ".architecture-3d-inspector > p:not(.architecture-3d-eyebrow) { color: #526078; min-height: 48px; }"
    echo ".architecture-3d-inspector dl { margin: 25px 0; }"
    echo ".architecture-3d-inspector dl div { padding: 12px 0; border-bottom: 1px solid #e2e8f0; }"
    echo ".architecture-3d-inspector dt { color: #758198; font-size: .74rem; text-transform: uppercase; letter-spacing: .08em; }"
    echo ".architecture-3d-inspector dd { margin: 4px 0 0; font-weight: 800; overflow-wrap: anywhere; }"
    echo ".architecture-3d-step { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }"
    echo ".architecture-3d-step button { background: #14223c; }"
    echo ".architecture-3d-legend { display: flex; flex-wrap: wrap; gap: 24px; padding: 23px 0 10px; }"
    echo ".architecture-3d-legend span { display: inline-flex; align-items: center; gap: 9px; font-size: .85rem; font-weight: 750; }"
    echo ".architecture-3d-legend i { width: 30px; height: 4px; display: inline-block; background: #25c5d2; }"
    echo ".architecture-3d-legend i.audio { background: #ff557a; }"
    echo ".architecture-3d-legend i.token { background: repeating-linear-gradient(90deg,#e9a12d 0 7px,transparent 7px 11px); }"
    echo ".architecture-3d-note { color: #66758a; font-size: .82rem; }"
    echo "@media (max-width: 820px) {"
    echo "  .architecture-3d-workspace { grid-template-columns: 1fr; }"
    echo "  .architecture-3d-scene-shell { min-height: 520px; }"
    echo "  .architecture-3d-inspector { order: 2; }"
    echo "}"
    echo "@media (max-width: 520px) {"
    echo "  .architecture-3d-header { padding-inline: 16px; gap: 8px; font-size: .82rem; }"
    echo "  .architecture-3d-header nav { gap: 10px; }"
    echo "  .architecture-3d-intro { padding-top: 35px; }"
    echo "  .architecture-3d-intro h1 { font-size: clamp(2rem, 10vw, 2.75rem); overflow-wrap: anywhere; }"
    echo "  .architecture-3d-intro > p:last-child { overflow-wrap: anywhere; }"
    echo "  .architecture-3d-scene-shell { min-height: 460px; }"
    echo "  .architecture-3d-controls { left: 10px; right: 10px; justify-content: space-between; }"
    echo "  .architecture-3d-controls button { min-width: 44px; padding-inline: 8px; font-size: .77rem; }"
    echo "  .architecture-3d-legend { display: grid; gap: 12px; }"
    echo "}"
    echo "@media (prefers-reduced-motion: reduce) { .architecture-3d-scene { transition: none; } }"
} > "$ausgabedatei"

echo "CSS-Datei wurde erfolgreich erstellt: $ausgabedatei" >&2
