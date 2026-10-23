#!/usr/bin/env python3
# sidepanel.css — portiert nach python
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.css
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/sidepanel.css
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_css():
    """Generate the sidepanel.css content programmatically"""
    
    # Root variables
    root_vars = {
        'color-scheme': 'light dark',
        'font-family': 'Inter, "Segoe UI", system-ui, sans-serif',
        '--accent': '#fe2c55',
        '--accent-dark': '#d91f46',
        '--surface': 'color-mix(in srgb, Canvas 94%, CanvasText 6%)',
        '--border': 'color-mix(in srgb, CanvasText 18%, transparent)',
        '--muted': 'color-mix(in srgb, CanvasText 65%, transparent)',
        '--good': '#147d45',
        '--warn': '#a65f00',
        '--bad': '#b42318'
    }
    
    # Build CSS rules
    rules = []
    
    # :root rule
    root_rule = ":root {\n"
    for prop, value in root_vars.items():
        root_rule += f"  {prop}: {value};\n"
    root_rule += "}"
    rules.append(root_rule)
    
    # Universal selector
    rules.append("* { box-sizing: border-box; }")
    
    # Body
    rules.append("body { margin: 0; background: Canvas; color: CanvasText; min-width: 300px; }")
    
    # Header
    rules.append("header { padding: 11px 18px; background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 18%, Canvas), Canvas); border-bottom: 1px solid var(--border); }")
    
    # Headings
    rules.append("h2 { margin: 0; font-size: 15px; }")
    
    # Main
    rules.append("main { padding: 14px; display: grid; grid-template-columns: minmax(0, 1fr); gap: 12px; }")
    
    # Sections
    rules.append("section { min-width: 0; padding: 14px; background: var(--surface); border: 1px solid var(--border); border-radius: 13px; box-shadow: 0 5px 20px color-mix(in srgb, CanvasText 6%, transparent); }")
    
    # Section title and button row
    rules.append(".section-title, .button-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; }")
    rules.append(".section-title { min-width: 0; flex-wrap: wrap; }")
    
    # Title actions
    rules.append(".title-actions { display: flex; min-width: 0; max-width: 100%; align-items: center; justify-content: flex-end; flex-wrap: wrap; gap: 6px; }")
    
    # Status LED
    rules.append(".status-led { width: 11px; height: 11px; flex: 0 0 11px; border-radius: 50%; background: var(--bad); box-shadow: 0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent); }")
    rules.append(".status-led.on { background: var(--good); box-shadow: 0 0 0 3px color-mix(in srgb, var(--good) 17%, transparent); }")
    rules.append(".status-led.off { background: var(--bad); }")
    
    # Button row
    rules.append(".button-row { justify-content: flex-start; flex-wrap: wrap; margin-top: 10px; }")
    
    # Buttons
    rules.append("button { border: 0; border-radius: 9px; padding: 9px 11px; font: inherit; font-size: 12px; font-weight: 700; cursor: pointer; }")
    rules.append("button:disabled { cursor: not-allowed; opacity: .55; }")
    rules.append(".compact { padding: 7px 9px; }")
    rules.append(".settings-button { min-width: 34px; font-size: 17px; line-height: 1; }")
    rules.append(".primary { color: white; background: var(--accent); }")
    rules.append(".primary:hover { background: var(--accent-dark); }")
    rules.append(".secondary { color: CanvasText; background: color-mix(in srgb, CanvasText 9%, Canvas); border: 1px solid var(--border); }")
    rules.append(".ghost { color: var(--muted); background: transparent; }")
    rules.append(".danger-outline { color: var(--bad); border-color: color-mix(in srgb, var(--bad) 45%, transparent); }")
    
    # Enable captions
    rules.append("#enable-captions { width: 100%; margin-top: 11px; }")
    
    # Text styles
    rules.append(".muted { color: var(--muted); }")
    rules.append(".small { font-size: 12px; line-height: 1.45; }")
    
    # Page title
    rules.append("#page-title { margin: 0; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }")
    
    # Status grid
    rules.append(".status-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; margin-top: 11px; }")
    rules.append(".status { padding: 9px; border: 1px solid var(--border); border-radius: 9px; background: Canvas; }")
    rules.append(".status-label { display: block; color: var(--muted); font-size: 10px; text-transform: uppercase; letter-spacing: .06em; }")
    rules.append(".status-value { display: block; margin-top: 3px; font-size: 12px; font-weight: 750; }")
    rules.append(".good .status-value { color: var(--good); }")
    rules.append(".warn .status-value { color: var(--warn); }")
    rules.append(".bad .status-value { color: var(--bad); }")
    
    # Count elements
    rules.append(".count { min-width: 25px; padding: 3px 7px; border-radius: 999px; background: color-mix(in srgb, var(--accent) 15%, Canvas); color: var(--accent); text-align: center; font-size: 11px; font-weight: 800; }")
    rules.append(".count-button { border: 1px solid color-mix(in srgb, var(--accent) 30%, transparent); cursor: pointer; }")
    rules.append(".count-button:hover, .count-button:focus-visible { background: color-mix(in srgb, var(--accent) 25%, Canvas); }")
    
    # Live indicator
    rules.append(".live-indicator { padding: 3px 7px; border-radius: 999px; background: color-mix(in srgb, var(--muted) 15%, Canvas); color: var(--muted); font-size: 10px; font-weight: 800; text-transform: uppercase; }")
    rules.append(".live-indicator.active { background: color-mix(in srgb, var(--good) 16%, Canvas); color: var(--good); }")
    
    # Stats grid
    rules.append(".stats-grid .status-value { font-size: 16px; font-variant-numeric: tabular-nums; }")
    
    # Chat list
    rules.append(".chat-list { display: grid; gap: 6px; margin-top: 11px; }")
    rules.append(".chat-list.empty { color: var(--muted); font-size: 12px; }")
    rules.append(".chat-line { margin: 0; padding: 7px 8px; border-left: 3px solid color-mix(in srgb, var(--accent) 45%, var(--border)); border-radius: 6px; background: Canvas; font-size: 12px; line-height: 1.4; overflow-wrap: anywhere; }")
    rules.append(".chat-author { font-weight: 800; }")
    
    # Player controls
    rules.append(".player-controls { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 7px; margin-top: 11px; }")
    rules.append(".player-controls button { width: 100%; }")
    rules.append(".player-time { font-size: 13px; font-weight: 800; font-variant-numeric: tabular-nums; }")
    
    # Audio controls
    rules.append(".audio-controls { display: grid; gap: 7px; margin-top: 12px; padding-top: 11px; border-top: 1px solid var(--border); }")
    rules.append(".control-label, .audio-meter-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 11px; }")
    rules.append(".control-label output, .audio-meter-row strong { font-variant-numeric: tabular-nums; }")
    rules.append("input[type=\"range\"] { width: 100%; accent-color: var(--accent); }")
    
    # Settings grid
    rules.append(".settings-grid { display: grid; gap: 7px; margin-top: 10px; }")
    rules.append(".settings-grid label { display: grid; gap: 4px; color: var(--muted); font-size: 10px; }")
    rules.append(".settings-grid label[hidden] { display: none; }")
    
    # Input fields
    rules.append("input[type=\"url\"], input[type=\"text\"], input[type=\"password\"], input[type=\"number\"], select { width: 100%; min-width: 0; padding: 7px 8px; border: 1px solid var(--border); border-radius: 7px; background: Canvas; color: CanvasText; font: inherit; font-size: 11px; }")
    
    # Top chatters
    rules.append(".top-chatters { display: grid; gap: 6px; margin-top: 8px; }")
    rules.append(".top-chatters.empty { color: var(--muted); font-size: 12px; }")
    rules.append(".top-chatters-actions { display: flex; justify-content: flex-end; gap: 9px; margin-top: 7px; }")
    rules.append(".top-chatters-actions[hidden] { display: none; }")
    
    # Top chatter link
    rules.append(".top-chatter-link { padding: 0; color: var(--accent); background: transparent; border: 0; border-radius: 0; font-weight: 700; }")
    rules.append(".top-chatter-link:hover { text-decoration: underline; }")
    
    # Chatter row
    rules.append(".chatter-row { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; align-items: center; gap: 7px; padding: 7px 8px; border: 1px solid var(--border); border-radius: 8px; background: Canvas; }")
    rules.append(".chatter-name { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11px; font-weight: 800; }")
    rules.append(".chatter-metrics { color: var(--muted); font-size: 10px; white-space: nowrap; }")
    rules.append(".mute-toggle { display: flex; align-items: center; gap: 4px; color: var(--muted); font-size: 10px; }")
    
    # Recognize song
    rules.append("#recognize-song { width: 100%; margin-top: 10px; }")
    rules.append(".song-result { margin-top: 9px; padding: 9px; border: 1px solid var(--border); border-radius: 9px; background: Canvas; font-size: 11px; line-height: 1.45; }")
    rules.append(".song-result strong, .song-result span, .song-result a { display: block; }")
    rules.append(".song-result a { margin-top: 4px; color: var(--accent); overflow-wrap: anywhere; }")
    
    # Modal
    rules.append(".modal-backdrop { position: fixed; inset: 0; z-index: 100; padding: 14px; background: color-mix(in srgb, CanvasText 42%, transparent); overflow: auto; }")
    rules.append(".modal { width: min(520px, 100%); max-height: calc(100vh - 28px); margin: 0 auto; overflow: auto; background: Canvas; }")
    
    # Lists
    rules.append(".audience-list, .chat-history-list, .recommendation-list { display: grid; gap: 7px; margin-top: 9px; }")
    rules.append(".chat-history-row { padding: 8px 9px; border: 1px solid var(--border); border-radius: 9px; background: var(--surface); font-size: 11px; line-height: 1.4; overflow-wrap: anywhere; }")
    rules.append(".chat-history-meta { display: block; margin-bottom: 3px; color: var(--muted); font-size: 10px; }")
    
    # Audience row
    rules.append(".audience-row { display: grid; gap: 6px; padding: 9px; border: 1px solid var(--border); border-radius: 9px; background: var(--surface); }")
    rules.append(".audience-row-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }")
    rules.append(".audience-row select { width: auto; max-width: 170px; }")
    rules.append(".audience-metrics { color: var(--muted); font-size: 10px; line-height: 1.45; }")
    
    # Option row
    rules.append(".option-row { display: flex; align-items: flex-start; gap: 7px; margin-top: 8px; color: var(--muted); font-size: 11px; line-height: 1.35; }")
    rules.append(".option-row input { margin: 1px 0 0; accent-color: var(--accent); }")
    rules.append(".auto-chat-refresh { align-items: center; }")
    rules.append(".external-speech-trigger-row { align-items: center; }")
    rules.append(".external-speech-trigger-row label { display: flex; align-items: center; gap: 7px; }")
    
    # External speech trigger row input
    rules.append(".external-speech-trigger-row input[type=\"text\"] { width: 48px; margin-left: 3px; padding: 3px 4px; border: 1px solid var(--border); border-radius: 6px; background: Canvas; color: CanvasText; font: inherit; font-size: 11px; }")
    
    # Number inputs
    rules.append(".auto-chat-refresh input[type=\"number\"] { width: 48px; margin-left: 3px; padding: 3px 4px; border: 1px solid var(--border); border-radius: 6px; background: Canvas; color: CanvasText; font: inherit; font-size: 11px; }")
    rules.append(".quick-recover-setting input[type=\"number\"] { width: 48px; margin-left: 3px; padding: 3px 4px; border: 1px solid var(--border); border-radius: 6px; background: Canvas; color: CanvasText; font: inherit; font-size: 11px; }")
    
    # Audio note
    rules.append(".audio-note { margin: 1px 0 0; }")
    
    # Profile info
    rules.append(".profile-info { display: grid; gap: 8px; margin-top: 11px; }")
    rules.append(".profile-heading { margin: 0; font-size: 14px; font-weight: 800; }")
    rules.append(".profile-handle, .profile-bio { margin: 0; color: var(--muted); font-size: 11px; line-height: 1.45; white-space: pre-wrap; }")
    rules.append(".profile-stats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }")
    rules.append(".profile-stat { padding: 7px; border: 1px solid var(--border); border-radius: 8px; background: Canvas; }")
    rules.append(".profile-stat strong, .profile-stat span { display: block; }")
    rules.append(".profile-stat span { margin-top: 2px; color: var(--muted); font-size: 9px; text-transform: uppercase; }")
    
    # Summary info
    rules.append(".summary-info { margin-top: 10px; padding-top: 9px; border-top: 1px solid var(--border); font-size: 11px; line-height: 1.45; }")
    rules.append(".summary-text { margin: 6px 0 0; white-space: pre-wrap; }")
    
    # Recommendation controls
    rules.append(".recommendation-controls { display: grid; grid-template-columns: minmax(70px, .7fr) minmax(150px, 1.3fr); gap: 8px; margin-top: 10px; }")
    rules.append(".recommendation-controls label { display: grid; gap: 4px; color: var(--muted); font-size: 10px; }")
    rules.append(".recommendation-list.empty { display: block; color: var(--muted); font-size: 12px; }")
    rules.append(".recommendation-row { padding: 9px; border: 1px solid var(--border); border-radius: 9px; background: Canvas; }")
    rules.append(".recommendation-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 8px; }")
    rules.append(".recommendation-name { min-width: 0; margin: 0; font-size: 11px; font-weight: 800; overflow-wrap: anywhere; }")
    rules.append(".recommendation-viewers { flex: 0 0 auto; color: var(--muted); font-size: 10px; font-variant-numeric: tabular-nums; }")
    rules.append(".recommendation-description { margin: 5px 0 0; color: var(--muted); font-size: 10px; line-height: 1.4; overflow-wrap: anywhere; }")
    rules.append(".recommendation-link { display: inline-block; margin-top: 6px; color: var(--accent); font-size: 11px; font-weight: 700; }")
    
    # List
    rules.append(".list { display: grid; gap: 8px; margin-top: 11px; max-height: 300px; overflow: auto; }")
    rules.append(".list.empty { display: block; color: var(--muted); font-size: 12px; }")
    rules.append(".item { padding: 10px; border: 1px solid var(--border); border-radius: 9px; background: Canvas; }")
    rules.append(".item-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }")
    rules.append(".item-title { font-size: 12px; font-weight: 800; }")
    rules.append(".item-meta, .item-url, .caption-meta { color: var(--muted); font-size: 10px; }")
    rules.append(".item-url { margin-top: 6px; overflow-wrap: anywhere; max-height: 42px; overflow: hidden; }")
    rules.append(".copy { flex: 0 0 auto; padding: 6px 8px; }")
    rules.append(".caption-text { margin: 5px 0 0; white-space: pre-wrap; font-size: 12px; line-height: 1.4; }")
    
    # Status and notice
    rules.append(".inline-status, .notice { min-height: 17px; margin: 9px 0 0; color: var(--muted); font-size: 11px; }")
    rules.append(".action-status { line-height: 1.4; }")
    rules.append(".reset-note { margin: 7px 0 0; }")
    rules.append(".notice { margin: 0 3px 8px; color: var(--bad); }")
    
    # Media queries
    rules.append("@media (min-width: 430px) { .speech-settings { grid-template-columns: 1fr 1fr; } .speech-settings label:first-child { grid-column: 1 / -1; } }")
    rules.append("@media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto !important; } }")
    
    # Additional comments as CSS comments
    rules.append("/* Header controls remain in one ordered group at the upper right. */")
    rules.append(".section-title.header-controls { flex-wrap: nowrap; align-items: flex-start; }")
    rules.append(".header-controls > .title-actions { margin-inline-start: auto; flex-wrap: nowrap; flex-shrink: 0; }")
    rules.append(".header-controls > .title-actions input[type=\"checkbox\"] { margin: 0; }")
    rules.append(".connection-status { display: flex; align-items: center; gap: 8px; }")
    
    return "\n".join(rules) + "\n"

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 sidepanel.py <output_file>")
        sys.exit(1)
    
    output_file = sys.argv[1]
    css_content = generate_css()
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(css_content)
        print(f"CSS file generated successfully: {output_file}")
    except Exception as e:
        print(f"Error writing to file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
