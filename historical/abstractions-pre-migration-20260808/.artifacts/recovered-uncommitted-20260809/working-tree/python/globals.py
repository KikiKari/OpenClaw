#!/usr/bin/env python3
# globals.css — portiert nach python
# Quelle: css, Onboarding@main:app/globals.css
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import sys
import os

def generate_css():
    """Generate the CSS content programmatically"""
    
    # Import and root variables
    css_parts = []
    
    # Add imports
    css_parts.append('@import "tailwindcss";\n')
    
    # Root variables
    css_parts.append(':root {\n')
    variables = [
        ('--bg', '#faf8f4'),
        ('--surface', '#ffffff'),
        ('--surface-2', '#f1eee7'),
        ('--ink', '#1b1a17'),
        ('--ink-2', '#3c3a34'),
        ('--muted', '#6e6a61'),
        ('--line', '#e5e1d8'),
        ('--line-strong', '#d4cfc3'),
        ('--accent', '#a8542f'),
        ('--accent-press', '#8e4526'),
        ('--accent-tint', '#f1e5dd'),
        ('--on-accent', '#ffffff'),
        ('--accent-2', '#2e7d7b'),
        ('--accent-2-press', '#225e5b'),
        ('--accent-3', '#c77d2e'),
        ('--footer-bg', '#191815'),
        ('--footer-fg', '#efeae0'),
        ('--footer-muted', '#9a958a'),
        ('--success', '#2e7d5b'),
        ('--danger', '#9e3f32'),
        ('--font-display', '"Iowan Old Style", "Palatino Linotype", Georgia, "Times New Roman", serif'),
        ('--font-sans', '"Segoe UI", Inter, system-ui, -apple-system, sans-serif'),
        ('--font-mono', '"Cascadia Code", "SFMono-Regular", Consolas, ui-monospace, monospace'),
        ('--space-1', '0.25rem'),
        ('--space-2', '0.5rem'),
        ('--space-3', '0.75rem'),
        ('--space-4', '1rem'),
        ('--space-5', '1.25rem'),
        ('--space-6', '1.5rem'),
        ('--space-8', '2rem'),
        ('--space-10', '2.5rem'),
        ('--space-12', '3rem'),
        ('--space-16', '4rem'),
        ('--space-20', '5rem'),
        ('--space-24', '6rem'),
        ('--space-30', '7.5rem'),
        ('--radius-sm', '0.375rem'),
        ('--radius-md', '0.625rem'),
        ('--radius-lg', '1.125rem'),
        ('--radius-pill', '999px'),
        ('--shadow-sm', '0 1px 2px rgb(27 26 23 / 6%)'),
        ('--shadow-md', '0 10px 30px -16px rgb(27 26 23 / 22%)'),
        ('--shadow-lg', '0 34px 70px -34px rgb(27 26 23 / 32%)'),
        ('--container', '75rem'),
        ('--motion-fast', '180ms'),
        ('--motion-base', '350ms'),
        ('--motion-slow', '800ms'),
        ('--ease-out', 'cubic-bezier(0.22, 0.61, 0.36, 1)')
    ]
    
    for var, value in variables:
        css_parts.append(f'  {var}: {value};\n')
    css_parts.append('}\n\n')
    
    # Theme inline
    css_parts.append('@theme inline {\n')
    theme_vars = [
        '--color-bg: var(--bg)',
        '--color-surface: var(--surface)',
        '--color-surface-2: var(--surface-2)',
        '--color-ink: var(--ink)',
        '--color-ink-2: var(--ink-2)',
        '--color-muted: var(--muted)',
        '--color-line: var(--line)',
        '--color-line-strong: var(--line-strong)',
        '--color-accent: var(--accent)',
        '--color-accent-2: var(--accent-2)',
        '--color-accent-3: var(--accent-3)',
        '--font-display: var(--font-display)',
        '--font-sans: var(--font-sans)',
        '--font-mono: var(--font-mono)'
    ]
    
    for var in theme_vars:
        css_parts.append(f'  {var};\n')
    css_parts.append('}\n\n')
    
    # Base styles
    css_parts.append('* { box-sizing: border-box; }\n')
    css_parts.append('html { scroll-behavior: smooth; }\n')
    css_parts.append('body {\n')
    css_parts.append('  margin: 0;\n')
    css_parts.append('  background: var(--bg);\n')
    css_parts.append('  color: var(--ink);\n')
    css_parts.append('  font-family: var(--font-sans);\n')
    css_parts.append('  line-height: 1.5;\n')
    css_parts.append('  -webkit-font-smoothing: antialiased;\n')
    css_parts.append('}\n')
    css_parts.append('a { color: inherit; }\n')
    css_parts.append('button, input, textarea { font: inherit; }\n')
    css_parts.append('::selection { background: var(--accent-tint); color: var(--ink); }\n\n')
    
    # Utility classes
    css_parts.append('.display {\n')
    css_parts.append('  font-family: var(--font-display);\n')
    css_parts.append('  font-weight: 400;\n')
    css_parts.append('  letter-spacing: -0.022em;\n')
    css_parts.append('}\n')
    css_parts.append('.eyebrow {\n')
    css_parts.append('  font-family: var(--font-mono);\n')
    css_parts.append('  font-size: 0.75rem;\n')
    css_parts.append('  letter-spacing: 0.16em;\n')
    css_parts.append('  text-transform: uppercase;\n')
    css_parts.append('}\n')
    css_parts.append('.focus-ring:focus-visible {\n')
    css_parts.append('  outline: 2px solid var(--accent);\n')
    css_parts.append('  outline-offset: 4px;\n')
    css_parts.append('}\n')
    css_parts.append('.content-auto { content-visibility: auto; contain-intrinsic-size: 1px 800px; }\n\n')
    
    # Media query for reduced motion
    css_parts.append('@media (prefers-reduced-motion: reduce) {\n')
    css_parts.append('  html { scroll-behavior: auto; }\n')
    css_parts.append('  *, *::before, *::after {\n')
    css_parts.append('    animation-duration: 0.01ms !important;\n')
    css_parts.append('    animation-iteration-count: 1 !important;\n')
    css_parts.append('    scroll-behavior: auto !important;\n')
    css_parts.append('    transition-duration: 0.01ms !important;\n')
    css_parts.append('  }\n')
    css_parts.append('}\n\n')
    
    # Header hiding comment and styles
    css_parts.append('/* Header ausblenden solange PondExperience aktiv ist (data-hero-immersive) */\n')
    css_parts.append('body[data-hero-immersive="true"] > header,\n')
    css_parts.append('body[data-hero-immersive="true"] header[data-site-header] {\n')
    css_parts.append('  opacity: 0;\n')
    css_parts.append('  pointer-events: none;\n')
    css_parts.append('  transition: opacity 0.4s ease-out;\n')
    css_parts.append('}\n\n')
    
    # Keyframes for dropfall animation
    css_parts.append('/* Wassertropfen die frontal am Screen herunterlaufen (Splash-Overlay) */\n')
    css_parts.append('@keyframes dropfall {\n')
    css_parts.append('  0% {\n')
    css_parts.append('    transform: translateY(0);\n')
    css_parts.append('    opacity: 0;\n')
    css_parts.append('  }\n')
    css_parts.append('  10% {\n')
    css_parts.append('    opacity: 0.9;\n')
    css_parts.append('  }\n')
    css_parts.append('  90% {\n')
    css_parts.append('    opacity: 0.7;\n')
    css_parts.append('  }\n')
    css_parts.append('  100% {\n')
    css_parts.append('    transform: translateY(110vh);\n')
    css_parts.append('    opacity: 0;\n')
    css_parts.append('  }\n')
    css_parts.append('}\n')
    
    return ''.join(css_parts)

def main():
    """Main function to write CSS to file"""
    if len(sys.argv) != 2:
        print("Usage: python3 globals_css_generator.py <output_file>")
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
