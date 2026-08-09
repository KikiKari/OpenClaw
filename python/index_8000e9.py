#!/usr/bin/env python3
# index.html — portiert nach python
# Quelle: html, Onboarding@main:development/preview-renders/hover-mock/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import sys
import html

def generate_html():
    """Generate the complete HTML document as a string"""
    
    # Define CSS variables
    css_vars = {
        '--bg': '#FAF8F4',
        '--ink': '#1B1A17',
        '--accent': '#A8542F',
        '--accent-2': '#2E7D7B',
        '--font-display': "'Newsreader', Georgia, serif",
        '--font-body': "'Hanken Grotesk', -apple-system, sans-serif",
        '--font-mono': "'JetBrains Mono', monospace"
    }
    
    # Start building the HTML
    html_parts = []
    
    # DOCTYPE and html tag
    html_parts.append('<!DOCTYPE html>')
    html_parts.append('<html lang="de">')
    
    # Head section
    html_parts.append('<head>')
    html_parts.append('<meta charset="UTF-8">')
    html_parts.append('<title>Hover-Preview Varianten · Vergleich</title>')
    
    # Style section
    html_parts.append('<style>')
    
    # CSS variables
    html_parts.append(':root {')
    for var, value in css_vars.items():
        html_parts.append(f'  {var}: {value};')
    html_parts.append('}')
    
    # Global styles
    html_parts.append('* { box-sizing: border-box; margin: 0; padding: 0; }')
    html_parts.append('body {')
    html_parts.append('  font-family: var(--font-body);')
    html_parts.append(f'  background: {css_vars["--bg"]};')
    html_parts.append(f'  color: {css_vars["--ink"]};')
    html_parts.append('  padding: 32px 16px 80px;')
    html_parts.append('}')
    
    # Heading styles
    html_parts.append('h1 {')
    html_parts.append('  font-family: var(--font-display);')
    html_parts.append('  font-weight: 500;')
    html_parts.append('  font-size: 28px;')
    html_parts.append('  max-width: 1400px;')
    html_parts.append('  margin: 0 auto 12px;')
    html_parts.append('}')
    
    # Intro styles
    html_parts.append('.intro {')
    html_parts.append('  max-width: 1400px;')
    html_parts.append('  margin: 0 auto 32px;')
    html_parts.append('  color: #666;')
    html_parts.append('  font-size: 14px;')
    html_parts.append('  line-height: 1.5;')
    html_parts.append('}')
    
    # Grid styles
    html_parts.append('.grid {')
    html_parts.append('  display: grid;')
    html_parts.append('  gap: 32px;')
    html_parts.append('  max-width: 1400px;')
    html_parts.append('  margin: 0 auto;')
    html_parts.append('}')
    
    # Variant styles
    html_parts.append('.variant {')
    html_parts.append('  background: #000;')
    html_parts.append('  border-radius: 16px;')
    html_parts.append('  overflow: hidden;')
    html_parts.append('  box-shadow: 0 12px 40px rgba(0,0,0,0.15);')
    html_parts.append('}')
    
    # Variant header styles
    html_parts.append('.variant-header {')
    html_parts.append('  background: #fff;')
    html_parts.append('  padding: 16px 24px;')
    html_parts.append('  display: flex;')
    html_parts.append('  align-items: center;')
    html_parts.append('  justify-content: space-between;')
    html_parts.append('  gap: 16px;')
    html_parts.append('  border-bottom: 1px solid #eee;')
    html_parts.append('}')
    
    # Variant label styles
    html_parts.append('.variant-label {')
    html_parts.append('  font-family: var(--font-mono);')
    html_parts.append('  font-size: 11px;')
    html_parts.append('  letter-spacing: 0.2em;')
    html_parts.append('  text-transform: uppercase;')
    html_parts.append(f'  color: {css_vars["--accent"]};')
    html_parts.append('  font-weight: 600;')
    html_parts.append('}')
    
    # Variant title styles
    html_parts.append('.variant-title {')
    html_parts.append('  font-family: var(--font-display);')
    html_parts.append('  font-size: 20px;')
    html_parts.append('  font-weight: 500;')
    html_parts.append('}')
    
    # Variant description styles
    html_parts.append('.variant-desc {')
    html_parts.append('  font-size: 13px;')
    html_parts.append('  color: #666;')
    html_parts.append('  flex: 1;')
    html_parts.append('  text-align: right;')
    html_parts.append('}')
    
    # Scene styles
    html_parts.append('.scene {')
    html_parts.append('  position: relative;')
    html_parts.append('  aspect-ratio: 16 / 9;')
    html_parts.append("  background: url('bg.png') center/cover no-repeat;")
    html_parts.append('  overflow: hidden;')
    html_parts.append('}')
    
    # Orb styles
    html_parts.append('.orb {')
    html_parts.append('  position: absolute;')
    html_parts.append('  width: 12%;')
    html_parts.append('  aspect-ratio: 1;')
    html_parts.append('  left: 42%;')
    html_parts.append('  top: 55%;')
    html_parts.append('  transform: translate(-50%, -50%);')
    html_parts.append('  cursor: pointer;')
    html_parts.append('}')
    
    html_parts.append('.orb img {')
    html_parts.append('  width: 100%;')
    html_parts.append('  height: 100%;')
    html_parts.append('  object-fit: contain;')
    html_parts.append('}')
    
    # Variant 1: Card preview styles
    html_parts.append('.card-preview {')
    html_parts.append('  position: absolute;')
    html_parts.append('  left: 55%;')
    html_parts.append('  top: 45%;')
    html_parts.append('  background: rgba(255,255,255,0.98);')
    html_parts.append('  padding: 16px 20px;')
    html_parts.append('  border-radius: 12px;')
    html_parts.append('  box-shadow: 0 8px 24px rgba(0,0,0,0.25);')
    html_parts.append('  width: 240px;')
    html_parts.append('  animation: slideIn 0.3s ease-out;')
    html_parts.append('}')
    
    html_parts.append('.card-preview .badge {')
    html_parts.append('  display: inline-block;')
    html_parts.append(f'  background: {css_vars["--accent-2"]};')
    html_parts.append('  color: white;')
    html_parts.append('  font-family: var(--font-mono);')
    html_parts.append('  font-size: 9px;')
    html_parts.append('  letter-spacing: 0.15em;')
    html_parts.append('  text-transform: uppercase;')
    html_parts.append('  padding: 3px 8px;')
    html_parts.append('  border-radius: 3px;')
    html_parts.append('  margin-bottom: 8px;')
    html_parts.append('}')
    
    html_parts.append('.card-preview h3 {')
    html_parts.append('  font-family: var(--font-display);')
    html_parts.append('  font-size: 18px;')
    html_parts.append('  font-weight: 500;')
    html_parts.append('  margin-bottom: 6px;')
    html_parts.append(f'  color: {css_vars["--ink"]};')
    html_parts.append('}')
    
    html_parts.append('.card-preview p {')
    html_parts.append('  font-size: 12px;')
    html_parts.append('  color: #555;')
    html_parts.append('  line-height: 1.4;')
    html_parts.append('}')
    
    html_parts.append('@keyframes slideIn {')
    html_parts.append('  from { opacity: 0; transform: translateX(-8px); }')
    html_parts.append('  to { opacity: 1; transform: translateX(0); }')
    html_parts.append('}')
    
    # Variant 2: Minimal tooltip styles
    html_parts.append('.tooltip {')
    html_parts.append('  position: absolute;')
    html_parts.append('  left: 42%;')
    html_parts.append('  top: 46%;')
    html_parts.append('  transform: translate(-50%, -100%);')
    html_parts.append('  color: white;')
    html_parts.append('  text-shadow: 0 2px 12px rgba(0,0,0,0.8);')
    html_parts.append('  font-family: var(--font-display);')
    html_parts.append('  font-size: 20px;')
    html_parts.append('  font-weight: 500;')
    html_parts.append('  white-space: nowrap;')
    html_parts.append('  animation: fadeUp 0.3s ease-out;')
    html_parts.append('}')
    
    html_parts.append('@keyframes fadeUp {')
    html_parts.append('  from { opacity: 0; transform: translate(-50%, -80%); }')
    html_parts.append('  to { opacity: 1; transform: translate(-50%, -100%); }')
    html_parts.append('}')
    
    # Variant 3: Full overlay styles
    html_parts.append('.full-overlay {')
    html_parts.append('  position: absolute;')
    html_parts.append('  inset: 0;')
    html_parts.append('  background: rgba(0,0,0,0.5);')
    html_parts.append('  backdrop-filter: blur(6px);')
    html_parts.append('  display: flex;')
    html_parts.append('  align-items: center;')
    html_parts.append('  justify-content: center;')
    html_parts.append('  animation: fadeIn 0.35s ease-out;')
    html_parts.append('}')
    
    html_parts.append('.full-overlay .panel {')
    html_parts.append('  background: rgba(255,255,255,0.98);')
    html_parts.append('  padding: 32px 40px;')
    html_parts.append('  border-radius: 20px;')
    html_parts.append('  max-width: 420px;')
    html_parts.append('  box-shadow: 0 20px 60px rgba(0,0,0,0.4);')
    html_parts.append('  text-align: center;')
    html_parts.append('}')
    
    html_parts.append('.full-overlay .badge {')
    html_parts.append('  display: inline-block;')
    html_parts.append(f'  background: {css_vars["--accent"]};')
    html_parts.append('  color: white;')
    html_parts.append('  font-family: var(--font-mono);')
    html_parts.append('  font-size: 10px;')
    html_parts.append('  letter-spacing: 0.2em;')
    html_parts.append('  text-transform: uppercase;')
    html_parts.append('  padding: 4px 10px;')
    html_parts.append('  border-radius: 4px;')
    html_parts.append('  margin-bottom: 14px;')
    html_parts.append('}')
    
    html_parts.append('.full-overlay h3 {')
    html_parts.append('  font-family: var(--font-display);')
    html_parts.append('  font-size: 28px;')
    html_parts.append('  font-weight: 500;')
    html_parts.append('  margin-bottom: 10px;')
    html_parts.append(f'  color: {css_vars["--ink"]};')
    html_parts.append('}')
    
    html_parts.append('.full-overlay p {')
    html_parts.append('  font-size: 14px;')
    html_parts.append('  color: #555;')
    html_parts.append('  line-height: 1.5;')
    html_parts.append('  margin-bottom: 20px;')
    html_parts.append('}')
    
    html_parts.append('.full-overlay .preview-img {')
    html_parts.append('  width: 100%;')
    html_parts.append('  aspect-ratio: 16/10;')
    html_parts.append('  background: linear-gradient(135deg, #A8542F, #2E7D7B);')
    html_parts.append('  border-radius: 8px;')
    html_parts.append('  margin-bottom: 16px;')
    html_parts.append('  display: flex;')
    html_parts.append('  align-items: center;')
    html_parts.append('  justify-content: center;')
    html_parts.append('  color: white;')
    html_parts.append('  font-family: var(--font-mono);')
    html_parts.append('  font-size: 11px;')
    html_parts.append('  letter-spacing: 0.15em;')
    html_parts.append('  opacity: 0.9;')
    html_parts.append('}')
    
    html_parts.append('@keyframes fadeIn {')
    html_parts.append('  from { opacity: 0; }')
    html_parts.append('  to { opacity: 1; }')
    html_parts.append('}')
    
    # Instruction styles
    html_parts.append('.instruction {')
    html_parts.append('  text-align: center;')
    html_parts.append('  color: #999;')
    html_parts.append('  font-size: 12px;')
    html_parts.append('  margin-top: 16px;')
    html_parts.append('  font-family: var(--font-mono);')
    html_parts.append('  letter-spacing: 0.15em;')
    html_parts.append('  text-transform: uppercase;')
    html_parts.append('}')
    
    # Media query
    html_parts.append('@media (max-width: 900px) {')
    html_parts.append('  .card-preview { width: 180px; padding: 12px 14px; }')
    html_parts.append('  .card-preview h3 { font-size: 15px; }')
    html_parts.append('  .card-preview p { font-size: 11px; }')
    html_parts.append('  .tooltip { font-size: 15px; }')
    html_parts.append('  .full-overlay .panel { padding: 20px 24px; max-width: 300px; }')
    html_parts.append('  .full-overlay h3 { font-size: 20px; }')
    html_parts.append('}')
    
    html_parts.append('</style>')
    
    # Font links
    html_parts.append('<link rel="preconnect" href="https://fonts.googleapis.com">')
    html_parts.append('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
    html_parts.append('<link href="https://fonts.googleapis.com/css2?family=Newsreader:wght@400;500&family=Hanken+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">')
    
    html_parts.append('</head>')
    
    # Body section
    html_parts.append('<body>')
    
    # Main heading
    html_parts.append('<h1>Hover-Preview · drei Varianten im Vergleich</h1>')
    
    # Intro paragraph
    html_parts.append('<p class="intro">Gleiche Szene, gleiche Kugel-Position (Beispiel: Projekt-Kugel "Weather-Check").<br>Alle drei Varianten zeigen den Zustand <em>bei Maushover</em>. Welche soll ins Projekt?</p>')
    
    # Grid container
    html_parts.append('<div class="grid">')
    
    # Variant 1
    html_parts.append('  <!-- Variante 1 -->')
    html_parts.append('  <div class="variant">')
    html_parts.append('    <div class="variant-header">')
    html_parts.append('      <div>')
    html_parts.append('        <div class="variant-label">Variante 1</div>')
    html_parts.append('        <div class="variant-title">Karte daneben</div>')
    html_parts.append('      </div>')
    html_parts.append('      <div class="variant-desc">Kompakte Card rechts der Kugel · Titel + Badge + kurze Beschreibung aus content.ts · dezent, nicht störend</div>')
    html_parts.append('    </div>')
    html_parts.append('    <div class="scene">')
    html_parts.append('      <div class="orb"><img src="orb-01-teal.png" alt=""></div>')
    html_parts.append('      <div class="card-preview">')
    html_parts.append('        <span class="badge">GitHub · Public</span>')
    html_parts.append('        <h3>Weather-Check</h3>')
    html_parts.append('        <p>Progressive Web App für lokale Wetterdaten mit Live-Radar und Push-Benachrichtigungen.</p>')
    html_parts.append('      </div>')
    html_parts.append('    </div>')
    html_parts.append('  </div>')
    
    # Variant 2
    html_parts.append('  <!-- Variante 2 -->')
    html_parts.append('  <div class="variant">')
    html_parts.append('    <div class="variant-header">')
    html_parts.append('      <div>')
    html_parts.append('        <div class="variant-label">Variante 2</div>')
    html_parts.append('        <div class="variant-title">Minimaler Tooltip</div>')
    html_parts.append('      </div>')
    html_parts.append('      <div class="variant-desc">Nur der Titel schwebt über der Kugel · maximal reduziert · schnell erfassbar · lässt die Bildwirkung ungestört</div>')
    html_parts.append('    </div>')
    html_parts.append('    <div class="scene">')
    html_parts.append('      <div class="orb"><img src="orb-01-teal.png" alt=""></div>')
    html_parts.append('      <div class="tooltip">Weather-Check</div>')
    html_parts.append('    </div>')
    html_parts.append('  </div>')
    
    # Variant 3
    html_parts.append('  <!-- Variante 3 -->')
    html_parts.append('  <div class="variant">')
    html_parts.append('    <div class="variant-header">')
    html_parts.append('      <div>')
    html_parts.append('        <div class="variant-label">Variante 3</div>')
    html_parts.append('        <div class="variant-title">Vollflächiges Overlay</div>')
    html_parts.append('      </div>')
    html_parts.append('      <div class="variant-desc">Zentrales Modal mit Preview-Bild + Titel + Beschreibung · prominent · lädt zum Klicken ein · verdeckt aber Szene</div>')
    html_parts.append('    </div>')
    html_parts.append('    <div class="scene">')
    html_parts.append('      <div class="orb"><img src="orb-01-teal.png" alt=""></div>')
    html_parts.append('      <div class="full-overlay">')
    html_parts.append('        <div class="panel">')
    html_parts.append('          <div class="preview-img">PROJEKT-PREVIEW</div>')
    html_parts.append('          <span class="badge">GitHub · Public</span>')
    html_parts.append('          <h3>Weather-Check</h3>')
    html_parts.append('          <p>Progressive Web App für lokale Wetterdaten mit Live-Radar und Push-Benachrichtigungen.</p>')
    html_parts.append('        </div>')
    html_parts.append('      </div>')
    html_parts.append('    </div>')
    html_parts.append('  </div>')
    
    html_parts.append('</div>')
    
    # Instruction paragraph
    html_parts.append('<p class="instruction">Sag mir welche Variante — dann baue ich sie ins Frontend ein.</p>')
    
    html_parts.append('</body>')
    html_parts.append('</html>')
    
    return '\n'.join(html_parts)

def main():
    """Main function to generate HTML and write to file if specified"""
    if len(sys.argv) > 1:
        filename = sys.argv[1]
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                f.write(generate_html())
            print(f"HTML content written to {filename}")
        except IOError as e:
            print(f"Error writing to file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(generate_html())

if __name__ == "__main__":
    main()
