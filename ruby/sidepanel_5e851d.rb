#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "afe0da4002f6589ee58ced9e9918653ac3e6bc06c43e1d3b192422e52aa4896f", "source_sha256": "5e851dbbd6f8a85b568a8bbe7eddf23a83348f89559ecc9a3a4234558ee855d9", "target_language": "ruby"}
# sidepanel.css — portiert nach ruby
# Quelle: css, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/browser-extension/sidepanel.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

class SidePanelCSSGenerator
  def initialize
    @variables = {
      'accent' => '#fe2c55',
      'accent-dark' => '#d91f46',
      'surface' => 'color-mix(in srgb, Canvas 94%, CanvasText 6%)',
      'border' => 'color-mix(in srgb, CanvasText 18%, transparent)',
      'muted' => 'color-mix(in srgb, CanvasText 65%, transparent)',
      'good' => '#147d45',
      'warn' => '#a65f00',
      'bad' => '#b42318'
    }
    
    @rules = []
  end

  def generate_css
    css = ":root {\n"
    css += "  color-scheme: light dark;\n"
    css += "  font-family: Inter, \"Segoe UI\", system-ui, sans-serif;\n"
    @variables.each do |name, value|
      css += "  --#{name}: #{value};\n"
    end
    css += "}\n\n"

    @rules.each do |rule|
      css += rule + "\n"
    end

    css
  end

  def add_rule(selector, properties)
    rule = "#{selector} { "
    properties.each do |prop, value|
      rule += "#{prop}: #{value}; "
    end
    rule += "}"
    @rules << rule
  end

  def add_media_query(condition, rules_content)
    media_rule = "@media #{condition} { #{rules_content} }"
    @rules << media_rule
  end

  def build_stylesheet
    # Global styles
    add_rule("*", {"box-sizing" => "border-box"})
    add_rule("body", {
      "margin" => "0",
      "background" => "Canvas",
      "color" => "CanvasText",
      "min-width" => "300px"
    })
    add_rule("header", {
      "padding" => "11px 18px",
      "background" => "linear-gradient(135deg, color-mix(in srgb, var(--accent) 18%, Canvas), Canvas)",
      "border-bottom" => "1px solid var(--border)"
    })
    add_rule("h2", {
      "margin" => "0",
      "font-size" => "15px"
    })
    add_rule("main", {
      "padding" => "14px",
      "display" => "grid",
      "grid-template-columns" => "minmax(0, 1fr)",
      "gap" => "12px"
    })
    add_rule("section", {
      "min-width" => "0",
      "padding" => "14px",
      "background" => "var(--surface)",
      "border" => "1px solid var(--border)",
      "border-radius" => "13px",
      "box-shadow" => "0 5px 20px color-mix(in srgb, CanvasText 6%, transparent)"
    })

    # Section title and button row
    add_rule(".section-title, .button-row", {
      "display" => "flex",
      "align-items" => "center",
      "justify-content" => "space-between",
      "gap" => "8px"
    })
    add_rule(".section-title", {
      "min-width" => "0",
      "flex-wrap" => "wrap"
    })
    add_rule(".title-actions", {
      "display" => "flex",
      "min-width" => "0",
      "max-width" => "100%",
      "align-items" => "center",
      "justify-content" => "flex-end",
      "flex-wrap" => "wrap",
      "gap" => "6px"
    })

    # Status LED
    add_rule(".status-led", {
      "width" => "11px",
      "height" => "11px",
      "flex" => "0 0 11px",
      "border-radius" => "50%",
      "background" => "var(--bad)",
      "box-shadow" => "0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)"
    })
    add_rule(".status-led.on", {
      "background" => "var(--good)",
      "box-shadow" => "0 0 0 3px color-mix(in srgb, var(--good) 17%, transparent)"
    })
    add_rule(".status-led.off", {
      "background" => "var(--bad)"
    })

    # Buttons
    add_rule(".button-row", {
      "justify-content" => "flex-start",
      "flex-wrap" => "wrap",
      "margin-top" => "10px"
    })
    add_rule("button", {
      "border" => "0",
      "border-radius" => "9px",
      "padding" => "9px 11px",
      "font" => "inherit",
      "font-size" => "12px",
      "font-weight" => "700",
      "cursor" => "pointer"
    })
    add_rule("button:disabled", {
      "cursor" => "not-allowed",
      "opacity" => ".55"
    })
    add_rule(".compact", {
      "padding" => "7px 9px"
    })
    add_rule(".settings-button", {
      "min-width" => "34px",
      "font-size" => "17px",
      "line-height" => "1"
    })
    add_rule(".primary", {
      "color" => "white",
      "background" => "var(--accent)"
    })
    add_rule(".primary:hover", {
      "background" => "var(--accent-dark)"
    })
    add_rule(".secondary", {
      "color" => "CanvasText",
      "background" => "color-mix(in srgb, CanvasText 9%, Canvas)",
      "border" => "1px solid var(--border)"
    })
    add_rule(".ghost", {
      "color" => "var(--muted)",
      "background" => "transparent"
    })
    add_rule(".danger-outline", {
      "color" => "var(--bad)",
      "border-color" => "color-mix(in srgb, var(--bad) 45%, transparent)"
    })
    add_rule("#enable-captions", {
      "width" => "100%",
      "margin-top" => "11px"
    })

    # Text styles
    add_rule(".muted", {
      "color" => "var(--muted)"
    })
    add_rule(".small", {
      "font-size" => "12px",
      "line-height" => "1.45"
    })
    add_rule("#page-title", {
      "margin" => "0",
      "font-size" => "12px",
      "white-space" => "nowrap",
      "overflow" => "hidden",
      "text-overflow" => "ellipsis"
    })

    # Status grid
    add_rule(".status-grid", {
      "display" => "grid",
      "grid-template-columns" => "1fr 1fr",
      "gap" => "7px",
      "margin-top" => "11px"
    })
    add_rule(".status", {
      "padding" => "9px",
      "border" => "1px solid var(--border)",
      "border-radius" => "9px",
      "background" => "Canvas"
    })
    add_rule(".status-label", {
      "display" => "block",
      "color" => "var(--muted)",
      "font-size" => "10px",
      "text-transform" => "uppercase",
      "letter-spacing" => ".06em"
    })
    add_rule(".status-value", {
      "display" => "block",
      "margin-top" => "3px",
      "font-size" => "12px",
      "font-weight" => "750"
    })
    add_rule(".good .status-value", {
      "color" => "var(--good)"
    })
    add_rule(".warn .status-value", {
      "color" => "var(--warn)"
    })
    add_rule(".bad .status-value", {
      "color" => "var(--bad)"
    })

    # Count elements
    add_rule(".count", {
      "min-width" => "25px",
      "padding" => "3px 7px",
      "border-radius" => "999px",
      "background" => "color-mix(in srgb, var(--accent) 15%, Canvas)",
      "color" => "var(--accent)",
      "text-align" => "center",
      "font-size" => "11px",
      "font-weight" => "800"
    })
    add_rule(".count-button", {
      "border" => "1px solid color-mix(in srgb, var(--accent) 30%, transparent)",
      "cursor" => "pointer"
    })
    add_rule(".count-button:hover, .count-button:focus-visible", {
      "background" => "color-mix(in srgb, var(--accent) 25%, Canvas)"
    })

    # Live indicator
    add_rule(".live-indicator", {
      "padding" => "3px 7px",
      "border-radius" => "999px",
      "background" => "color-mix(in srgb, var(--muted) 15%, Canvas)",
      "color" => "var(--muted)",
      "font-size" => "10px",
      "font-weight" => "800",
      "text-transform" => "uppercase"
    })
    add_rule(".live-indicator.active", {
      "background" => "color-mix(in srgb, var(--good) 16%, Canvas)",
      "color" => "var(--good)"
    })

    # Stats grid
    add_rule(".stats-grid .status-value", {
      "font-size" => "16px",
      "font-variant-numeric" => "tabular-nums"
    })

    # Chat list
    add_rule(".chat-list", {
      "display" => "grid",
      "gap" => "6px",
      "margin-top" => "11px"
    })
    add_rule(".chat-list.empty", {
      "color" => "var(--muted)",
      "font-size" => "12px"
    })
    add_rule(".chat-line", {
      "margin" => "0",
      "padding" => "7px 8px",
      "border-left" => "3px solid color-mix(in srgb, var(--accent) 45%, var(--border))",
      "border-radius" => "6px",
      "background" => "Canvas",
      "font-size" => "12px",
      "line-height" => "1.4",
      "overflow-wrap" => "anywhere"
    })
    add_rule(".chat-author", {
      "font-weight" => "800"
    })

    # Player controls
    add_rule(".player-controls", {
      "display" => "grid",
      "grid-template-columns" => "repeat(2, minmax(0, 1fr))",
      "gap" => "7px",
      "margin-top" => "11px"
    })
    add_rule(".player-controls button", {
      "width" => "100%"
    })
    add_rule(".player-time", {
      "font-size" => "13px",
      "font-weight" => "800",
      "font-variant-numeric" => "tabular-nums"
    })

    # Audio controls
    add_rule(".audio-controls", {
      "display" => "grid",
      "gap" => "7px",
      "margin-top" => "12px",
      "padding-top" => "11px",
      "border-top" => "1px solid var(--border)"
    })
    add_rule(".control-label, .audio-meter-row", {
      "display" => "flex",
      "align-items" => "center",
      "justify-content" => "space-between",
      "gap" => "8px",
      "font-size" => "11px"
    })
    add_rule(".control-label output, .audio-meter-row strong", {
      "font-variant-numeric" => "tabular-nums"
    })
    add_rule("input[type=\"range\"]", {
      "width" => "100%",
      "accent-color" => "var(--accent)"
    })

    # Settings grid
    add_rule(".settings-grid", {
      "display" => "grid",
      "gap" => "7px",
      "margin-top" => "10px"
    })
    add_rule(".settings-grid label", {
      "display" => "grid",
      "gap" => "4px",
      "color" => "var(--muted)",
      "font-size" => "10px"
    })
    add_rule(".settings-grid label[hidden]", {
      "display" => "none"
    })
    add_rule("input[type=\"url\"], input[type=\"text\"], input[type=\"password\"], input[type=\"number\"], select", {
      "width" => "100%",
      "min-width" => "0",
      "padding" => "7px 8px",
      "border" => "1px solid var(--border)",
      "border-radius" => "7px",
      "background" => "Canvas",
      "color" => "CanvasText",
      "font" => "inherit",
      "font-size" => "11px"
    })

    # Top chatters
    add_rule(".top-chatters", {
      "display" => "grid",
      "gap" => "6px",
      "margin-top" => "8px"
    })
    add_rule(".top-chatters.empty", {
      "color" => "var(--muted)",
      "font-size" => "12px"
    })
    add_rule(".top-chatters-actions", {
      "display" => "flex",
      "justify-content" => "flex-end",
      "gap" => "9px",
      "margin-top" => "7px"
    })
    add_rule(".top-chatters-actions[hidden]", {
      "display" => "none"
    })
    add_rule(".top-chatter-link", {
      "padding" => "0",
      "color" => "var(--accent)",
      "background" => "transparent",
      "border" => "0",
      "border-radius" => "0",
      "font-weight" => "700"
    })
    add_rule(".top-chatter-link:hover", {
      "text-decoration" => "underline"
    })
    add_rule(".chatter-row", {
      "display" => "grid",
      "grid-template-columns" => "minmax(0, 1fr) auto auto",
      "align-items" => "center",
      "gap" => "7px",
      "padding" => "7px 8px",
      "border" => "1px solid var(--border)",
      "border-radius" => "8px",
      "background" => "Canvas"
    })
    add_rule(".chatter-name", {
      "min-width" => "0",
      "overflow" => "hidden",
      "text-overflow" => "ellipsis",
      "white-space" => "nowrap",
      "font-size" => "11px",
      "font-weight" => "800"
    })
    add_rule(".chatter-metrics", {
      "color" => "var(--muted)",
      "font-size" => "10px",
      "white-space" => "nowrap"
    })
    add_rule(".mute-toggle", {
      "display" => "flex",
      "align-items" => "center",
      "gap" => "4px",
      "color" => "var(--muted)",
      "font-size" => "10px"
    })

    # Recognize song
    add_rule("#recognize-song", {
      "width" => "100%",
      "margin-top" => "10px"
    })
    add_rule(".song-result", {
      "margin-top" => "9px",
      "padding" => "9px",
      "border" => "1px solid var(--border)",
      "border-radius" => "9px",
      "background" => "Canvas",
      "font-size" => "11px",
      "line-height" => "1.45"
    })
    add_rule(".song-result strong, .song-result span, .song-result a", {
      "display" => "block"
    })
    add_rule(".song-result a", {
      "margin-top" => "4px",
      "color" => "var(--accent)",
      "overflow-wrap" => "anywhere"
    })

    # Modal backdrop
    add_rule(".modal-backdrop", {
      "position" => "fixed",
      "inset" => "0",
      "z-index" => "100",
      "padding" => "14px",
      "background" => "color-mix(in srgb, CanvasText 42%, transparent)",
      "overflow" => "auto"
    })
    add_rule(".modal", {
      "width" => "min(520px, 100%)",
      "max-height" => "calc(100vh - 28px)",
      "margin" => "0 auto",
      "overflow" => "auto",
      "background" => "Canvas"
    })

    # Lists
    add_rule(".audience-list, .chat-history-list, .recommendation-list", {
      "display" => "grid",
      "gap" => "7px",
      "margin-top" => "9px"
    })
    add_rule(".chat-history-row", {
      "padding" => "8px 9px",
      "border" => "1px solid var(--border)",
      "border-radius" => "9px",
      "background" => "var(--surface)",
      "font-size" => "11px",
      "line-height" => "1.4",
      "overflow-wrap" => "anywhere"
    })
    add_rule(".chat-history-meta", {
      "display" => "block",
      "margin-bottom" => "3px",
      "color" => "var(--muted)",
      "font-size" => "10px"
    })
    add_rule(".audience-row", {
      "display" => "grid",
      "gap" => "6px",
      "padding" => "9px",
      "border" => "1px solid var(--border)",
      "border-radius" => "9px",
      "background" => "var(--surface)"
    })
    add_rule(".audience-row-head", {
      "display" => "flex",
      "align-items" => "center",
      "justify-content" => "space-between",
      "gap" => "8px"
    })
    add_rule(".audience-row select", {
      "width" => "auto",
      "max-width" => "170px"
    })
    add_rule(".audience-metrics", {
      "color" => "var(--muted)",
      "font-size" => "10px",
      "line-height" => "1.45"
    })

    # Option row
    add_rule(".option-row", {
      "display" => "flex",
      "align-items" => "flex-start",
      "gap" => "7px",
      "margin-top" => "8px",
      "color" => "var(--muted)",
      "font-size" => "11px",
      "line-height" => "1.35"
    })
    add_rule(".option-row input", {
      "margin" => "1px 0 0",
      "accent-color" => "var(--accent)"
    })
    add_rule(".auto-chat-refresh", {
      "align-items" => "center"
    })
    add_rule(".auto-chat-refresh input[type=\"number\"]", {
      "width" => "48px",
      "margin-left" => "3px",
      "padding" => "3px 4px",
      "border" => "1px solid var(--border)",
      "border-radius" => "6px",
      "background" => "Canvas",
      "color" => "CanvasText",
      "font" => "inherit",
      "font-size" => "11px"
    })
    add_rule(".quick-recover-setting input[type=\"number\"]", {
      "width" => "48px",
      "margin-left" => "3px",
      "padding" => "3px 4px",
      "border" => "1px solid var(--border)",
      "border-radius" => "6px",
      "background" => "Canvas",
      "color" => "CanvasText",
      "font" => "inherit",
      "font-size" => "11px"
    })
    add_rule(".audio-note", {
      "margin" => "1px 0 0"
    })

    # Profile info
    add_rule(".profile-info", {
      "display" => "grid",
      "gap" => "8px",
      "margin-top" => "11px"
    })
    add_rule(".profile-heading", {
      "margin" => "0",
      "font-size" => "14px",
      "font-weight" => "800"
    })
    add_rule(".profile-handle, .profile-bio", {
      "margin" => "0",
      "color" => "var(--muted)",
      "font-size" => "11px",
      "line-height" => "1.45",
      "white-space" => "pre-wrap"
    })
    add_rule(".profile-stats", {
      "display" => "grid",
      "grid-template-columns" => "repeat(3, minmax(0, 1fr))",
      "gap" => "6px"
    })
    add_rule(".profile-stat", {
      "padding" => "7px",
      "border" => "1px solid var(--border)",
      "border-radius" => "8px",
      "background" => "Canvas"
    })
    add_rule(".profile-stat strong, .profile-stat span", {
      "display" => "block"
    })
    add_rule(".profile-stat span", {
      "margin-top" => "2px",
      "color" => "var(--muted)",
      "font-size" => "9px",
      "text-transform" => "uppercase"
    })

    # Summary info
    add_rule(".summary-info", {
      "margin-top" => "10px",
      "padding-top" => "9px",
      "border-top" => "1px solid var(--border)",
      "font-size" => "11px",
      "line-height" => "1.45"
    })
    add_rule(".summary-text", {
      "margin" => "6px 0 0",
      "white-space" => "pre-wrap"
    })

    # Recommendation controls
    add_rule(".recommendation-controls", {
      "display" => "grid",
      "grid-template-columns" => "minmax(70px, .7fr) minmax(150px, 1.3fr)",
      "gap" => "8px",
      "margin-top" => "10px"
    })
    add_rule(".recommendation-controls label", {
      "display" => "grid",
      "gap" => "4px",
      "color" => "var(--muted)",
      "font-size" => "10px"
    })
    add_rule(".recommendation-list.empty", {
      "display" => "block",
      "color" => "var(--muted)",
      "font-size" => "12px"
    })
    add_rule(".recommendation-row", {
      "padding" => "9px",
      "border" => "1px solid var(--border)",
      "border-radius" => "9px",
      "background" => "Canvas"
    })
    add_rule(".recommendation-head", {
      "display" => "flex",
      "align-items" => "flex-start",
      "justify-content" => "space-between",
      "gap" => "8px"
    })
    add_rule(".recommendation-name", {
      "min-width" => "0",
      "margin" => "0",
      "font-size" => "11px",
      "font-weight" => "800",
      "overflow-wrap" => "anywhere"
    })
    add_rule(".recommendation-viewers", {
      "flex" => "0 0 auto",
      "color" => "var(--muted)",
      "font-size" => "10px",
      "font-variant-numeric" => "tabular-nums"
    })
    add_rule(".recommendation-description", {
      "margin" => "5px 0 0",
      "color" => "var(--muted)",
      "font-size" => "10px",
      "line-height" => "1.4",
      "overflow-wrap" => "anywhere"
    })
    add_rule(".recommendation-link", {
      "display" => "inline-block",
      "margin-top" => "6px",
      "color" => "var(--accent)",
      "font-size" => "11px",
      "font-weight" => "700"
    })

    # List
    add_rule(".list", {
      "display" => "grid",
      "gap" => "8px",
      "margin-top" => "11px",
      "max-height" => "300px",
      "overflow" => "auto"
    })
    add_rule(".list.empty", {
      "display" => "block",
      "color" => "var(--muted)",
      "font-size" => "12px"
    })
    add_rule(".item", {
      "padding" => "10px",
      "border" => "1px solid var(--border)",
      "border-radius" => "9px",
      "background" => "Canvas"
    })
    add_rule(".item-head", {
      "display" => "flex",
      "align-items" => "center",
      "justify-content" => "space-between",
      "gap" => "8px"
    })
    add_rule(".item-title", {
      "font-size" => "12px",
      "font-weight" => "800"
    })
    add_rule(".item-meta, .item-url, .caption-meta", {
      "color" => "var(--muted)",
      "font-size" => "10px"
    })
    add_rule(".item-url", {
      "margin-top" => "6px",
      "overflow-wrap" => "anywhere",
      "max-height" => "42px",
      "overflow" => "hidden"
    })
    add_rule(".copy", {
      "flex" => "0 0 auto",
      "padding" => "6px 8px"
    })
    add_rule(".caption-text", {
      "margin" => "5px 0 0",
      "white-space" => "pre-wrap",
      "font-size" => "12px",
      "line-height" => "1.4"
    })

    # Status and notice
    add_rule(".inline-status, .notice", {
      "min-height" => "17px",
      "margin" => "9px 0 0",
      "color" => "var(--muted)",
      "font-size" => "11px"
    })
    add_rule(".action-status", {
      "line-height" => "1.4"
    })
    add_rule(".reset-note", {
      "margin" => "7px 0 0"
    })
    add_rule(".notice", {
      "margin" => "0 3px 8px",
      "color" => "var(--bad)"
    })

    # Media queries
    add_media_query("(min-width: 430px)", ".speech-settings { grid-template-columns: 1fr 1fr; } .speech-settings label:first-child { grid-column: 1 / -1; }")
    add_media_query("(prefers-reduced-motion: reduce)", "* { scroll-behavior: auto !important; }")
  end

  def write_to_file(filename)
    build_stylesheet
    File.write(filename, generate_css)
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output_filename>"
    exit 1
  end

  generator = SidePanelCSSGenerator.new
  generator.write_to_file(ARGV[0])
  puts "CSS file generated: #{ARGV[0]}"
end
