#!/usr/bin/env python3
# gateway-styles.css — portiert nach python
# Quelle: css, OpenClaw@main:examples/gateway-styles.css
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_css():
    """Generate the CSS content as a string"""
    css_parts = []
    
    # Add comment header
    css_parts.append("/* OpenClaw Gateway Dashboard */\n")
    
    # Global reset
    css_parts.append("*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }\n")
    
    # Root variables
    css_parts.append("""
:root {
  --bg:       #0d1117;
  --surface:  #161b22;
  --border:   #30363d;
  --text:     #e6edf3;
  --muted:    #8b949e;
  --green:    #3fb950;
  --yellow:   #d29922;
  --red:      #f85149;
  --accent:   #58a6ff;
}
""")
    
    # Body styles
    css_parts.append("""
body {
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  min-height: 100vh;
}
""")
    
    # Header styles
    css_parts.append("""
header {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.25rem 2rem;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
}
""")
    
    css_parts.append("header h1 { font-size: 1.25rem; color: var(--accent); }\n")
    
    # Badge styles
    css_parts.append("""
.badge {
  padding: .25rem .75rem;
  border-radius: 999px;
  font-size: .75rem;
  font-weight: 600;
  background: var(--border);
  color: var(--muted);
}
.badge.ok    { background: #1a3a2a; color: var(--green); }
.badge.warn  { background: #3a2e0a; color: var(--yellow); }
.badge.error { background: #3a1010; color: var(--red); }
""")
    
    # Main content
    css_parts.append("""
main { padding: 2rem; max-width: 960px; margin: 0 auto; }
""")
    
    # Grid layout
    css_parts.append("""
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}
""")
    
    # Card styles
    css_parts.append("""
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.25rem;
  position: relative;
}
""")
    
    css_parts.append(".card h2   { font-size: 1rem; margin-bottom: .25rem; }\n")
    css_parts.append(".card .endpoint { font-size: .8rem; color: var(--muted); }\n")
    
    # Status dot
    css_parts.append("""
.status-dot {
  position: absolute;
  top: 1.25rem;
  right: 1.25rem;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--border);
}
.status-dot.green { background: var(--green); box-shadow: 0 0 6px var(--green); }
.status-dot.red   { background: var(--red);   box-shadow: 0 0 6px var(--red); }
""")
    
    # Metrics section
    css_parts.append("""
.metrics h2 { font-size: 1rem; margin-bottom: 1rem; }
""")
    
    # Table styles
    css_parts.append("""
table {
  width: 100%;
  border-collapse: collapse;
  font-size: .875rem;
}
th, td {
  padding: .625rem 1rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
}
th { color: var(--muted); font-weight: 500; }
tr:last-child td { border-bottom: none; }
""")
    
    return "".join(css_parts)

def main():
    """Main function to write CSS to file"""
    if len(sys.argv) != 2:
        print("Usage: python gateway-styles.py <output-file>")
        sys.exit(1)
    
    output_file = sys.argv[1]
    css_content = generate_css()
    
    try:
        Path(output_file).write_text(css_content, encoding='utf-8')
        print(f"CSS file written to {output_file}")
    except Exception as e:
        print(f"Error writing file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
