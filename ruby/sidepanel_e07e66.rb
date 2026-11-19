#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "61967172c6db64eaa0022a4e47fcf2be48268251c17baba6efab00aa37ef3499", "source_sha256": "e07e663714dd74eaf25d7c73a2e4fae09e726ce450182ddaeb0637ae76e40ad5", "target_language": "ruby"}
# sidepanel.css — portiert nach ruby
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.css
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.css
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/sidepanel.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

class CSSGenerator
  def initialize
    @variables = {}
    @rules = []
  end

  def add_variable(name, value)
    @variables[name] = value
  end

  def add_rule(selector, properties)
    @rules << { selector: selector, properties: properties }
  end

  def add_media_query(condition, rules)
    @rules << { media: condition, rules: rules }
  end

  def generate
    output = ":root {\n"
    @variables.each do |name, value|
      output += "  #{name}: #{value};\n"
    end
    output += "}\n\n"

    @rules.each do |rule|
      if rule[:media]
        output += "@media #{rule[:media]} {\n"
        rule[:rules].each do |inner_rule|
          output += format_rule(inner_rule[:selector], inner_rule[:properties])
        end
        output += "}\n\n"
      else
        output += format_rule(rule[:selector], rule[:properties])
      end
    end

    output
  end

  private

  def format_rule(selector, properties)
    output = "#{selector} {"
    properties.each do |prop, value|
      output += " #{prop}: #{value};"
    end
    output += " }\n"
    output += "\n" if selector == '*'
    output
  end
end

def create_sidepanel_css
  css = CSSGenerator.new

  # Root variables
  css.add_variable('color-scheme', 'light dark')
  css.add_variable('font-family', 'Inter, "Segoe UI", system-ui, sans-serif')
  css.add_variable('--accent', '#fe2c55')
  css.add_variable('--accent-dark', '#d91f46')
  css.add_variable('--surface', 'color-mix(in srgb, Canvas 94%, CanvasText 6%)')
  css.add_variable('--border', 'color-mix(in srgb, CanvasText 18%, transparent)')
  css.add_variable('--muted', 'color-mix(in srgb, CanvasText 65%, transparent)')
  css.add_variable('--good', '#147d45')
  css.add_variable('--warn', '#a65f00')
  css.add_variable('--bad', '#b42318')

  # Universal selector
  css.add_rule('*', { 'box-sizing' => 'border-box' })

  # Body
  css.add_rule('body', {
    'margin' => '0',
    'background' => 'Canvas',
    'color' => 'CanvasText',
    'min-width' => '300px'
  })

  # Header
  css.add_rule('header', {
    'padding' => '11px 18px',
    'background' => 'linear-gradient(135deg, color-mix(in srgb, var(--accent) 18%, Canvas), Canvas)',
    'border-bottom' => '1px solid var(--border)'
  })

  # Headings
  css.add_rule('h2', {
    'margin' => '0',
    'font-size' => '15px'
  })

  # Main content
  css.add_rule('main', {
    'padding' => '14px',
    'display' => 'grid',
    'grid-template-columns' => 'minmax(0, 1fr)',
    'gap' => '12px'
  })

  # Sections
  css.add_rule('section', {
    'min-width' => '0',
    'padding' => '14px',
    'background' => 'var(--surface)',
    'border' => '1px solid var(--border)',
    'border-radius' => '13px',
    'box-shadow' => '0 5px 20px color-mix(in srgb, CanvasText 6%, transparent)'
  })

  # Section title and button row
  css.add_rule('.section-title, .button-row', {
    'display' => 'flex',
    'align-items' => 'center',
    'justify-content' => 'space-between',
    'gap' => '8px'
  })

  css.add_rule('.section-title', {
    'min-width' => '0',
    'flex-wrap' => 'wrap'
  })

  css.add_rule('.title-actions', {
    'display' => 'flex',
    'min-width' => '0',
    'max-width' => '100%',
    'align-items' => 'center',
    'justify-content' => 'flex-end',
    'flex-wrap' => 'wrap',
    'gap' => '6px'
  })

  # Status LED
  css.add_rule('.status-led', {
    'width' => '11px',
    'height' => '11px',
    'flex' => '0 0 11px',
    'border-radius' => '50%',
    'background' => 'var(--bad)',
    'box-shadow' => '0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)'
  })

  css.add_rule('.status-led.on', {
    'background' => 'var(--good)',
    'box-shadow' => '0 0 0 3px color-mix(in srgb, var(--good) 17%, transparent)'
  })

  css.add_rule('.status-led.off', {
    'background' => 'var(--bad)'
  })

  # Button row
  css.add_rule('.button-row', {
    'justify-content' => 'flex-start',
    'flex-wrap' => 'wrap',
    'margin-top' => '10px'
  })

  # Buttons
  css.add_rule('button', {
    'border' => '0',
    'border-radius' => '9px',
    'padding' => '9px 11px',
    'font' => 'inherit',
    'font-size' => '12px',
    'font-weight' => '700',
    'cursor' => 'pointer'
  })

  css.add_rule('button:disabled', {
    'cursor' => 'not-allowed',
    'opacity' => '.55'
  })

  css.add_rule('.compact', {
    'padding' => '7px 9px'
  })

  css.add_rule('.settings-button', {
    'min-width' => '34px',
    'font-size' => '17px',
    'line-height' => '1'
  })

  css.add_rule('.primary', {
    'color' => 'white',
    'background' => 'var(--accent)'
  })

  css.add_rule('.primary:hover', {
    'background' => 'var(--accent-dark)'
  })

  css.add_rule('.secondary', {
    'color' => 'CanvasText',
    'background' => 'color-mix(in srgb, CanvasText 9%, Canvas)',
    'border' => '1px solid var(--border)'
  })

  css.add_rule('.ghost', {
    'color' => 'var(--muted)',
    'background' => 'transparent'
  })

  css.add_rule('.danger-outline', {
    'color' => 'var(--bad)',
    'border-color' => 'color-mix(in srgb, var(--bad) 45%, transparent)'
  })

  css.add_rule('#enable-captions', {
    'width' => '100%',
    'margin-top' => '11px'
  })

  # Text styles
  css.add_rule('.muted', {
    'color' => 'var(--muted)'
  })

  css.add_rule('.small', {
    'font-size' => '12px',
    'line-height' => '1.45'
  })

  css.add_rule('#page-title', {
    'margin' => '0',
    'font-size' => '12px',
    'white-space' => 'nowrap',
    'overflow' => 'hidden',
    'text-overflow' => 'ellipsis'
  })

  # Status grid
  css.add_rule('.status-grid', {
    'display' => 'grid',
    'grid-template-columns' => '1fr 1fr',
    'gap' => '7px',
    'margin-top' => '11px'
  })

  css.add_rule('.status', {
    'padding' => '9px',
    'border' => '1px solid var(--border)',
    'border-radius' => '9px',
    'background' => 'Canvas'
  })

  css.add_rule('.status-label', {
    'display' => 'block',
    'color' => 'var(--muted)',
    'font-size' => '10px',
    'text-transform' => 'uppercase',
    'letter-spacing' => '.06em'
  })

  css.add_rule('.status-value', {
    'display' => 'block',
    'margin-top' => '3px',
    'font-size' => '12px',
    'font-weight' => '750'
  })

  css.add_rule('.good .status-value', {
    'color' => 'var(--good)'
  })

  css.add_rule('.warn .status-value', {
    'color' => 'var(--warn)'
  })

  css.add_rule('.bad .status-value', {
    'color' => 'var(--bad)'
  })

  # Count elements
  css.add_rule('.count', {
    'min-width' => '25px',
    'padding' => '3px 7px',
    'border-radius' => '999px',
    'background' => 'color-mix(in srgb, var(--accent) 15%, Canvas)',
    'color' => 'var(--accent)',
    'text-align' => 'center',
    'font-size' => '11px',
    'font-weight' => '800'
  })

  css.add_rule('.count-button', {
    'border' => '1px solid color-mix(in srgb, var(--accent) 30%, transparent)',
    'cursor' => 'pointer'
  })

  css.add_rule('.count-button:hover, .count-button:focus-visible', {
    'background' => 'color-mix(in srgb, var(--accent) 25%, Canvas)'
  })

  # Live indicator
  css.add_rule('.live-indicator', {
    'padding' => '3px 7px',
    'border-radius' => '999px',
    'background' => 'color-mix(in srgb, var(--muted) 15%, Canvas)',
    'color' => 'var(--muted)',
    'font-size' => '10px',
    'font-weight' => '800',
    'text-transform' => 'uppercase'
  })

  css.add_rule('.live-indicator.active', {
    'background' => 'color-mix(in srgb, var(--good) 16%, Canvas)',
    'color' => 'var(--good)'
  })

  # Stats grid
  css.add_rule('.stats-grid .status-value', {
    'font-size' => '16px',
    'font-variant-numeric' => 'tabular-nums'
  })

  # Chat list
  css.add_rule('.chat-list', {
    'display' => 'grid',
    'gap' => '6px',
    'margin-top' => '11px'
  })

  css.add_rule('.chat-list.empty', {
    'color' => 'var(--muted)',
    'font-size' => '12px'
  })

  css.add_rule('.chat-line', {
    'margin' => '0',
    'padding' => '7px 8px',
    'border-left' => '3px solid color-mix(in srgb, var(--accent) 45%, var(--border))',
    'border-radius' => '6px',
    'background' => 'Canvas',
    'font-size' => '12px',
    'line-height' => '1.4',
    'overflow-wrap' => 'anywhere'
  })

  css.add_rule('.chat-author', {
    'font-weight' => '800'
  })

  # Player controls
  css.add_rule('.player-controls', {
    'display' => 'grid',
    'grid-template-columns' => 'repeat(2, minmax(0, 1fr))',
    'gap' => '7px',
    'margin-top' => '11px'
  })

  css.add_rule('.player-controls button', {
    'width' => '100%'
  })

  css.add_rule('.player-time', {
    'font-size' => '13px',
    'font-weight' => '800',
    'font-variant-numeric' => 'tabular-nums'
  })

  # Audio controls
  css.add_rule('.audio-controls', {
    'display' => 'grid',
    'gap' => '7px',
    'margin-top' => '12px',
    'padding-top' => '11px',
    'border-top' => '1px solid var(--border)'
  })

  css.add_rule('.control-label, .audio-meter-row', {
    'display' => 'flex',
    'align-items' => 'center',
    'justify-content' => 'space-between',
    'gap' => '8px',
    'font-size' => '11px'
  })

  css.add_rule('.control-label output, .audio-meter-row strong', {
    'font-variant-numeric' => 'tabular-nums'
  })

  css.add_rule('input[type="range"]', {
    'width' => '100%',
    'accent-color' => 'var(--accent)'
  })

  # Settings grid
  css.add_rule('.settings-grid', {
    'display' => 'grid',
    'gap' => '7px',
    'margin-top' => '10px'
  })

  css.add_rule('.settings-grid label', {
    'display' => 'grid',
    'gap' => '4px',
    'color' => 'var(--muted)',
    'font-size' => '10px'
  })

  css.add_rule('.settings-grid label[hidden]', {
    'display' => 'none'
  })

  css.add_rule('input[type="url"], input[type="text"], input[type="password"], input[type="number"], select', {
    'width' => '100%',
    'min-width' => '0',
    'padding' => '7px 8px',
    'border' => '1px solid var(--border)',
    'border-radius' => '7px',
    'background' => 'Canvas',
    'color' => 'CanvasText',
    'font' => 'inherit',
    'font-size' => '11px'
  })

  # Top chatters
  css.add_rule('.top-chatters', {
    'display' => 'grid',
    'gap' => '6px',
    'margin-top' => '8px'
  })

  css.add_rule('.top-chatters.empty', {
    'color' => 'var(--muted)',
    'font-size' => '12px'
  })

  css.add_rule('.top-chatters-actions', {
    'display' => 'flex',
    'justify-content' => 'flex-end',
    'gap' => '9px',
    'margin-top' => '7px'
  })

  css.add_rule('.top-chatters-actions[hidden]', {
    'display' => 'none'
  })

  css.add_rule('.top-chatter-link', {
    'padding' => '0',
    'color' => 'var(--accent)',
    'background' => 'transparent',
    'border' => '0',
    'border-radius' => '0',
    'font-weight' => '700'
  })

  css.add_rule('.top-chatter-link:hover', {
    'text-decoration' => 'underline'
  })

  css.add_rule('.chatter-row', {
    'display' => 'grid',
    'grid-template-columns' => 'minmax(0, 1fr) auto auto',
    'align-items' => 'center',
    'gap' => '7px',
    'padding' => '7px 8px',
    'border' => '1px solid var(--border)',
    'border-radius' => '8px',
    'background' => 'Canvas'
  })

  css.add_rule('.chatter-name', {
    'min-width' => '0',
    'overflow' => 'hidden',
    'text-overflow' => 'ellipsis',
    'white-space' => 'nowrap',
    'font-size' => '11px',
    'font-weight' => '800'
  })

  css.add_rule('.chatter-metrics', {
    'color' => 'var(--muted)',
    'font-size' => '10px',
    'white-space' => 'nowrap'
  })

  css.add_rule('.mute-toggle', {
    'display' => 'flex',
    'align-items' => 'center',
    'gap' => '4px',
    'color' => 'var(--muted)',
    'font-size' => '10px'
  })

  # Song recognition
  css.add_rule('#recognize-song', {
    'width' => '100%',
    'margin-top' => '10px'
  })

  css.add_rule('.song-result', {
    'margin-top' => '9px',
    'padding' => '9px',
    'border' => '1px solid var(--border)',
    'border-radius' => '9px',
    'background' => 'Canvas',
    'font-size' => '11px',
    'line-height' => '1.45'
  })

  css.add_rule('.song-result strong, .song-result span, .song-result a', {
    'display' => 'block'
  })

  css.add_rule('.song-result a', {
    'margin-top' => '4px',
    'color' => 'var(--accent)',
    'overflow-wrap' => 'anywhere'
  })

  # Modal
  css.add_rule('.modal-backdrop', {
    'position' => 'fixed',
    'inset' => '0',
    'z-index' => '100',
    'padding' => '14px',
    'background' => 'color-mix(in srgb, CanvasText 42%, transparent)',
    'overflow' => 'auto'
  })

  css.add_rule('.modal', {
    'width' => 'min(520px, 100%)',
    'max-height' => 'calc(100vh - 28px)',
    'margin' => '0 auto',
    'overflow' => 'auto',
    'background' => 'Canvas'
  })

  # Lists
  css.add_rule('.audience-list, .chat-history-list, .recommendation-list', {
    'display' => 'grid',
    'gap' => '7px',
    'margin-top' => '9px'
  })

  css.add_rule('.chat-history-row', {
    'padding' => '8px 9px',
    'border' => '1px solid var(--border)',
    'border-radius' => '9px',
    'background' => 'var(--surface)',
    'font-size' => '11px',
    'line-height' => '1.4',
    'overflow-wrap' => 'anywhere'
  })

  css.add_rule('.chat-history-meta', {
    'display' => 'block',
    'margin-bottom' => '3px',
    'color' => 'var(--muted)',
    'font-size' => '10px'
  })

  css.add_rule('.audience-row', {
    'display' => 'grid',
    'gap' => '6px',
    'padding' => '9px',
    'border' => '1px solid var(--border)',
    'border-radius' => '9px',
    'background' => 'var(--surface)'
  })

  css.add_rule('.audience-row-head', {
    'display' => 'flex',
    'align-items' => 'center',
    'justify-content' => 'space-between',
    'gap' => '8px'
  })

  css.add_rule('.audience-row select', {
    'width' => 'auto',
    'max-width' => '170px'
  })

  css.add_rule('.audience-metrics', {
    'color' => 'var(--muted)',
    'font-size' => '10px',
    'line-height' => '1.45'
  })

  # Option rows
  css.add_rule('.option-row', {
    'display' => 'flex',
    'align-items' => 'flex-start',
    'gap' => '7px',
    'margin-top' => '8px',
    'color' => 'var(--muted)',
    'font-size' => '11px',
    'line-height' => '1.35'
  })

  css.add_rule('.option-row input', {
    'margin' => '1px 0 0',
    'accent-color' => 'var(--accent)'
  })

  css.add_rule('.auto-chat-refresh', {
    'align-items' => 'center'
  })

  css.add_rule('.external-speech-trigger-row', {
    'align-items' => 'center'
  })

  css.add_rule('.external-speech-trigger-row label', {
    'display' => 'flex',
    'align-items' => 'center',
    'gap' => '7px'
  })

  css.add_rule('.external-speech-trigger-row input[type="text"]', {
    'width' => '48px',
    'margin-left' => '3px',
    'padding' => '3px 4px',
    'border' => '1px solid var(--border)',
    'border-radius' => '6px',
    'background' => 'Canvas',
    'color' => 'CanvasText',
    'font' => 'inherit',
    'font-size' => '11px'
  })

  css.add_rule('.auto-chat-refresh input[type="number"]', {
    'width' => '48px',
    'margin-left' => '3px',
    'padding' => '3px 4px',
    'border' => '1px solid var(--border)',
    'border-radius' => '6px',
    'background' => 'Canvas',
    'color' => 'CanvasText',
    'font' => 'inherit',
    'font-size' => '11px'
  })

  css.add_rule('.quick-recover-setting input[type="number"]', {
    'width' => '48px',
    'margin-left' => '3px',
    'padding' => '3px 4px',
    'border' => '1px solid var(--border)',
    'border-radius' => '6px',
    'background' => 'Canvas',
    'color' => 'CanvasText',
    'font' => 'inherit',
    'font-size' => '11px'
  })

  css.add_rule('.audio-note', {
    'margin' => '1px 0 0'
  })

  # Profile info
  css.add_rule('.profile-info', {
    'display' => 'grid',
    'gap' => '8px',
    'margin-top' => '11px'
  })

  css.add_rule('.profile-heading', {
    'margin' => '0',
    'font-size' => '14px',
    'font-weight' => '800'
  })

  css.add_rule('.profile-handle, .profile-bio', {
    'margin' => '0',
    'color' => 'var(--muted)',
    'font-size' => '11px',
    'line-height' => '1.45',
    'white-space' => 'pre-wrap'
  })

  css.add_rule('.profile-stats', {
    'display' => 'grid',
    'grid-template-columns' => 'repeat(3, minmax(0, 1fr))',
    'gap' => '6px'
  })

  css.add_rule('.profile-stat', {
    'padding' => '7px',
    'border' => '1px solid var(--border)',
    'border-radius' => '8px',
    'background' => 'Canvas'
  })

  css.add_rule('.profile-stat strong, .profile-stat span', {
    'display' => 'block'
  })

  css.add_rule('.profile-stat span', {
    'margin-top' => '2px',
    'color' => 'var(--muted)',
    'font-size' => '9px',
    'text-transform' => 'uppercase'
  })

  css.add_rule('.summary-info', {
    'margin-top' => '10px',
    'padding-top' => '9px',
    'border-top' => '1px solid var(--border)',
    'font-size' => '11px',
    'line-height' => '1.45'
  })

  css.add_rule('.summary-text', {
    'margin' => '6px 0 0',
    'white-space' => 'pre-wrap'
  })

  # Recommendation controls
  css.add_rule('.recommendation-controls', {
    'display' => 'grid',
    'grid-template-columns' => 'minmax(70px, .7fr) minmax(150px, 1.3fr)',
    'gap' => '8px',
    'margin-top' => '10px'
  })

  css.add_rule('.recommendation-controls label', {
    'display' => 'grid',
    'gap' => '4px',
    'color' => 'var(--muted)',
    'font-size' => '10px'
  })

  css.add_rule('.recommendation-list.empty', {
    'display' => 'block',
    'color' => 'var(--muted)',
    'font-size' => '12px'
  })

  css.add_rule('.recommendation-row', {
    'padding' => '9px',
    'border' => '1px solid var(--border)',
    'border-radius' => '9px',
    'background' => 'Canvas'
  })

  css.add_rule('.recommendation-head', {
    'display' => 'flex',
    'align-items' => 'flex-start',
    'justify-content' => 'space-between',
    'gap' => '8px'
  })

  css.add_rule('.recommendation-name', {
    'min-width' => '0',
    'margin' => '0',
    'font-size' => '11px',
    'font-weight' => '800',
    'overflow-wrap' => 'anywhere'
  })

  css.add_rule('.recommendation-viewers', {
    'flex' => '0 0 auto',
    'color' => 'var(--muted)',
    'font-size' => '10px',
    'font-variant-numeric' => 'tabular-nums'
  })

  css.add_rule('.recommendation-description', {
    'margin' => '5px 0 0',
    'color' => 'var(--muted)',
    'font-size' => '10px',
    'line-height' => '1.4',
    'overflow-wrap' => 'anywhere'
  })

  css.add_rule('.recommendation-link', {
    'display' => 'inline-block',
    'margin-top' => '6px',
    'color' => 'var(--accent)',
    'font-size' => '11px',
    'font-weight' => '700'
  })

  # Generic list
  css.add_rule('.list', {
    'display' => 'grid',
    'gap' => '8px',
    'margin-top' => '11px',
    'max-height' => '300px',
    'overflow' => 'auto'
  })

  css.add_rule('.list.empty', {
    'display' => 'block',
    'color' => 'var(--muted)',
    'font-size' => '12px'
  })

  css.add_rule('.item', {
    'padding' => '10px',
    'border' => '1px solid var(--border)',
    'border-radius' => '9px',
    'background' => 'Canvas'
  })

  css.add_rule('.item-head', {
    'display' => 'flex',
    'align-items' => 'center',
    'justify-content' => 'space-between',
    'gap' => '8px'
  })

  css.add_rule('.item-title', {
    'font-size' => '12px',
    'font-weight' => '800'
  })

  css.add_rule('.item-meta, .item-url, .caption-meta', {
    'color' => 'var(--muted)',
    'font-size' => '10px'
  })

  css.add_rule('.item-url', {
    'margin-top' => '6px',
    'overflow-wrap' => 'anywhere',
    'max-height' => '42px',
    'overflow' => 'hidden'
  })

  css.add_rule('.copy', {
    'flex' => '0 0 auto',
    'padding' => '6px 8px'
  })

  css.add_rule('.caption-text', {
    'margin' => '5px 0 0',
    'white-space' => 'pre-wrap',
    'font-size' => '12px',
    'line-height' => '1.4'
  })

  # Status and notice elements
  css.add_rule('.inline-status, .notice', {
    'min-height' => '17px',
    'margin' => '9px 0 0',
    'color' => 'var(--muted)',
    'font-size' => '11px'
  })

  css.add_rule('.action-status', {
    'line-height' => '1.4'
  })

  css.add_rule('.reset-note', {
    'margin' => '7px 0 0'
  })

  css.add_rule('.notice', {
    'margin' => '0 3px 8px',
    'color' => 'var(--bad)'
  })

  # Media queries
  css.add_media_query('(min-width: 430px)', [
    {
      selector: '.speech-settings',
      properties: {
        'grid-template-columns' => '1fr 1fr'
      }
    },
    {
      selector: '.speech-settings label:first-child',
      properties: {
        'grid-column' => '1 / -1'
      }
    }
  ])

  css.add_media_query('(prefers-reduced-motion: reduce)', [
    {
      selector: '*',
      properties: {
        'scroll-behavior' => 'auto !important'
      }
    }
  ])

  # Additional comments as rules
  css.add_rule('/* Header controls remain in one ordered group at the upper right. */\n.section-title.header-controls', {
    'flex-wrap' => 'nowrap',
    'align-items' => 'flex-start'
  })

  css.add_rule('.header-controls > .title-actions', {
    'margin-inline-start' => 'auto',
    'flex-wrap' => 'nowrap',
    'flex-shrink' => '0'
  })

  css.add_rule('.header-controls > .title-actions input[type="checkbox"]', {
    'margin' => '0'
  })

  css.add_rule('.connection-status', {
    'display' => 'flex',
    'align-items' => 'center',
    'gap' => '8px'
  })

  css.generate
end

# Main execution
if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output_file>"
    exit 1
  end

  output_file = ARGV[0]
  
  begin
    css_content = create_sidepanel_css
    File.write(output_file, css_content)
    puts "CSS file generated successfully: #{output_file}"
  rescue => e
    puts "Error generating CSS file: #{e.message}"
    exit 1
  end
end
