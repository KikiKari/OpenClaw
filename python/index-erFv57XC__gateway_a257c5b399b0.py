#!/usr/bin/env python3
# index-erFv57XC.css — portiert nach python
# Quelle: css, Projects@Weather-Check:Weather-Check/assets/index-erFv57XC.css
# Erzeugt: 2026-11-09 durch ABSTRACTIONS_MANAGER.py

import sys
import argparse
from pathlib import Path

def generate_css():
    """Generate the CSS content programmatically"""
    css_parts = []
    
    # Import statement
    css_parts.append('@import"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap";')
    
    # Root variables
    css_parts.append(':root{')
    css_parts.append('  --background: 214 35% 8%;')
    css_parts.append('  --foreground: 210 20% 92%;')
    css_parts.append('  --card: 214 30% 11%;')
    css_parts.append('  --card-foreground: 210 20% 92%;')
    css_parts.append('  --popover: 214 30% 11%;')
    css_parts.append('  --popover-foreground: 210 20% 92%;')
    css_parts.append('  --primary: 210 85% 55%;')
    css_parts.append('  --primary-foreground: 214 35% 8%;')
    css_parts.append('  --secondary: 214 25% 16%;')
    css_parts.append('  --secondary-foreground: 210 20% 75%;')
    css_parts.append('  --muted: 214 25% 14%;')
    css_parts.append('  --muted-foreground: 210 15% 55%;')
    css_parts.append('  --accent: 195 80% 50%;')
    css_parts.append('  --accent-foreground: 214 35% 8%;')
    css_parts.append('  --destructive: 0 75% 55%;')
    css_parts.append('  --destructive-foreground: 210 20% 92%;')
    css_parts.append('  --border: 214 25% 18%;')
    css_parts.append('  --input: 214 25% 16%;')
    css_parts.append('  --ring: 210 85% 55%;')
    css_parts.append('  --radius: .75rem;')
    css_parts.append('  --rain-blue: #3b9eff;')
    css_parts.append('  --rain-dark: #0d1b2a;')
    css_parts.append('  --radar-glow: rgba(59, 158, 255, .15)')
    css_parts.append('}')
    
    # Universal selector variables
    universal_vars = [
        '--tw-border-spacing-x: 0',
        '--tw-border-spacing-y: 0',
        '--tw-translate-x: 0',
        '--tw-translate-y: 0',
        '--tw-rotate: 0',
        '--tw-skew-x: 0',
        '--tw-skew-y: 0',
        '--tw-scale-x: 1',
        '--tw-scale-y: 1',
        '--tw-pan-x: ',
        '--tw-pan-y: ',
        '--tw-pinch-zoom: ',
        '--tw-scroll-snap-strictness: proximity',
        '--tw-gradient-from-position: ',
        '--tw-gradient-via-position: ',
        '--tw-gradient-to-position: ',
        '--tw-ordinal: ',
        '--tw-slashed-zero: ',
        '--tw-numeric-figure: ',
        '--tw-numeric-spacing: ',
        '--tw-numeric-fraction: ',
        '--tw-ring-inset: ',
        '--tw-ring-offset-width: 0px',
        '--tw-ring-offset-color: #fff',
        '--tw-ring-color: rgb(59 130 246 / .5)',
        '--tw-ring-offset-shadow: 0 0 #0000',
        '--tw-ring-shadow: 0 0 #0000',
        '--tw-shadow: 0 0 #0000',
        '--tw-shadow-colored: 0 0 #0000',
        '--tw-blur: ',
        '--tw-brightness: ',
        '--tw-contrast: ',
        '--tw-grayscale: ',
        '--tw-hue-rotate: ',
        '--tw-invert: ',
        '--tw-saturate: ',
        '--tw-sepia: ',
        '--tw-drop-shadow: ',
        '--tw-backdrop-blur: ',
        '--tw-backdrop-brightness: ',
        '--tw-backdrop-contrast: ',
        '--tw-backdrop-grayscale: ',
        '--tw-backdrop-hue-rotate: ',
        '--tw-backdrop-invert: ',
        '--tw-backdrop-opacity: ',
        '--tw-backdrop-saturate: ',
        '--tw-backdrop-sepia: ',
        '--tw-contain-size: ',
        '--tw-contain-layout: ',
        '--tw-contain-paint: ',
        '--tw-contain-style: '
    ]
    
    css_parts.append('*,:before,:after{' + ';'.join(universal_vars) + '}')
    css_parts.append('::backdrop{' + ';'.join(universal_vars) + '}')
    
    # Base styles
    css_parts.append('*,:before,:after{box-sizing:border-box;border-width:0;border-style:solid;border-color:#e5e7eb}')
    css_parts.append(':before,:after{--tw-content: ""}')
    css_parts.append('html,:host{line-height:1.5;-webkit-text-size-adjust:100%;-moz-tab-size:4;-o-tab-size:4;tab-size:4;font-family:var(--font-sans);font-feature-settings:normal;font-variation-settings:normal;-webkit-tap-highlight-color:transparent}')
    css_parts.append('body{margin:0;line-height:inherit}')
    css_parts.append('hr{height:0;color:inherit;border-top-width:1px}')
    css_parts.append('abbr:where([title]){-webkit-text-decoration:underline dotted;text-decoration:underline dotted}')
    css_parts.append('h1,h2,h3,h4,h5,h6{font-size:inherit;font-weight:inherit}')
    css_parts.append('a{color:inherit;text-decoration:inherit}')
    css_parts.append('b,strong{font-weight:bolder}')
    css_parts.append('code,kbd,samp,pre{font-family:var(--font-mono);font-feature-settings:normal;font-variation-settings:normal;font-size:1em}')
    css_parts.append('small{font-size:80%}')
    css_parts.append('sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}')
    css_parts.append('sub{bottom:-.25em}')
    css_parts.append('sup{top:-.5em}')
    css_parts.append('table{text-indent:0;border-color:inherit;border-collapse:collapse}')
    css_parts.append('button,input,optgroup,select,textarea{font-family:inherit;font-feature-settings:inherit;font-variation-settings:inherit;font-size:100%;font-weight:inherit;line-height:inherit;letter-spacing:inherit;color:inherit;margin:0;padding:0}')
    css_parts.append('button,select{text-transform:none}')
    css_parts.append('button,input:where([type=button]),input:where([type=reset]),input:where([type=submit]){-webkit-appearance:button;background-color:transparent;background-image:none}')
    css_parts.append(':-moz-focusring{outline:auto}')
    css_parts.append(':-moz-ui-invalid{box-shadow:none}')
    css_parts.append('progress{vertical-align:baseline}')
    css_parts.append('::-webkit-inner-spin-button,::-webkit-outer-spin-button{height:auto}')
    css_parts.append('[type=search]{-webkit-appearance:textfield;outline-offset:-2px}')
    css_parts.append('::-webkit-search-decoration{-webkit-appearance:none}')
    css_parts.append('::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}')
    css_parts.append('summary{display:list-item}')
    css_parts.append('blockquote,dl,dd,h1,h2,h3,h4,h5,h6,hr,figure,p,pre{margin:0}')
    css_parts.append('fieldset{margin:0;padding:0}')
    css_parts.append('legend{padding:0}')
    css_parts.append('ol,ul,menu{list-style:none;margin:0;padding:0}')
    css_parts.append('dialog{padding:0}')
    css_parts.append('textarea{resize:vertical}')
    css_parts.append('input::-moz-placeholder,textarea::-moz-placeholder{opacity:1;color:#9ca3af}')
    css_parts.append('input::placeholder,textarea::placeholder{opacity:1;color:#9ca3af}')
    css_parts.append('button,[role=button]{cursor:pointer}')
    css_parts.append(':disabled{cursor:default}')
    css_parts.append('img,svg,video,canvas,audio,iframe,embed,object{display:block;vertical-align:middle}')
    css_parts.append('img,video{max-width:100%;height:auto}')
    css_parts.append('[hidden]:where(:not([hidden=until-found])){display:none}')
    
    # Utility classes - this is a simplified version as there are hundreds of them
    utility_classes = {
        '.sr-only': 'position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border-width:0',
        '.pointer-events-none': 'pointer-events:none',
        '.pointer-events-auto': 'pointer-events:auto',
        '.visible': 'visibility:visible',
        '.invisible': 'visibility:hidden',
        '.fixed': 'position:fixed',
        '.absolute': 'position:absolute',
        '.relative': 'position:relative',
        '.block': 'display:block',
        '.inline-block': 'display:inline-block',
        '.flex': 'display:flex',
        '.inline-flex': 'display:inline-flex',
        '.table': 'display:table',
        '.grid': 'display:grid',
        '.hidden': 'display:none'
    }
    
    for cls, style in utility_classes.items():
        css_parts.append(f'{cls}{{{style}}}')
    
    # Animations
    css_parts.append('@keyframes pulse{50%{opacity:.5}}')
    css_parts.append('@keyframes spin{to{transform:rotate(360deg)}}')
    css_parts.append('@keyframes enter{0%{opacity:var(--tw-enter-opacity, 1);transform:translate3d(var(--tw-enter-translate-x, 0),var(--tw-enter-translate-y, 0),0) scale3d(var(--tw-enter-scale, 1),var(--tw-enter-scale, 1),var(--tw-enter-scale, 1)) rotate(var(--tw-enter-rotate, 0))}}')
    css_parts.append('@keyframes exit{to{opacity:var(--tw-exit-opacity, 1);transform:translate3d(var(--tw-exit-translate-x, 0),var(--tw-exit-translate-y, 0),0) scale3d(var(--tw-exit-scale, 1),var(--tw-exit-scale, 1),var(--tw-exit-scale, 1)) rotate(var(--tw-exit-rotate, 0))}}')
    css_parts.append('@keyframes radar-pulse{0%{transform:scale(.6);opacity:.8}to{transform:scale(2.2);opacity:0}}')
    css_parts.append('@keyframes rain-fall{0%{transform:translateY(-8px);opacity:0}20%{opacity:1}to{transform:translateY(24px);opacity:0}}')
    css_parts.append('@keyframes fill-bar{0%{width:0%}to{width:var(--target-width)}}')
    css_parts.append('@keyframes shimmer{0%{background-position:-200% 0}to{background-position:200% 0}}')
    css_parts.append('@keyframes accordion-up{0%{height:var(--radix-accordion-content-height)}to{height:0}}')
    css_parts.append('@keyframes accordion-down{0%{height:0}to{height:var(--radix-accordion-content-height)}}')
    
    # Body styles
    css_parts.append('body{background-color:hsl(var(--background));color:hsl(var(--foreground));font-family:Inter,system-ui,-apple-system,sans-serif;-webkit-font-smoothing:antialiased;min-height:100dvh;overflow-x:hidden}')
    
    # Special component styles
    css_parts.append('.radar-ring{animation:radar-pulse 2.5s ease-out infinite}')
    css_parts.append('.radar-ring:nth-child(2){animation-delay:.8s}')
    css_parts.append('.radar-ring:nth-child(3){animation-delay:1.6s}')
    css_parts.append('.rain-drop{animation:rain-fall 1.4s ease-in infinite}')
    css_parts.append('.rain-drop:nth-child(2){animation-delay:.2s}')
    css_parts.append('.rain-drop:nth-child(3){animation-delay:.5s}')
    css_parts.append('.rain-drop:nth-child(4){animation-delay:.7s}')
    css_parts.append('.rain-drop:nth-child(5){animation-delay:1s}')
    css_parts.append('.score-bar{animation:fill-bar 1s cubic-bezier(.4,0,.2,1) forwards}')
    css_parts.append('.glow-card{box-shadow:0 0 0 1px hsl(var(--border)),0 4px 24px #3b9eff14}')
    css_parts.append('.shimmer{background:linear-gradient(90deg,hsl(var(--muted)) 25%,hsl(var(--secondary)),hsl(var(--muted)) 75%);background-size:200% 100%;animation:shimmer 1.5s infinite}')
    css_parts.append('.photo-drop-zone{border:2px dashed hsl(var(--border));transition:border-color .2s,background-color .2s}')
    css_parts.append('.photo-drop-zone:hover,.photo-drop-zone.drag-over{border-color:hsl(var(--primary));background-color:hsl(var(--radar-glow))}')
    
    # Scrollbar
    css_parts.append('::-webkit-scrollbar{width:4px}')
    css_parts.append('::-webkit-scrollbar-track{background:transparent}')
    css_parts.append('::-webkit-scrollbar-thumb{background:hsl(var(--border));border-radius:2px}')
    
    # Pseudo-elements and pseudo-classes
    css_parts.append('.after\\:pointer-events-none:after{content:var(--tw-content);pointer-events:none}')
    css_parts.append('.after\\:absolute:after{content:var(--tw-content);position:absolute}')
    css_parts.append('.hover\\:bg-primary:hover{--tw-bg-opacity: 1;background-color:hsl(var(--primary) / var(--tw-bg-opacity, 1))}')
    css_parts.append('.focus\\:outline-none:focus{outline:2px solid transparent;outline-offset:2px}')
    
    return ''.join(css_parts)

def main(output_file):
    """Main function to generate CSS and write to file"""
    css_content = generate_css()
    
    # Write to file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(css_content)
    
    print(f"CSS file generated successfully: {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate CSS file")
    parser.add_argument("output", help="Output CSS file path")
    args = parser.parse_args()
    
    main(args.output)
