#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9497ef2b7c3dfeb47532391adaed09d781497db60219a9e2a8c8f4583723610d", "source_sha256": "c1f866c7986ff0ed4be1f6037a31a8e570e388a61d046d7bbb6130c93a0d20ec", "target_language": "ruby"}
# sidepanel.css — portiert nach ruby
# Quelle: css, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-iOS:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

class SidePanelCSSGenerator
  def initialize
    @variables = {}
    @rules = []
  end

  def generate_css
    css = ":root {\n"
    @variables.each do |key, value|
      css += "  #{key}: #{value};\n"
    end
    css += "}\n\n"
    
    @rules.each do |rule|
      css += "#{rule[:selector]} { "
      rule[:properties].each do |prop, val|
        css += "#{prop}: #{val}; "
      end
      css += "}\n"
    end
    
    css
  end

  def add_variable(name, value)
    @variables[name] = value
  end

  def add_rule(selector, properties = {})
    @rules << { selector: selector, properties: properties }
  end

  def self.generate
    generator = new
    
    # Root variables
    generator.add_variable("color-scheme", "light dark")
    generator.add_variable("font-family", 'Inter, "Segoe UI", system-ui, sans-serif')
    generator.add_variable("--accent", "#fe2c55")
    generator.add_variable("--accent-dark", "#d91f46")
    generator.add_variable("--surface", "color-mix(in srgb, Canvas 94%, CanvasText 6%)")
    generator.add_variable("--border", "color-mix(in srgb, CanvasText 18%, transparent)")
    generator.add_variable("--muted", "color-mix(in srgb, CanvasText 65%, transparent)")
    generator.add_variable("--good", "#147d45")
    generator.add_variable("--warn", "#a65f00")
    generator.add_variable("--bad", "#b42318")
    
    # Global rules
    generator.add_rule("*", { "box-sizing" => "border-box" })
    generator.add_rule("body", { 
      "margin" => "0", 
      "background" => "Canvas", 
      "color" => "CanvasText", 
      "min-width" => "300px" 
    })
    generator.add_rule("header", { 
      "padding" => "11px 18px", 
      "background" => "linear-gradient(135deg, color-mix(in srgb, var(--accent) 18%, Canvas), Canvas)", 
      "border-bottom" => "1px solid var(--border)" 
    })
    generator.add_rule("h2", { 
      "margin" => "0", 
      "font-size" => "15px" 
    })
    generator.add_rule("main", { 
      "padding" => "14px", 
      "display" => "grid", 
      "grid-template-columns" => "minmax(0, 1fr)", 
      "gap" => "12px" 
    })
    generator.add_rule("section", { 
      "min-width" => "0", 
      "padding" => "14px", 
      "background" => "var(--surface)", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "13px", 
      "box-shadow" => "0 5px 20px color-mix(in srgb, CanvasText 6%, transparent)" 
    })
    generator.add_rule(".section-title, .button-row", { 
      "display" => "flex", 
      "align-items" => "center", 
      "justify-content" => "space-between", 
      "gap" => "8px" 
    })
    generator.add_rule(".section-title", { 
      "min-width" => "0", 
      "flex-wrap" => "wrap" 
    })
    generator.add_rule(".title-actions", { 
      "display" => "flex", 
      "min-width" => "0", 
      "max-width" => "100%", 
      "align-items" => "center", 
      "justify-content" => "flex-end", 
      "flex-wrap" => "wrap", 
      "gap" => "6px" 
    })
    generator.add_rule(".status-led", { 
      "width" => "11px", 
      "height" => "11px", 
      "flex" => "0 0 11px", 
      "border-radius" => "50%", 
      "background" => "var(--bad)", 
      "box-shadow" => "0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)" 
    })
    generator.add_rule(".status-led.on", { 
      "background" => "var(--good)", 
      "box-shadow" => "0 0 0 3px color-mix(in srgb, var(--good) 17%, transparent)" 
    })
    generator.add_rule(".status-led.off", { 
      "background" => "var(--bad)" 
    })
    generator.add_rule(".button-row", { 
      "justify-content" => "flex-start", 
      "flex-wrap" => "wrap", 
      "margin-top" => "10px" 
    })
    generator.add_rule("button", { 
      "border" => "0", 
      "border-radius" => "9px", 
      "padding" => "9px 11px", 
      "font" => "inherit", 
      "font-size" => "12px", 
      "font-weight" => "700", 
      "cursor" => "pointer" 
    })
    generator.add_rule("button:disabled", { 
      "cursor" => "not-allowed", 
      "opacity" => ".55" 
    })
    generator.add_rule(".compact", { 
      "padding" => "7px 9px" 
    })
    generator.add_rule(".primary", { 
      "color" => "white", 
      "background" => "var(--accent)" 
    })
    generator.add_rule(".primary:hover", { 
      "background" => "var(--accent-dark)" 
    })
    generator.add_rule(".secondary", { 
      "color" => "CanvasText", 
      "background" => "color-mix(in srgb, CanvasText 9%, Canvas)", 
      "border" => "1px solid var(--border)" 
    })
    generator.add_rule(".ghost", { 
      "color" => "var(--muted)", 
      "background" => "transparent" 
    })
    generator.add_rule(".danger-outline", { 
      "color" => "var(--bad)", 
      "border-color" => "color-mix(in srgb, var(--bad) 45%, transparent)" 
    })
    generator.add_rule("#enable-captions", { 
      "width" => "100%", 
      "margin-top" => "11px" 
    })
    generator.add_rule(".muted", { 
      "color" => "var(--muted)" 
    })
    generator.add_rule(".small", { 
      "font-size" => "12px", 
      "line-height" => "1.45" 
    })
    generator.add_rule("#page-title", { 
      "margin" => "0", 
      "font-size" => "12px", 
      "white-space" => "nowrap", 
      "overflow" => "hidden", 
      "text-overflow" => "ellipsis" 
    })
    generator.add_rule(".status-grid", { 
      "display" => "grid", 
      "grid-template-columns" => "1fr 1fr", 
      "gap" => "7px", 
      "margin-top" => "11px" 
    })
    generator.add_rule(".status", { 
      "padding" => "9px", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "9px", 
      "background" => "Canvas" 
    })
    generator.add_rule(".status-label", { 
      "display" => "block", 
      "color" => "var(--muted)", 
      "font-size" => "10px", 
      "text-transform" => "uppercase", 
      "letter-spacing" => ".06em" 
    })
    generator.add_rule(".status-value", { 
      "display" => "block", 
      "margin-top" => "3px", 
      "font-size" => "12px", 
      "font-weight" => "750" 
    })
    generator.add_rule(".good .status-value", { 
      "color" => "var(--good)" 
    })
    generator.add_rule(".warn .status-value", { 
      "color" => "var(--warn)" 
    })
    generator.add_rule(".bad .status-value", { 
      "color" => "var(--bad)" 
    })
    generator.add_rule(".count", { 
      "min-width" => "25px", 
      "padding" => "3px 7px", 
      "border-radius" => "999px", 
      "background" => "color-mix(in srgb, var(--accent) 15%, Canvas)", 
      "color" => "var(--accent)", 
      "text-align" => "center", 
      "font-size" => "11px", 
      "font-weight" => "800" 
    })
    generator.add_rule(".count-button", { 
      "border" => "1px solid color-mix(in srgb, var(--accent) 30%, transparent)", 
      "cursor" => "pointer" 
    })
    generator.add_rule(".count-button:hover, .count-button:focus-visible", { 
      "background" => "color-mix(in srgb, var(--accent) 25%, Canvas)" 
    })
    generator.add_rule(".live-indicator", { 
      "padding" => "3px 7px", 
      "border-radius" => "999px", 
      "background" => "color-mix(in srgb, var(--muted) 15%, Canvas)", 
      "color" => "var(--muted)", 
      "font-size" => "10px", 
      "font-weight" => "800", 
      "text-transform" => "uppercase" 
    })
    generator.add_rule(".live-indicator.active", { 
      "background" => "color-mix(in srgb, var(--good) 16%, Canvas)", 
      "color" => "var(--good)" 
    })
    generator.add_rule(".stats-grid .status-value", { 
      "font-size" => "16px", 
      "font-variant-numeric" => "tabular-nums" 
    })
    generator.add_rule(".chat-list", { 
      "display" => "grid", 
      "gap" => "6px", 
      "margin-top" => "11px" 
    })
    generator.add_rule(".chat-list.empty", { 
      "color" => "var(--muted)", 
      "font-size" => "12px" 
    })
    generator.add_rule(".chat-line", { 
      "margin" => "0", 
      "padding" => "7px 8px", 
      "border-left" => "3px solid color-mix(in srgb, var(--accent) 45%, var(--border))", 
      "border-radius" => "6px", 
      "background" => "Canvas", 
      "font-size" => "12px", 
      "line-height" => "1.4", 
      "overflow-wrap" => "anywhere" 
    })
    generator.add_rule(".chat-author", { 
      "font-weight" => "800" 
    })
    generator.add_rule(".player-controls", { 
      "display" => "grid", 
      "grid-template-columns" => "repeat(2, minmax(0, 1fr))", 
      "gap" => "7px", 
      "margin-top" => "11px" 
    })
    generator.add_rule(".player-controls button", { 
      "width" => "100%" 
    })
    generator.add_rule(".player-time", { 
      "font-size" => "13px", 
      "font-weight" => "800", 
      "font-variant-numeric" => "tabular-nums" 
    })
    generator.add_rule(".audio-controls", { 
      "display" => "grid", 
      "gap" => "7px", 
      "margin-top" => "12px", 
      "padding-top" => "11px", 
      "border-top" => "1px solid var(--border)" 
    })
    generator.add_rule(".control-label, .audio-meter-row", { 
      "display" => "flex", 
      "align-items" => "center", 
      "justify-content" => "space-between", 
      "gap" => "8px", 
      "font-size" => "11px" 
    })
    generator.add_rule(".control-label output, .audio-meter-row strong", { 
      "font-variant-numeric" => "tabular-nums" 
    })
    generator.add_rule('input[type="range"]', { 
      "width" => "100%", 
      "accent-color" => "var(--accent)" 
    })
    generator.add_rule(".settings-grid", { 
      "display" => "grid", 
      "gap" => "7px", 
      "margin-top" => "10px" 
    })
    generator.add_rule(".settings-grid label", { 
      "display" => "grid", 
      "gap" => "4px", 
      "color" => "var(--muted)", 
      "font-size" => "10px" 
    })
    generator.add_rule(".settings-grid label[hidden]", { 
      "display" => "none" 
    })
    generator.add_rule('input[type="url"], input[type="password"], select', { 
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
    generator.add_rule(".top-chatters", { 
      "display" => "grid", 
      "gap" => "6px", 
      "margin-top" => "8px" 
    })
    generator.add_rule(".top-chatters.empty", { 
      "color" => "var(--muted)", 
      "font-size" => "12px" 
    })
    generator.add_rule(".top-chatters-actions", { 
      "display" => "flex", 
      "justify-content" => "flex-end", 
      "gap" => "9px", 
      "margin-top" => "7px" 
    })
    generator.add_rule(".top-chatters-actions[hidden]", { 
      "display" => "none" 
    })
    generator.add_rule(".top-chatter-link", { 
      "padding" => "0", 
      "color" => "var(--accent)", 
      "background" => "transparent", 
      "border" => "0", 
      "border-radius" => "0", 
      "font-weight" => "700" 
    })
    generator.add_rule(".top-chatter-link:hover", { 
      "text-decoration" => "underline" 
    })
    generator.add_rule(".chatter-row", { 
      "display" => "grid", 
      "grid-template-columns" => "minmax(0, 1fr) auto auto", 
      "align-items" => "center", 
      "gap" => "7px", 
      "padding" => "7px 8px", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "8px", 
      "background" => "Canvas" 
    })
    generator.add_rule(".chatter-name", { 
      "min-width" => "0", 
      "overflow" => "hidden", 
      "text-overflow" => "ellipsis", 
      "white-space" => "nowrap", 
      "font-size" => "11px", 
      "font-weight" => "800" 
    })
    generator.add_rule(".chatter-metrics", { 
      "color" => "var(--muted)", 
      "font-size" => "10px", 
      "white-space" => "nowrap" 
    })
    generator.add_rule(".mute-toggle", { 
      "display" => "flex", 
      "align-items" => "center", 
      "gap" => "4px", 
      "color" => "var(--muted)", 
      "font-size" => "10px" 
    })
    generator.add_rule("#recognize-song", { 
      "width" => "100%", 
      "margin-top" => "10px" 
    })
    generator.add_rule(".song-result", { 
      "margin-top" => "9px", 
      "padding" => "9px", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "9px", 
      "background" => "Canvas", 
      "font-size" => "11px", 
      "line-height" => "1.45" 
    })
    generator.add_rule(".song-result strong, .song-result span, .song-result a", { 
      "display" => "block" 
    })
    generator.add_rule(".song-result a", { 
      "margin-top" => "4px", 
      "color" => "var(--accent)", 
      "overflow-wrap" => "anywhere" 
    })
    generator.add_rule(".modal-backdrop", { 
      "position" => "fixed", 
      "inset" => "0", 
      "z-index" => "100", 
      "padding" => "14px", 
      "background" => "color-mix(in srgb, CanvasText 42%, transparent)", 
      "overflow" => "auto" 
    })
    generator.add_rule(".modal", { 
      "width" => "min(520px, 100%)", 
      "max-height" => "calc(100vh - 28px)", 
      "margin" => "0 auto", 
      "overflow" => "auto", 
      "background" => "Canvas" 
    })
    generator.add_rule(".audience-list, .chat-history-list", { 
      "display" => "grid", 
      "gap" => "7px", 
      "margin-top" => "9px" 
    })
    generator.add_rule(".chat-history-row", { 
      "padding" => "8px 9px", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "9px", 
      "background" => "var(--surface)", 
      "font-size" => "11px", 
      "line-height" => "1.4", 
      "overflow-wrap" => "anywhere" 
    })
    generator.add_rule(".chat-history-meta", { 
      "display" => "block", 
      "margin-bottom" => "3px", 
      "color" => "var(--muted)", 
      "font-size" => "10px" 
    })
    generator.add_rule(".audience-row", { 
      "display" => "grid", 
      "gap" => "6px", 
      "padding" => "9px", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "9px", 
      "background" => "var(--surface)" 
    })
    generator.add_rule(".audience-row-head", { 
      "display" => "flex", 
      "align-items" => "center", 
      "justify-content" => "space-between", 
      "gap" => "8px" 
    })
    generator.add_rule(".audience-row select", { 
      "width" => "auto", 
      "max-width" => "170px" 
    })
    generator.add_rule(".audience-metrics", { 
      "color" => "var(--muted)", 
      "font-size" => "10px", 
      "line-height" => "1.45" 
    })
    generator.add_rule(".option-row", { 
      "display" => "flex", 
      "align-items" => "flex-start", 
      "gap" => "7px", 
      "margin-top" => "8px", 
      "color" => "var(--muted)", 
      "font-size" => "11px", 
      "line-height" => "1.35" 
    })
    generator.add_rule(".option-row input", { 
      "margin" => "1px 0 0", 
      "accent-color" => "var(--accent)" 
    })
    generator.add_rule(".auto-chat-refresh", { 
      "align-items" => "center" 
    })
    generator.add_rule(".auto-chat-refresh input[type=\"number\"]", { 
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
    generator.add_rule(".audio-note", { 
      "margin" => "1px 0 0" 
    })
    generator.add_rule(".profile-info", { 
      "display" => "grid", 
      "gap" => "8px", 
      "margin-top" => "11px" 
    })
    generator.add_rule(".profile-heading", { 
      "margin" => "0", 
      "font-size" => "14px", 
      "font-weight" => "800" 
    })
    generator.add_rule(".profile-handle, .profile-bio", { 
      "margin" => "0", 
      "color" => "var(--muted)", 
      "font-size" => "11px", 
      "line-height" => "1.45", 
      "white-space" => "pre-wrap" 
    })
    generator.add_rule(".profile-stats", { 
      "display" => "grid", 
      "grid-template-columns" => "repeat(3, minmax(0, 1fr))", 
      "gap" => "6px" 
    })
    generator.add_rule(".profile-stat", { 
      "padding" => "7px", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "8px", 
      "background" => "Canvas" 
    })
    generator.add_rule(".profile-stat strong, .profile-stat span", { 
      "display" => "block" 
    })
    generator.add_rule(".profile-stat span", { 
      "margin-top" => "2px", 
      "color" => "var(--muted)", 
      "font-size" => "9px", 
      "text-transform" => "uppercase" 
    })
    generator.add_rule(".summary-info", { 
      "margin-top" => "10px", 
      "padding-top" => "9px", 
      "border-top" => "1px solid var(--border)", 
      "font-size" => "11px", 
      "line-height" => "1.45" 
    })
    generator.add_rule(".summary-text", { 
      "margin" => "6px 0 0", 
      "white-space" => "pre-wrap" 
    })
    generator.add_rule(".list", { 
      "display" => "grid", 
      "gap" => "8px", 
      "margin-top" => "11px", 
      "max-height" => "300px", 
      "overflow" => "auto" 
    })
    generator.add_rule(".list.empty", { 
      "display" => "block", 
      "color" => "var(--muted)", 
      "font-size" => "12px" 
    })
    generator.add_rule(".item", { 
      "padding" => "10px", 
      "border" => "1px solid var(--border)", 
      "border-radius" => "9px", 
      "background" => "Canvas" 
    })
    generator.add_rule(".item-head", { 
      "display" => "flex", 
      "align-items" => "center", 
      "justify-content" => "space-between", 
      "gap" => "8px" 
    })
    generator.add_rule(".item-title", { 
      "font-size" => "12px", 
      "font-weight" => "800" 
    })
    generator.add_rule(".item-meta, .item-url, .caption-meta", { 
      "color" => "var(--muted)", 
      "font-size" => "10px" 
    })
    generator.add_rule(".item-url", { 
      "margin-top" => "6px", 
      "overflow-wrap" => "anywhere", 
      "max-height" => "42px", 
      "overflow" => "hidden" 
    })
    generator.add_rule(".copy", { 
      "flex" => "0 0 auto", 
      "padding" => "6px 8px" 
    })
    generator.add_rule(".caption-text", { 
      "margin" => "5px 0 0", 
      "white-space" => "pre-wrap", 
      "font-size" => "12px", 
      "line-height" => "1.4" 
    })
    generator.add_rule(".inline-status, .notice", { 
      "min-height" => "17px", 
      "margin" => "9px 0 0", 
      "color" => "var(--muted)", 
      "font-size" => "11px" 
    })
    generator.add_rule(".action-status", { 
      "line-height" => "1.4" 
    })
    generator.add_rule(".reset-note", { 
      "margin" => "7px 0 0" 
    })
    generator.add_rule(".notice", { 
      "margin" => "0 3px 8px", 
      "color" => "var(--bad)" 
    })
    
    # Media queries
    generator.add_rule("@media (min-width: 430px)", nil)
    generator.add_rule(".speech-settings", { 
      "grid-template-columns" => "1fr 1fr" 
    }, true)
    generator.add_rule(".speech-settings label:first-child", { 
      "grid-column" => "1 / -1" 
    }, true)
    
    generator.add_rule("@media (prefers-reduced-motion: reduce)", nil)
    generator.add_rule("*", { 
      "scroll-behavior" => "auto !important" 
    }, true)
    
    generator.generate_css
  end
  
  def add_rule(selector, properties, inside_media = false)
    if inside_media
      @rules.last[:content] ||= []
      @rules.last[:content] << { selector: selector, properties: properties }
    else
      @rules << { selector: selector, properties: properties }
    end
  end

  def generate_css
    css = ":root {\n"
    @variables.each do |key, value|
      css += "  #{key}: #{value};\n"
    end
    css += "}\n\n"
    
    @rules.each do |rule|
      if rule[:selector].start_with?("@media")
        css += "#{rule[:selector]} {\n"
        if rule[:content]
          rule[:content].each do |sub_rule|
            css += "  #{sub_rule[:selector]} { "
            sub_rule[:properties].each do |prop, val|
              css += "#{prop}: #{val}; "
            end
            css += "}\n"
          end
        end
        css += "}\n"
      else
        css += "#{rule[:selector]} { "
        rule[:properties].each do |prop, val|
          css += "#{prop}: #{val}; "
        end
        css += "}\n"
      end
    end
    
    css
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output_file>"
    exit 1
  end

  output_file = ARGV[0]
  
  css_content = SidePanelCSSGenerator.generate
  
  File.open(output_file, 'w') do |file|
    file.write(css_content)
  end
  
  puts "CSS file generated: #{output_file}"
end
