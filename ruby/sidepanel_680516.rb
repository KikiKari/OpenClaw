#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5974185505bc6f6eb5bd2a5b8405a4b27ba64e94e41176ef117e8c7ce2ab3d6d", "source_sha256": "68051666bbf4b190e8ed4104075967311e9dda63ce5247df2f8b091a279b7c90", "target_language": "ruby"}
# sidepanel.css — portiert nach ruby
# Quelle: css, Projects@TikTok-Live-Companion:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.css
# auch in: Projects@TikTok-Live-Companion:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-Android:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.css
# auch in: 2 weiteren Fundstellen
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Generiert die sidepanel.css Datei
class SidePanelCSSGenerator
  def initialize
    @css = []
  end

  def generate_css
    add_root_variables
    add_global_styles
    add_layout_styles
    add_component_styles
    add_responsive_styles
    
    @css.join("\n")
  end

  private

  def add_rule(selector, properties)
    formatted_props = properties.map { |prop| "  #{prop}" }
    @css << "#{selector} {"
    @css.concat(formatted_props)
    @css << "}"
  end

  def add_root_variables
    add_rule(":root", [
      "color-scheme: light dark;",
      'font-family: Inter, "Segoe UI", system-ui, sans-serif;',
      "--accent: #fe2c55;",
      "--accent-dark: #d91f46;",
      "--surface: color-mix(in srgb, Canvas 94%, CanvasText 6%);",
      "--border: color-mix(in srgb, CanvasText 18%, transparent);",
      "--muted: color-mix(in srgb, CanvasText 65%, transparent);",
      "--good: #147d45;",
      "--warn: #a65f00;",
      "--bad: #b42318;"
    ])
    @css << ""
  end

  def add_global_styles
    add_rule("*", ["box-sizing: border-box;"])
    add_rule("body", [
      "margin: 0;",
      "background: Canvas;",
      "color: CanvasText;",
      "min-width: 300px;"
    ])
    @css << ""
  end

  def add_layout_styles
    add_rule("header", [
      "padding: 11px 18px;",
      "background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 18%, Canvas), Canvas);",
      "border-bottom: 1px solid var(--border);"
    ])
    
    add_rule("h2", [
      "margin: 0;",
      "font-size: 15px;"
    ])
    
    add_rule("main", [
      "padding: 14px;",
      "display: grid;",
      "grid-template-columns: minmax(0, 1fr);",
      "gap: 12px;"
    ])
    
    add_rule("section", [
      "min-width: 0;",
      "padding: 14px;",
      "background: var(--surface);",
      "border: 1px solid var(--border);",
      "border-radius: 13px;",
      "box-shadow: 0 5px 20px color-mix(in srgb, CanvasText 6%, transparent);"
    ])
    
    @css << ""
  end

  def add_component_styles
    # Section title and button row
    add_rule(".section-title, .button-row", [
      "display: flex;",
      "align-items: center;",
      "justify-content: space-between;",
      "gap: 8px;"
    ])
    
    add_rule(".section-title", [
      "min-width: 0;",
      "flex-wrap: wrap;"
    ])
    
    add_rule(".title-actions", [
      "display: flex;",
      "min-width: 0;",
      "max-width: 100%;",
      "align-items: center;",
      "justify-content: flex-end;",
      "flex-wrap: wrap;",
      "gap: 6px;"
    ])
    
    # Status LED
    add_rule(".status-led", [
      "width: 11px;",
      "height: 11px;",
      "flex: 0 0 11px;",
      "border-radius: 50%;",
      "background: var(--bad);",
      "box-shadow: 0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent);"
    ])
    
    add_rule(".status-led.on", [
      "background: var(--good);",
      "box-shadow: 0 0 0 3px color-mix(in srgb, var(--good) 17%, transparent);"
    ])
    
    add_rule(".status-led.off", [
      "background: var(--bad);"
    ])
    
    # Button row
    add_rule(".button-row", [
      "justify-content: flex-start;",
      "flex-wrap: wrap;",
      "margin-top: 10px;"
    ])
    
    # Buttons
    add_rule("button", [
      "border: 0;",
      "border-radius: 9px;",
      "padding: 9px 11px;",
      "font: inherit;",
      "font-size: 12px;",
      "font-weight: 700;",
      "cursor: pointer;"
    ])
    
    add_rule("button:disabled", [
      "cursor: not-allowed;",
      "opacity: .55;"
    ])
    
    add_rule(".compact", [
      "padding: 7px 9px;"
    ])
    
    add_rule(".primary", [
      "color: white;",
      "background: var(--accent);"
    ])
    
    add_rule(".primary:hover", [
      "background: var(--accent-dark);"
    ])
    
    add_rule(".secondary", [
      "color: CanvasText;",
      "background: color-mix(in srgb, CanvasText 9%, Canvas);",
      "border: 1px solid var(--border);"
    ])
    
    add_rule(".ghost", [
      "color: var(--muted);",
      "background: transparent;"
    ])
    
    add_rule(".danger-outline", [
      "color: var(--bad);",
      "border-color: color-mix(in srgb, var(--bad) 45%, transparent);"
    ])
    
    add_rule("#enable-captions", [
      "width: 100%;",
      "margin-top: 11px;"
    ])
    
    # Text styles
    add_rule(".muted", [
      "color: var(--muted);"
    ])
    
    add_rule(".small", [
      "font-size: 12px;",
      "line-height: 1.45;"
    ])
    
    add_rule("#page-title", [
      "margin: 0;",
      "font-size: 12px;",
      "white-space: nowrap;",
      "overflow: hidden;",
      "text-overflow: ellipsis;"
    ])
    
    # Status grid
    add_rule(".status-grid", [
      "display: grid;",
      "grid-template-columns: 1fr 1fr;",
      "gap: 7px;",
      "margin-top: 11px;"
    ])
    
    add_rule(".status", [
      "padding: 9px;",
      "border: 1px solid var(--border);",
      "border-radius: 9px;",
      "background: Canvas;"
    ])
    
    add_rule(".status-label", [
      "display: block;",
      "color: var(--muted);",
      "font-size: 10px;",
      "text-transform: uppercase;",
      "letter-spacing: .06em;"
    ])
    
    add_rule(".status-value", [
      "display: block;",
      "margin-top: 3px;",
      "font-size: 12px;",
      "font-weight: 750;"
    ])
    
    add_rule(".good .status-value", [
      "color: var(--good);"
    ])
    
    add_rule(".warn .status-value", [
      "color: var(--warn);"
    ])
    
    add_rule(".bad .status-value", [
      "color: var(--bad);"
    ])
    
    # Count and live indicator
    add_rule(".count", [
      "min-width: 25px;",
      "padding: 3px 7px;",
      "border-radius: 999px;",
      "background: color-mix(in srgb, var(--accent) 15%, Canvas);",
      "color: var(--accent);",
      "text-align: center;",
      "font-size: 11px;",
      "font-weight: 800;"
    ])
    
    add_rule(".live-indicator", [
      "padding: 3px 7px;",
      "border-radius: 999px;",
      "background: color-mix(in srgb, var(--muted) 15%, Canvas);",
      "color: var(--muted);",
      "font-size: 10px;",
      "font-weight: 800;",
      "text-transform: uppercase;"
    ])
    
    add_rule(".live-indicator.active", [
      "background: color-mix(in srgb, var(--good) 16%, Canvas);",
      "color: var(--good);"
    ])
    
    add_rule(".stats-grid .status-value", [
      "font-size: 16px;",
      "font-variant-numeric: tabular-nums;"
    ])
    
    # Chat list
    add_rule(".chat-list", [
      "display: grid;",
      "gap: 6px;",
      "margin-top: 11px;"
    ])
    
    add_rule(".chat-list.empty", [
      "color: var(--muted);",
      "font-size: 12px;"
    ])
    
    add_rule(".chat-line", [
      "margin: 0;",
      "padding: 7px 8px;",
      "border-left: 3px solid color-mix(in srgb, var(--accent) 45%, var(--border));",
      "border-radius: 6px;",
      "background: Canvas;",
      "font-size: 12px;",
      "line-height: 1.4;",
      "overflow-wrap: anywhere;"
    ])
    
    add_rule(".chat-author", [
      "font-weight: 800;"
    ])
    
    # Player controls
    add_rule(".player-controls", [
      "display: grid;",
      "grid-template-columns: repeat(2, minmax(0, 1fr));",
      "gap: 7px;",
      "margin-top: 11px;"
    ])
    
    add_rule(".player-controls button", [
      "width: 100%;"
    ])
    
    add_rule(".player-time", [
      "font-size: 13px;",
      "font-weight: 800;",
      "font-variant-numeric: tabular-nums;"
    ])
    
    # Audio controls
    add_rule(".audio-controls", [
      "display: grid;",
      "gap: 7px;",
      "margin-top: 12px;",
      "padding-top: 11px;",
      "border-top: 1px solid var(--border);"
    ])
    
    add_rule(".control-label, .audio-meter-row", [
      "display: flex;",
      "align-items: center;",
      "justify-content: space-between;",
      "gap: 8px;",
      "font-size: 11px;"
    ])
    
    add_rule(".control-label output, .audio-meter-row strong", [
      "font-variant-numeric: tabular-nums;"
    ])
    
    add_rule('input[type="range"]', [
      "width: 100%;",
      "accent-color: var(--accent);"
    ])
    
    # Settings grid
    add_rule(".settings-grid", [
      "display: grid;",
      "gap: 7px;",
      "margin-top: 10px;"
    ])
    
    add_rule(".settings-grid label", [
      "display: grid;",
      "gap: 4px;",
      "color: var(--muted);",
      "font-size: 10px;"
    ])
    
    add_rule('input[type="url"], input[type="password"], select', [
      "width: 100%;",
      "min-width: 0;",
      "padding: 7px 8px;",
      "border: 1px solid var(--border);",
      "border-radius: 7px;",
      "background: Canvas;",
      "color: CanvasText;",
      "font: inherit;",
      "font-size: 11px;"
    ])
    
    # Top chatters
    add_rule(".top-chatters", [
      "display: grid;",
      "gap: 6px;",
      "margin-top: 8px;"
    ])
    
    add_rule(".top-chatters.empty", [
      "color: var(--muted);",
      "font-size: 12px;"
    ])
    
    add_rule(".chatter-row", [
      "display: grid;",
      "grid-template-columns: minmax(0, 1fr) auto auto;",
      "align-items: center;",
      "gap: 7px;",
      "padding: 7px 8px;",
      "border: 1px solid var(--border);",
      "border-radius: 8px;",
      "background: Canvas;"
    ])
    
    add_rule(".chatter-name", [
      "min-width: 0;",
      "overflow: hidden;",
      "text-overflow: ellipsis;",
      "white-space: nowrap;",
      "font-size: 11px;",
      "font-weight: 800;"
    ])
    
    add_rule(".chatter-metrics", [
      "color: var(--muted);",
      "font-size: 10px;",
      "white-space: nowrap;"
    ])
    
    add_rule(".mute-toggle", [
      "display: flex;",
      "align-items: center;",
      "gap: 4px;",
      "color: var(--muted);",
      "font-size: 10px;"
    ])
    
    add_rule("#recognize-song", [
      "width: 100%;",
      "margin-top: 10px;"
    ])
    
    # Song result
    add_rule(".song-result", [
      "margin-top: 9px;",
      "padding: 9px;",
      "border: 1px solid var(--border);",
      "border-radius: 9px;",
      "background: Canvas;",
      "font-size: 11px;",
      "line-height: 1.45;"
    ])
    
    add_rule(".song-result strong, .song-result span, .song-result a", [
      "display: block;"
    ])
    
    add_rule(".song-result a", [
      "margin-top: 4px;",
      "color: var(--accent);",
      "overflow-wrap: anywhere;"
    ])
    
    # Modal
    add_rule(".modal-backdrop", [
      "position: fixed;",
      "inset: 0;",
      "z-index: 100;",
      "padding: 14px;",
      "background: color-mix(in srgb, CanvasText 42%, transparent);",
      "overflow: auto;"
    ])
    
    add_rule(".modal", [
      "width: min(520px, 100%);",
      "max-height: calc(100vh - 28px);",
      "margin: 0 auto;",
      "overflow: auto;",
      "background: Canvas;"
    ])
    
    # Audience list
    add_rule(".audience-list", [
      "display: grid;",
      "gap: 7px;",
      "margin-top: 9px;"
    ])
    
    add_rule(".audience-row", [
      "display: grid;",
      "gap: 6px;",
      "padding: 9px;",
      "border: 1px solid var(--border);",
      "border-radius: 9px;",
      "background: var(--surface);"
    ])
    
    add_rule(".audience-row-head", [
      "display: flex;",
      "align-items: center;",
      "justify-content: space-between;",
      "gap: 8px;"
    ])
    
    add_rule(".audience-row select", [
      "width: auto;",
      "max-width: 170px;"
    ])
    
    add_rule(".audience-metrics", [
      "color: var(--muted);",
      "font-size: 10px;",
      "line-height: 1.45;"
    ])
    
    # Option row
    add_rule(".option-row", [
      "display: flex;",
      "align-items: flex-start;",
      "gap: 7px;",
      "margin-top: 8px;",
      "color: var(--muted);",
      "font-size: 11px;",
      "line-height: 1.35;"
    ])
    
    add_rule(".option-row input", [
      "margin: 1px 0 0;",
      "accent-color: var(--accent);"
    ])
    
    add_rule(".audio-note", [
      "margin: 1px 0 0;"
    ])
    
    # Profile info
    add_rule(".profile-info", [
      "display: grid;",
      "gap: 8px;",
      "margin-top: 11px;"
    ])
    
    add_rule(".profile-heading", [
      "margin: 0;",
      "font-size: 14px;",
      "font-weight: 800;"
    ])
    
    add_rule(".profile-handle, .profile-bio", [
      "margin: 0;",
      "color: var(--muted);",
      "font-size: 11px;",
      "line-height: 1.45;",
      "white-space: pre-wrap;"
    ])
    
    add_rule(".profile-stats", [
      "display: grid;",
      "grid-template-columns: repeat(3, minmax(0, 1fr));",
      "gap: 6px;"
    ])
    
    add_rule(".profile-stat", [
      "padding: 7px;",
      "border: 1px solid var(--border);",
      "border-radius: 8px;",
      "background: Canvas;"
    ])
    
    add_rule(".profile-stat strong, .profile-stat span", [
      "display: block;"
    ])
    
    add_rule(".profile-stat span", [
      "margin-top: 2px;",
      "color: var(--muted);",
      "font-size: 9px;",
      "text-transform: uppercase;"
    ])
    
    # Summary info
    add_rule(".summary-info", [
      "margin-top: 10px;",
      "padding-top: 9px;",
      "border-top: 1px solid var(--border);",
      "font-size: 11px;",
      "line-height: 1.45;"
    ])
    
    add_rule(".summary-text", [
      "margin: 6px 0 0;",
      "white-space: pre-wrap;"
    ])
    
    # List
    add_rule(".list", [
      "display: grid;",
      "gap: 8px;",
      "margin-top: 11px;",
      "max-height: 300px;",
      "overflow: auto;"
    ])
    
    add_rule(".list.empty", [
      "display: block;",
      "color: var(--muted);",
      "font-size: 12px;"
    ])
    
    add_rule(".item", [
      "padding: 10px;",
      "border: 1px solid var(--border);",
      "border-radius: 9px;",
      "background: Canvas;"
    ])
    
    add_rule(".item-head", [
      "display: flex;",
      "align-items: center;",
      "justify-content: space-between;",
      "gap: 8px;"
    ])
    
    add_rule(".item-title", [
      "font-size: 12px;",
      "font-weight: 800;"
    ])
    
    add_rule(".item-meta, .item-url, .caption-meta", [
      "color: var(--muted);",
      "font-size: 10px;"
    ])
    
    add_rule(".item-url", [
      "margin-top: 6px;",
      "overflow-wrap: anywhere;",
      "max-height: 42px;",
      "overflow: hidden;"
    ])
    
    add_rule(".copy", [
      "flex: 0 0 auto;",
      "padding: 6px 8px;"
    ])
    
    add_rule(".caption-text", [
      "margin: 5px 0 0;",
      "white-space: pre-wrap;",
      "font-size: 12px;",
      "line-height: 1.4;"
    ])
    
    # Status and notice
    add_rule(".inline-status, .notice", [
      "min-height: 17px;",
      "margin: 9px 0 0;",
      "color: var(--muted);",
      "font-size: 11px;"
    ])
    
    add_rule(".action-status", [
      "line-height: 1.4;"
    ])
    
    add_rule(".reset-note", [
      "margin: 7px 0 0;"
    ])
    
    add_rule(".quality-details", [
      "margin-top: 5px;",
      "color: var(--muted);",
      "font-size: 10px;",
      "line-height: 1.4;"
    ])
    
    add_rule(".quality-active", [
      "border-color: color-mix(in srgb, var(--good) 55%, var(--border));"
    ])
    
    add_rule(".notice", [
      "margin: 0 3px 8px;",
      "color: var(--bad);"
    ])
    
    @css << ""
  end

  def add_responsive_styles
    @css << "@media (min-width: 430px) { .speech-settings { grid-template-columns: 1fr 1fr; } .speech-settings label:first-child { grid-column: 1 / -1; } }"
    @css << "@media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto !important; } }"
  end
end

# Hauptprogramm
if __FILE__ == $0
  if ARGV.length != 1
    puts "Verwendung: #{$0} <ausgabedatei>"
    exit 1
  end

  output_file = ARGV[0]
  
  generator = SidePanelCSSGenerator.new
  css_content = generator.generate_css
  
  File.write(output_file, css_content)
  
  puts "CSS-Datei wurde erfolgreich erstellt: #{output_file}"
end
