#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "52e640ff0bba42979cfc31f93d6c25ef85f74d46eaacd325505e65c1b9f6ed1f", "source_sha256": "47d390b58fc734629c213c66e58cb7f0c68bbd896bac294215d12289e5e21c07", "target_language": "ruby"}
# gateway-styles.css — portiert nach ruby
# Quelle: css, OpenClaw@main:examples/gateway-styles.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Gateway Dashboard

class CSSGenerator
  def initialize
    @variables = {
      '--bg' => '#0d1117',
      '--surface' => '#161b22',
      '--border' => '#30363d',
      '--text' => '#e6edf3',
      '--muted' => '#8b949e',
      '--green' => '#3fb950',
      '--yellow' => '#d29922',
      '--red' => '#f85149',
      '--accent' => '#58a6ff'
    }
    
    @rules = []
  end
  
  def add_rule(selector, properties)
    @rules << { selector: selector, properties: properties }
  end
  
  def generate_css
    css = "/* OpenClaw Gateway Dashboard */\n\n"
    
    # Reset styles
    css += "* { box-sizing: border-box; margin: 0; padding: 0; }\n"
    css += "*::before { box-sizing: border-box; margin: 0; padding: 0; }\n"
    css += "*::after { box-sizing: border-box; margin: 0; padding: 0; }\n\n"
    
    # Root variables
    css += ":root {\n"
    @variables.each do |name, value|
      css += "  #{name}: #{value};\n"
    end
    css += "}\n\n"
    
    # Generate all rules
    @rules.each do |rule|
      css += "#{rule[:selector]} {\n"
      rule[:properties].each do |prop, value|
        css += "  #{prop}: #{value};\n"
      end
      css += "}\n\n"
    end
    
    css
  end
  
  def self.generate_default_styles
    generator = new
    
    # Body
    generator.add_rule('body', {
      'background' => 'var(--bg)',
      'color' => 'var(--text)',
      'font-family' => '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      'min-height' => '100vh'
    })
    
    # Header
    generator.add_rule('header', {
      'display' => 'flex',
      'align-items' => 'center',
      'gap' => '1rem',
      'padding' => '1.25rem 2rem',
      'border-bottom' => '1px solid var(--border)',
      'background' => 'var(--surface)'
    })
    
    generator.add_rule('header h1', {
      'font-size' => '1.25rem',
      'color' => 'var(--accent)'
    })
    
    # Badge
    generator.add_rule('.badge', {
      'padding' => '.25rem .75rem',
      'border-radius' => '999px',
      'font-size' => '.75rem',
      'font-weight' => '600',
      'background' => 'var(--border)',
      'color' => 'var(--muted)'
    })
    
    generator.add_rule('.badge.ok', {
      'background' => '#1a3a2a',
      'color' => 'var(--green)'
    })
    
    generator.add_rule('.badge.warn', {
      'background' => '#3a2e0a',
      'color' => 'var(--yellow)'
    })
    
    generator.add_rule('.badge.error', {
      'background' => '#3a1010',
      'color' => 'var(--red)'
    })
    
    # Main
    generator.add_rule('main', {
      'padding' => '2rem',
      'max-width' => '960px',
      'margin' => '0 auto'
    })
    
    # Grid
    generator.add_rule('.grid', {
      'display' => 'grid',
      'grid-template-columns' => 'repeat(auto-fit, minmax(260px, 1fr))',
      'gap' => '1rem',
      'margin-bottom' => '2rem'
    })
    
    # Card
    generator.add_rule('.card', {
      'background' => 'var(--surface)',
      'border' => '1px solid var(--border)',
      'border-radius' => '8px',
      'padding' => '1.25rem',
      'position' => 'relative'
    })
    
    generator.add_rule('.card h2', {
      'font-size' => '1rem',
      'margin-bottom' => '.25rem'
    })
    
    generator.add_rule('.card .endpoint', {
      'font-size' => '.8rem',
      'color' => 'var(--muted)'
    })
    
    # Status dot
    generator.add_rule('.status-dot', {
      'position' => 'absolute',
      'top' => '1.25rem',
      'right' => '1.25rem',
      'width' => '10px',
      'height' => '10px',
      'border-radius' => '50%',
      'background' => 'var(--border)'
    })
    
    generator.add_rule('.status-dot.green', {
      'background' => 'var(--green)',
      'box-shadow' => '0 0 6px var(--green)'
    })
    
    generator.add_rule('.status-dot.red', {
      'background' => 'var(--red)',
      'box-shadow' => '0 0 6px var(--red)'
    })
    
    # Metrics
    generator.add_rule('.metrics h2', {
      'font-size' => '1rem',
      'margin-bottom' => '1rem'
    })
    
    # Table
    generator.add_rule('table', {
      'width' => '100%',
      'border-collapse' => 'collapse',
      'font-size' => '.875rem'
    })
    
    generator.add_rule('th, td', {
      'padding' => '.625rem 1rem',
      'text-align' => 'left',
      'border-bottom' => '1px solid var(--border)'
    })
    
    generator.add_rule('th', {
      'color' => 'var(--muted)',
      'font-weight' => '500'
    })
    
    generator.add_rule('tr:last-child td', {
      'border-bottom' => 'none'
    })
    
    generator
  end
end

# Main execution
if __FILE__ == $0
  output_file = ARGV[0] || 'gateway-styles.css'
  
  generator = CSSGenerator.generate_default_styles
  css_content = generator.generate_css
  
  File.open(output_file, 'w') do |file|
    file.write(css_content)
  end
  
  puts "CSS file generated: #{output_file}"
end
