#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9a6a8f2ca3bd75e362d7197392f721b904abd6692cc2281ba60f22ce3da63264", "source_sha256": "9be2a45ff3b835da1be1793cc88c8cb54d6a2456cf2ccc358c8243df836440e3", "target_language": "ruby"}
# status-overview-panel.css — portiert nach ruby
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview-panel.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Methode zur Erstellung der CSS-Struktur
def generate_css
  css_rules = []

  # Definiere die CSS-Regeln als Hashes
  css_rules << {
    selector: '.overview-row',
    properties: {
      'display' => 'grid',
      'grid-template-columns' => '24px minmax(0,1fr) 11px 22px auto',
      'gap' => '7px',
      'align-items' => 'center',
      'margin' => '6px 0'
    }
  }

  css_rules << {
    selector: '.overview-row input',
    properties: {
      'min-width' => '0',
      'width' => '100%'
    }
  }

  css_rules << {
    selector: '.overview-state',
    properties: {
      'width' => '11px',
      'height' => '11px',
      'border-radius' => '50%',
      'background' => '#888'
    }
  }

  css_rules << {
    selector: '.overview-state.online',
    properties: {
      'background' => 'var(--good)',
      'box-shadow' => '0 0 0 3px color-mix(in srgb, var(--good) 15%, transparent)'
    }
  }

  css_rules << {
    selector: '.overview-state.offline',
    properties: {
      'background' => 'var(--bad)',
      'box-shadow' => '0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)'
    }
  }

  css_rules << {
    selector: '.overview-state.checking, .overview-state.error',
    properties: {
      'background' => 'var(--warn)'
    }
  }

  css_rules << {
    selector: '.overview-count',
    properties: {
      'font-size' => '11px',
      'text-align' => 'center',
      'font-variant-numeric' => 'tabular-nums'
    }
  }

  css_rules << {
    selector: '.overview-actions',
    properties: {
      'display' => 'grid',
      'grid-template-columns' => '44px repeat(2,minmax(0,1fr))',
      'gap' => '6px',
      'align-items' => 'stretch'
    }
  }

  css_rules << {
    selector: '.overview-actions button',
    properties: {
      'min-width' => '0',
      'padding' => '8px 2px',
      'font-size' => '11px',
      'white-space' => 'nowrap'
    }
  }

  css_rules << {
    selector: '#overview-rows',
    properties: {
      'display' => 'flex',
      'flex-direction' => 'column'
    }
  }

  css_rules << {
    selector: '.monitor-settings > label:not(.option-row)',
    properties: {
      'display' => 'block',
      'margin' => '12px 0'
    }
  }

  css_rules << {
    selector: '.monitor-settings .option-row input',
    properties: {
      'appearance' => 'auto',
      'width' => '13px',
      'height' => '13px',
      'min-width' => '13px',
      'background' => 'none'
    }
  }

  css_rules << {
    selector: '.overview-link',
    properties: {
      'padding' => '8px 0',
      'border-bottom' => '1px solid #bbb',
      'overflow-wrap' => 'anywhere'
    }
  }

  css_rules << {
    selector: '.overview-link p',
    properties: {
      'margin' => '4px 0'
    }
  }

  css_rules << {
    selector: '.overview-row .overview-retry',
    properties: {
      'width' => '24px',
      'min-width' => '24px',
      'height' => '26px',
      'min-height' => '26px',
      'padding' => '0',
      'background-image' => 'var(--icon-reset)',
      'background-size' => '20px',
      'background-position' => 'center',
      'background-repeat' => 'no-repeat'
    }
  }

  css_rules << {
    selector: '.top-setting input',
    properties: {
      'appearance' => 'auto',
      '-webkit-appearance' => 'checkbox',
      'width' => '13px',
      'height' => '13px',
      'min-width' => '13px',
      'background' => 'none'
    }
  }

  css_rules << {
    selector: '.overview-visually-hidden',
    properties: {
      'position' => 'absolute',
      'width' => '1px',
      'height' => '1px',
      'padding' => '0',
      'margin' => '-1px',
      'overflow' => 'hidden',
      'clip' => 'rect(0,0,0,0)',
      'white-space' => 'nowrap',
      'border' => '0'
    }
  }

  css_rules << {
    selector: '.overview-row[hidden]',
    properties: {
      'display' => 'none'
    }
  }

  # Konvertiere die Regeln in einen CSS-String
  css_content = ""
  css_rules.each do |rule|
    css_content += "#{rule[:selector]} {"
    rule[:properties].each do |property, value|
      css_content += " #{property}:#{value};"
    end
    css_content += " }\n"
  end

  css_content
end

# Hauptprogramm
if ARGV.length != 1
  puts "Verwendung: #{$0} <ausgabedatei>"
  exit 1
end

output_file = ARGV[0]

# Generiere den CSS-Inhalt
css_content = generate_css

# Schreibe den Inhalt in die angegebene Datei
File.open(output_file, 'w') do |file|
  file.write(css_content)
end

puts "CSS-Datei wurde erfolgreich erstellt: #{output_file}"
